#!/usr/bin/env bash
# Builds a workstation image and tests it in a VM installed from that image:
# the filesystem layout, the Ansible bootstrap, and an upgrade followed by a
# rollback. Runs without root.
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: vm-test.sh [OPTIONS] COMMAND

Builds a workstation image and tests it in a VM installed from it. Runs
without root.

Commands:
    build           Build localhost/workstation-NAME from Containerfile.NAME.
    disk            Install the built image to a VM disk with bcvk.
    check           Boot the disk and run the checks.
    all             Run build, disk, and check.
    ssh [CMD...]    Run CMD as root in the VM that --keep left running, or
                    open a shell there.
    stop            Stop the VM that --keep left running.
    clean           Stop the VM and remove the test registry, disks, and
                    test images.

Options:
    --flavor NAME   Image flavor (default: kde).
    --keep          With check or all, leave the VM running afterwards.
    -h, --help      Show this help.

Exit status: 0 on success, 1 if a step or check fails, 2 on a usage error.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly script_dir
readonly cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/homelab-images"
readonly run_dir="$cache_dir/run"

# QEMU user networking forwards the VM's connections to 10.0.2.2 to the host's
# loopback interface, so the registry is reachable from the VM without
# listening on the LAN.
readonly registry_container=homelab-image-registry
readonly registry_image=docker.io/library/registry:3.1.2

readonly ovmf_code=/usr/share/edk2/ovmf/OVMF_CODE.fd
readonly ovmf_vars=/usr/share/edk2/ovmf/OVMF_VARS.fd
readonly boot_timeout_seconds=300
readonly low_space_gb=15

# Collections that scripts/ansible.sh installs from Fedora packages.
readonly -a collections=(ansible.posix)

# Of the images the VM runs, only the upgrade image contains this file.
readonly upgrade_marker=/usr/share/homelab-vm-test

# The vsock/ host pattern uses systemd-ssh-proxy from the host's ssh
# configuration. The guest's systemd-ssh-generator listens on vsock.
readonly -a vm_ssh_options=(
    -i "$run_dir/id_ed25519"
    -o BatchMode=yes
    -o ConnectTimeout=5
    -o LogLevel=ERROR
)

# Set by parse_args.
command=
flavor=kde
keep=false
remote_command=()

# Set by set_flavor_names.
image=
disk=
host_ref=
guest_ref=

# Prerequisites that require_* functions found missing.
missing=()

# Number of failed checks.
failures=0

log() {
    printf '%s\n' "$*"
}

warn() {
    printf 'vm-test.sh: warning: %s\n' "$*" >&2
}

die() {
    printf 'vm-test.sh: %s\n' "$*" >&2
    exit 1
}

usage_error() {
    printf 'vm-test.sh: %s\n' "$*" >&2
    printf "Run 'vm-test.sh --help' for usage.\n" >&2
    exit 2
}

parse_args() {
    while [ "$#" -gt 0 ]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --flavor)
                [ "$#" -ge 2 ] || usage_error "--flavor needs a value"
                flavor="$2"
                shift 2
                ;;
            --flavor=*)
                flavor="${1#--flavor=}"
                shift
                ;;
            --keep)
                keep=true
                shift
                ;;
            -*)
                usage_error "unknown option: $1"
                ;;
            *)
                [ -z "$command" ] || usage_error "unexpected argument: $1"
                command="$1"
                shift
                if [ "$command" = ssh ]; then
                    # Everything after ssh is the command to run in the VM.
                    remote_command=("$@")
                    break
                fi
                ;;
        esac
    done
}

validate_args() {
    case "$command" in
        build|disk|check|all|ssh|stop|clean)
            ;;
        "")
            usage_error "missing command"
            ;;
        *)
            usage_error "unknown command: $command"
            ;;
    esac
    if [ "$keep" = true ] && [ "$command" != check ] && [ "$command" != all ]; then
        usage_error "--keep only applies to check and all"
    fi
    if [[ ! "$flavor" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
        usage_error "invalid flavor: $flavor"
    fi
    if [ ! -f "$script_dir/Containerfile.$flavor" ]; then
        usage_error "no Containerfile.$flavor in $script_dir"
    fi
}

set_flavor_names() {
    image="localhost/workstation-$flavor"
    disk="$cache_dir/workstation-$flavor.qcow2"
    host_ref="127.0.0.1:5000/workstation-$flavor:test"
    guest_ref="10.0.2.2:5000/workstation-$flavor:test"
    readonly image disk host_ref guest_ref
}

add_missing() {
    local item
    for item in "${missing[@]}"; do
        [ "$item" != "$1" ] || return 0
    done
    missing+=("$1")
}

require_commands() {
    local name
    for name in "$@"; do
        command -v "$name" >/dev/null || add_missing "the $name command"
    done
}

require_files() {
    local path
    for path in "$@"; do
        [ -r "$path" ] || add_missing "$path"
    done
}

require_devices() {
    local path
    for path in "$@"; do
        if [ ! -r "$path" ] || [ ! -w "$path" ]; then
            add_missing "read and write access to $path"
        fi
    done
}

require_vsock_ssh() {
    if ! ssh -G vsock/1 2>/dev/null | grep -q '^proxycommand .*systemd-ssh-proxy'; then
        add_missing "an ssh configuration that sends vsock/ hosts through systemd-ssh-proxy"
    fi
}

require_build_tools() {
    require_commands podman
}

require_disk_tools() {
    require_commands podman bcvk
    require_devices /dev/kvm
}

require_vm_tools() {
    require_commands podman qemu-system-x86_64 qemu-img ssh ssh-keygen base64 python3
    require_files "$ovmf_code" "$ovmf_vars"
    require_devices /dev/kvm /dev/vhost-vsock
    require_vsock_ssh
}

check_prerequisites() {
    case "$command" in
        build)
            require_build_tools
            ;;
        disk)
            require_disk_tools
            ;;
        check)
            require_vm_tools
            ;;
        all)
            require_build_tools
            require_disk_tools
            require_vm_tools
            ;;
        ssh)
            require_commands ssh
            require_vsock_ssh
            ;;
        clean)
            require_commands podman
            ;;
    esac
    if [ "${#missing[@]}" -gt 0 ]; then
        printf 'vm-test.sh: missing prerequisites:\n' >&2
        printf '    %s\n' "${missing[@]}" >&2
        printf 'See "Requirements" in %s/README.md.\n' "$script_dir" >&2
        exit 1
    fi
}

warn_if_low_space() {
    local dir="$cache_dir" free_gb
    while [ ! -d "$dir" ]; do
        dir="$(dirname "$dir")"
    done
    free_gb="$(df --output=avail -BG "$dir" | tail -n 1 | tr -dc '0-9')"
    if [ "$free_gb" -lt "$low_space_gb" ]; then
        warn "only $free_gb GB free under $dir; '$0 clean' removes the test disk and registry"
    fi
}

check_state() {
    case "$command" in
        disk)
            podman image exists "$image" || die "no image $image; run: $0 build"
            ;;
        check)
            [ -f "$disk" ] || die "no disk at $disk; run: $0 disk"
            podman image exists "$guest_ref" || die "no test image $guest_ref; run: $0 disk"
            ;;
        ssh)
            vm_running || die "no VM is running; start one with: $0 check --keep"
            ;;
    esac
    case "$command" in
        build|disk|all)
            warn_if_low_space
            ;;
    esac
}

# Prints the PID of the VM this script started, if it is still running.
vm_pid() {
    local pid
    [ -f "$run_dir/qemu.pid" ] || return 1
    pid="$(cat "$run_dir/qemu.pid")"
    # A stale PID file can name an unrelated process, so match our overlay.
    grep -qF "$run_dir/overlay.qcow2" "/proc/$pid/cmdline" 2>/dev/null || return 1
    printf '%s\n' "$pid"
}

vm_running() {
    vm_pid >/dev/null
}

vm_host() {
    printf 'vsock/%s\n' "$(cat "$run_dir/cid")"
}

# Runs a command as root in the VM, with no input.
vm_ssh() {
    ssh -n "${vm_ssh_options[@]}" "$(vm_host)" "$@"
}

# Runs a command as root in the VM, passing it standard input.
vm_ssh_with_input() {
    ssh -T "${vm_ssh_options[@]}" "$(vm_host)" "$@"
}

boot_id() {
    vm_ssh cat /proc/sys/kernel/random/boot_id 2>/dev/null
}

# Waits until the VM accepts SSH with a boot ID other than PREVIOUS_BOOT_ID.
wait_for_boot() {
    local previous="${1:-}" current deadline=$((SECONDS + boot_timeout_seconds))
    while [ "$SECONDS" -lt "$deadline" ]; do
        current="$(boot_id)" || current=
        if [ -n "$current" ] && [ "$current" != "$previous" ]; then
            return 0
        fi
        sleep 3
    done
    printf 'vm-test.sh: the VM did not come up; last console lines:\n' >&2
    tail -n 30 "$run_dir/console.log" >&2
    return 1
}

stop_vm() {
    local pid
    if pid="$(vm_pid)"; then
        kill "$pid"
        # Wait for QEMU to exit before removing its files.
        timeout 30 tail --pid="$pid" -f /dev/null || true
    fi
    rm -rf "$run_dir"
}

start_vm() {
    stop_vm
    mkdir -p "$run_dir"
    ssh-keygen -q -t ed25519 -N '' -C vm-test -f "$run_dir/id_ed25519"
    # Boot from a throwaway overlay so the installed disk stays pristine.
    qemu-img create -q -f qcow2 -b "$disk" -F qcow2 "$run_dir/overlay.qcow2"
    cp "$ovmf_vars" "$run_dir/OVMF_VARS.fd"
    # Guest context IDs are shared by every VM on the host.
    echo $((RANDOM % 60000 + 1000)) >"$run_dir/cid"
    # systemd-tmpfiles applies this credential at boot. It writes to
    # /var/roothome because /root is a link to it that does not resolve until
    # tmpfiles creates the directory.
    cat >"$run_dir/tmpfiles.conf" <<EOF
d /var/roothome 0700 root root -
d /var/roothome/.ssh 0700 root root -
f+~ /var/roothome/.ssh/authorized_keys 0600 root root - $(base64 -w0 "$run_dir/id_ed25519.pub")
EOF
    qemu-system-x86_64 \
        -machine q35,accel=kvm -cpu host -smp 4 -m 4G \
        -drive if=pflash,format=raw,readonly=on,file="$ovmf_code" \
        -drive if=pflash,format=raw,file="$run_dir/OVMF_VARS.fd" \
        -drive if=virtio,format=qcow2,file="$run_dir/overlay.qcow2" \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -device vhost-vsock-pci,guest-cid="$(cat "$run_dir/cid")" \
        -smbios "type=11,value=io.systemd.credential.binary:tmpfiles.extra=$(base64 -w0 "$run_dir/tmpfiles.conf")" \
        -display none -serial file:"$run_dir/console.log" \
        -daemonize -pidfile "$run_dir/qemu.pid"
    wait_for_boot
}

reboot_vm() {
    local previous
    previous="$(boot_id)"
    vm_ssh systemctl reboot || true
    wait_for_boot "$previous"
}

start_registry() {
    if ! podman container exists "$registry_container"; then
        mkdir -p "$cache_dir/registry"
        podman create --quiet --name "$registry_container" \
            -p 127.0.0.1:5000:5000 \
            -v "$cache_dir/registry:/var/lib/registry:Z" \
            "$registry_image" >/dev/null
    fi
    podman start "$registry_container" >/dev/null
}

# Prints a field of the booted deployment from bootc status: image or digest.
booted() {
    vm_ssh bootc status --format json | python3 -c '
import json, sys
image = json.load(sys.stdin)["status"]["booted"]["image"]
print({"image": image["image"]["image"], "digest": image["imageDigest"]}[sys.argv[1]])
' "$1"
}

# Succeeds if PATH is a symlink to TARGET and resolves to a directory.
links_to() {
    [ "$(vm_ssh readlink "$1")" = "$2" ] && vm_ssh test -d "$1/"
}

# Runs a check command and records whether it passed.
expect() {
    local description="$1"
    shift
    if "$@"; then
        log "PASS: $description"
    else
        printf 'FAIL: %s\n' "$description" >&2
        failures=$((failures + 1))
    fi
}

check_layout() {
    local collection
    expect "booted image is $guest_ref" [ "$(booted image)" = "$guest_ref" ]
    expect "/usr is read-only" \
        vm_ssh 'touch /usr/.vm-test 2>&1 | grep -q "Read-only file system"'
    expect "/etc is writable" vm_ssh 'touch /etc/.vm-test && rm /etc/.vm-test'
    expect "/var is writable" vm_ssh 'touch /var/.vm-test && rm /var/.vm-test'
    expect "/opt links to /var/opt" links_to /opt var/opt
    expect "/srv links to /var/srv" links_to /srv var/srv
    expect "/usr/local links to /var/usrlocal" links_to /usr/local ../var/usrlocal
    expect "ansible-pull runs" vm_ssh 'ansible-pull --version >/dev/null'
    for collection in "${collections[@]}"; do
        expect "collection $collection is installed" \
            vm_ssh "ansible-galaxy collection list $collection 2>/dev/null | grep -q '^$collection '"
    done
}

check_upgrade_and_rollback() {
    local original_digest upgrade_digest
    original_digest="$(booted digest)"

    vm_ssh 'echo vm-test >/etc/homelab-vm-test && echo vm-test >/var/lib/homelab-vm-test'
    # The test registry serves plain HTTP.
    vm_ssh_with_input 'cat >/etc/containers/registries.conf.d/50-vm-test.conf' <<EOF
[[registry]]
location = "${guest_ref%%/*}"
insecure = true
EOF

    start_registry
    printf 'FROM %s\nRUN echo upgrade >%s\n' "$guest_ref" "$upgrade_marker" |
        podman build -q -t "$image:upgrade-test" - >/dev/null
    podman push -q --tls-verify=false --digestfile "$run_dir/upgrade.digest" \
        "$image:upgrade-test" "docker://$host_ref"
    upgrade_digest="$(cat "$run_dir/upgrade.digest")"

    vm_ssh bootc upgrade
    reboot_vm
    expect "upgrade boots the pushed image" [ "$(booted digest)" = "$upgrade_digest" ]
    expect "upgrade adds the new /usr content" vm_ssh "[ -f $upgrade_marker ]"
    expect "/etc changes survive the upgrade" vm_ssh '[ -f /etc/homelab-vm-test ]'
    expect "/var data survives the upgrade" vm_ssh '[ -f /var/lib/homelab-vm-test ]'

    vm_ssh bootc rollback
    reboot_vm
    expect "rollback boots the original image" [ "$(booted digest)" = "$original_digest" ]
    expect "rollback removes the new /usr content" vm_ssh "[ ! -e $upgrade_marker ]"
    expect "/etc changes survive the rollback" vm_ssh '[ -f /etc/homelab-vm-test ]'
    expect "/var data survives the rollback" vm_ssh '[ -f /var/lib/homelab-vm-test ]'
}

cmd_build() {
    podman build \
        -f "$script_dir/Containerfile.$flavor" \
        -t "$image" \
        "$script_dir"
}

cmd_disk() {
    mkdir -p "$cache_dir"
    # bcvk runs the installer in a VM booted from the image and reaches it over
    # SSH on TCP, but workstation images leave sshd.service disabled, so
    # install a test image that enables it. bcvk installs the image under its
    # local name, so the tag is the name the VM pulls updates from.
    printf 'FROM %s\nRUN systemctl enable sshd.service\n' "$image" |
        podman build -q -t "$guest_ref" - >/dev/null
    bcvk to-disk --format qcow2 --filesystem btrfs --disk-size 40G \
        "$guest_ref" "$disk"
}

finish_check() {
    if [ "$keep" = true ] && vm_running; then
        log "The VM is still running. Use: $0 ssh [CMD...], then $0 stop"
    else
        stop_vm
    fi
}

cmd_check() {
    trap finish_check EXIT
    start_vm
    check_layout
    check_upgrade_and_rollback
    [ "$failures" -eq 0 ] || die "$failures check(s) failed"
    log "All checks passed."
}

cmd_ssh() {
    exec ssh "${vm_ssh_options[@]}" "$(vm_host)" "${remote_command[@]}"
}

cmd_clean() {
    stop_vm
    podman rm --force --ignore "$registry_container" >/dev/null
    podman rmi --ignore "$guest_ref" "$image:upgrade-test" >/dev/null
    rm -rf "${cache_dir:?}"
}

main() {
    parse_args "$@"
    validate_args
    set_flavor_names
    check_prerequisites
    check_state
    case "$command" in
        build)
            cmd_build
            ;;
        disk)
            cmd_disk
            ;;
        check)
            cmd_check
            ;;
        all)
            cmd_build
            cmd_disk
            cmd_check
            ;;
        ssh)
            cmd_ssh
            ;;
        stop)
            stop_vm
            ;;
        clean)
            cmd_clean
            ;;
    esac
}

main "$@"
