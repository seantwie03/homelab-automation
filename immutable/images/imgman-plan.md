# imgman: Design & UX Plan

`imgman` (Image Manager) is a CLI tool for building, testing, and managing bootable container (`bootc`) images and virtual machines. Its interface is directly modeled after Podman's command hierarchy and lifecycle semantics.

---

## 1. Core Principles

1. **Hierarchy by Artifact Domain:**
   Commands are organized under four distinct namespaces:
   - **`image`**: Building and validating OCI container images from `Containerfile`s.
   - **`machine`**: Managing virtual machine disks (`.qcow2`), live instances, and remote access.
   - **`test`**: Automated test runners for OS images, upgrades from the current image, and Ansible playbooks.
   - **`system`**: System-wide housekeeping and resource reclamation.

2. **Test is Always Sufficient (Smart Dependency Resolution):**
   - You should never have to manually run `build` or `init` before testing.
     - `test image` and `test upgrade` build the image and compare its content with what the disk was installed from. If the image or the host's kickstart changed, they reinstall the disk before testing. If nothing changed, they skip build and init in under a second and boot directly into the test suite.
     - `test playbook` and `machine run` stay fast: they never build or reinstall, except to install a disk that is missing. When the disk is older than the latest build, they print a one-line warning pointing to `test image`.
   - Staleness compares content, not timestamps, so `git checkout`, rebases, and `touch` never cause a reinstall. See "Dependency Detection Logic" below.

3. **Installer & Filesystem Parity via Kickstart:**
   - Base virtual disks are provisioned using Anaconda and each host's production Kickstart recipe (`images/kickstart/<host>.ks`), the same file that installs the host's hardware.
   - Ensures exact parity with bare-metal hardware: identical Btrfs subvolume layouts (`home` at `/var/home`, nested `.cache`), pre-created user accounts (`sean` with UID 1000), and filesystem permissions. Playbooks encounter no artificial differences between VMs and physical machines.

4. **One Playbook per Host:**
   - Each host converges on its own playbook, `<host>.yml`, which the `ansible_pull` unit selects with `hostname --short`.
   - `--flavor` boots a different image but runs the host's playbook unchanged, including the desktop roles it lists.

5. **Podman-Style Positional Target (`[HOST]`):**
   - Images are named by flavor and machines by host, as Podman names images and machines separately. `image build` accepts an optional positional flavor argument (e.g., `kde`, `kde-nvidia`). Every `machine`, `test`, and `system` command accepts an optional positional host argument (e.g., `desktop22`, `x1carbon2018`).
   - A VM stands in for its host: it boots the host's flavor from a disk installed with the host's Kickstart, its hostname is set to `HOST`, and the host's playbook runs as it does on the host.
   - `images/hosts.toml` maps each host to its flavor. Each host's Kickstart is found by convention at `images/kickstart/<host>.ks`.
   - If `HOST` is omitted, commands default to `hostname --short` when it names a host in `hosts.toml`, and exit with a usage error otherwise. If `FLAVOR` is omitted, `image build` builds the default host's flavor.
   - Commands accept `--all` (or `-a`) to target every host in `hosts.toml`. On `image build`, `--all` targets every flavor discovered dynamically on disk (`Containerfile.*`), so flavors no host uses are still built and linted.
   - `--flavor NAME` on `machine init`, `machine run`, and the `test` commands boots a host on a flavor other than its own, such as `desktop22` on `niri` before switching it to that desktop. Each host keeps one disk per flavor, so the override never replaces the host's normal disk.

6. **Persistent by Default, Fresh on `machine run`:**
   - In alignment with `podman machine start` and `podman run`, test VMs remain running after execution. This preserves live state for immediate debugging and inspection via `imgman machine ssh` or `imgman machine gui`.
   - **`machine run` always resets:** Each call to `imgman machine run [HOST]` is guaranteed to produce a clean baseline. Each host runs at most one VM at a time. If that host's VM is already running, it is immediately terminated, its old overlay is discarded, and a brand-new throwaway copy-on-write overlay is booted.
   - The `--rm` flag enables ephemeral execution on test commands, automatically terminating the VM and discarding the copy-on-write overlay when validation completes (ideal for CI and batch pipelines).
   - `machine run`, `test image`, and `test upgrade` always boot fresh, so they replace any VM the host is running, including one you are using. `test playbook` reuses a running VM. Any test command with `--rm` stops the VM when it finishes. Whenever a command replaces a running VM, it prints one line first, such as `stopping desktop22's running VM`.

7. **Multi-VM Concurrency & Isolation:**
   - Workstations (e.g., desktop22, desktop25 with 64 GB RAM and multi-core Intel CPUs) can run several VMs concurrently.
   - Each host maintains an isolated runtime directory (`~/.cache/homelab-images/<host>/run/`), independent PID file, ephemeral overlay, random vsock context ID (CID), and SPICE display socket (`run/spice.sock`).
   - Running `imgman machine run --all` leaves all booted VMs running in parallel without collisions: each display socket lives in its host's `run/` directory, and a CID already in use is retried (see "Vsock CID Allocation").

8. **Virtual Graphics by Default, Explicit Viewer via `imgman machine gui`:**
   - Both `machine run` and `test` commands boot with virtual graphics hardware (`-device virtio-vga`) and a SPICE display server on a Unix socket enabled by default (unless `--no-gui` is passed). Nothing listens on the network, not even on loopback.
   - `remote-viewer` is **not** launched automatically, keeping your terminal focused and preventing unwanted popups.
   - When you want to inspect the graphical desktop, display manager (SDDM), or compositor, simply run `imgman machine gui [HOST]` to connect `remote-viewer` to that host's SPICE socket.
   - For automated CI or headless terminal workflows, pass `--no-gui` to boot QEMU with `-display none`.

---

## 2. Command Reference

```text
imgman
├── image
│   ├── build   [FLAVOR] [--all]
│   └── promote [FLAVOR]
│
├── machine
│   ├── init  [HOST] [--all] [--flavor NAME]
│   ├── run   [HOST] [--all] [--flavor NAME] [--no-gui]
│   ├── gui   [HOST]
│   ├── ssh   [HOST] [COMMAND...]
│   └── rm    [HOST] [--all]
│
├── test
│   ├── playbook [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
│   ├── image    [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
│   ├── upgrade  [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
│   └── all      [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]
│
└── system
    └── prune [HOST] [--all] [--disks]
```

---

### Domain: `image`

#### `imgman image build [FLAVOR] [--all]`
- **Purpose:** Compiles the OCI container image and executes `bootc container lint --fatal-warnings`.
- **Under the hood:** Runs `podman build -f images/Containerfile.<flavor> -t localhost/workstation-<flavor> images`.
- **Options:**
  - `FLAVOR`: Target flavor to build (default: the default host's flavor).
  - `-a, --all`: Builds and lints all flavors discovered in `images/Containerfile.*`.

#### `imgman image promote [FLAVOR]`
- **Purpose:** Marks the latest build of a flavor as the current image: the image hosts are assumed to run, which `test upgrade` upgrades from.
- **Under the hood:**
  1. Looks up the image ID of `localhost/workstation-<flavor>`.
  2. Refuses unless that image ID passed `test image` on every host that uses the flavor in `images/hosts.toml`, and, when a current image already exists, `test upgrade` on those hosts too. The first promotion of a flavor has no current image to upgrade from, so it requires only `test image`.
  3. Tags the build as `localhost/workstation-<flavor>:current`.
- **Options:**
  - `FLAVOR`: Flavor to promote (default: the default host's flavor).
- Once images are published, the current image is the oldest published image a host runs, and `test upgrade` pulls it from GHCR instead.

---

### Domain: `machine`

#### `imgman machine init [HOST] [--all] [--flavor NAME]`
- **Purpose:** Explicitly provisions a bootable virtual disk (`.qcow2`) for a host, using the host's production Kickstart layout and the host's flavor image.
- **Under the hood:**
  1. Starts the local container registry (`homelab-image-registry`) on `127.0.0.1:5000` and pushes `localhost/workstation-<flavor>` to `127.0.0.1:5000/<host>/workstation-<flavor>:test`.
  2. Extracts `images/pxeboot/vmlinuz` and `initrd.img` from the cached Fedora netinst ISO with `xorriso -osirrox`, and appends a cpio archive holding `images/kickstart/<host>.ks` as `ks.cfg` to the initrd, as `virt-install --initrd-inject` does.
  3. Boots QEMU directly into that kernel and initrd (`-kernel`, `-initrd`), with the ISO attached for the installer's stage 2, a blank target disk, and `-no-reboot`. The kernel command line is `inst.ks=file:/ks.cfg inst.stage2=hd:LABEL=<ISO label> inst.text console=ttyS0 imgman.url=10.0.2.2:5000/<host>/workstation-<flavor>:test imgman.disk=vda`. imgman reads the ISO label with `xorriso`. desktop22 also gets a second blank disk, `vdb`, standing in for its games SSD.
  4. The kickstart's `%pre` sees the `imgman.*` arguments and selects the test registry and `vda` (see "Kickstart Targets" below). Anaconda pulls the image from `10.0.2.2:5000`, partitions the disk with production Btrfs subvolumes (`home` at `/var/home`, nested `.cache`), provisions user `sean` (UID 1000), and installs the bootloader. The installer's output goes to `run/console.log`.
  5. The kickstart ends with `reboot`, which `-no-reboot` turns into QEMU exiting, leaving `~/.cache/homelab-images/<host>/workstation-<flavor>.qcow2`. Later boots start from the disk, without `-kernel`.
  6. Writes `workstation-<flavor>.inputs` next to the disk, recording the installed image ID and the kickstart's SHA-256, for the staleness check.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Provisions disks for every host in `images/hosts.toml`.
  - `--flavor NAME`: Installs `NAME` instead of the host's flavor.

#### `imgman machine run [HOST] [--all] [--flavor NAME] [--no-gui]`
- **Purpose:** Boots the host's virtual disk with a fresh throwaway copy-on-write overlay and leaves it running for interactive use (no automated assertions, no reboots, no test markers). Always terminates the host's currently running VM, if any, and resets to a clean overlay.
- **Under the hood:**
  1. Checks if a VM for `HOST` is running; if so, immediately terminates the QEMU process (`SIGTERM` / `SIGKILL`) and unlinks its runtime directory.
  2. Discards any previous ephemeral overlay and creates a fresh `overlay.qcow2` backed by the host's disk for the selected flavor. Runs `machine init` first only if the disk is missing, and warns if it is stale, without building.
  3. Picks a random vsock CID and stores it in `run/cid`.
  4. Spawns QEMU with KVM acceleration, OVMF UEFI firmware, vsock SSH, virtio-vga graphics, a SPICE server on `run/spice.sock`, and systemd credentials: `system.hostname`, which sets the VM's hostname to `HOST`; `tmpfiles.extra`, which installs the one-time root SSH key; and `systemd.unit-dropin.ansible-pull.service`, which keeps `ansible-pull` from replacing the synced tree (see `test playbook`).
  5. Leaves the VM booted and ready for interactive SSH (`imgman machine ssh`) or graphical inspection (`imgman machine gui`).
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Sequentially resets and boots every host, leaving all of them running in parallel, each with its own SPICE socket.
  - `--flavor NAME`: Boots the host's disk for `NAME` instead of the host's flavor.
  - `--no-gui`: Disables the virtual display and SPICE socket; runs QEMU headless (`-display none`).

#### `imgman machine gui [HOST]`
- **Purpose:** Launches `remote-viewer` to view and interact with the graphical desktop of a running VM.
- **Under the hood:**
  1. Checks if the VM for `HOST` is running; if not, informs the user to run `imgman machine run [HOST]` first.
  2. Spawns `remote-viewer spice+unix://$HOME/.cache/homelab-images/<host>/run/spice.sock`.
- **Options:**
  - `HOST`: Target host to inspect (default: this machine's short hostname).

#### `imgman machine ssh [HOST] [COMMAND...]`
- **Purpose:** Connects to a running VM over vsock SSH without exposing network ports on the host LAN.
- **Behavior:**
  - If the first word is a host in `images/hosts.toml`, it selects the host. Otherwise every word is part of `COMMAND...`, which runs on the default host. `imgman machine ssh nvim --version` runs on the default host; `imgman machine ssh desktop25 nvim --version` runs on `desktop25`.
  - If `COMMAND...` is provided, executes the command as root inside the VM and prints the output.
  - If omitted, opens an interactive root shell inside the VM.
- **Options:**
  - `HOST`: Target host if multiple VMs are running (default: this machine's short hostname).

#### `imgman machine rm [HOST] [--all]`
- **Purpose:** Terminates the VM process and deletes its ephemeral runtime overlay and sockets.
- **Under the hood:** Immediately kills the QEMU process (`SIGTERM` / `SIGKILL`) to release host memory and vsock CIDs, then removes the ephemeral `run/` directory containing `overlay.qcow2`.
- **Options:**
  - `HOST`: Removes a specific host's running VM instance (default: this machine's short hostname).
  - `-a, --all`: Removes running VM instances across all hosts.

---

### Domain: `test`

`test image` and `test upgrade` build the image and reinstall stale disks. `test playbook` uses the disk it finds, installing one only if it is missing and warning if it is stale. `test all` runs `test image` first, so its playbook run always gets a current disk.

#### `imgman test playbook [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** Tests Ansible playbook convergence and idempotence for a host against uncommitted local code.
- **Under the hood:**
  1. Ensures the host's VM is running; if not, boots it with a fresh throwaway overlay, as `machine run` does: installing the disk only if it is missing and warning if it is stale (virtual graphics enabled by default; inspect live via `imgman machine gui` unless `--no-gui` is specified).
  2. Uses `rsync --delete` over vsock SSH to sync the host's working tree, including uncommitted and untracked changes, into `/opt/homelab-automation` inside the VM (< 200ms).
     - Excludes `.git` and anything matched by `.gitignore` (`--exclude=.git --filter=':- .gitignore'`), to keep the sync fast.
     - Once the playbook converges, `ansible-pull.timer` is enabled in the VM. A `systemd.unit-dropin.ansible-pull.service` credential, passed at every boot, adds `ConditionVirtualization=!vm` to the service, so the timer fires but the service is skipped instead of replacing the synced tree with the published branch. A skipped unit is not a failed unit, and the playbook's timer tasks still pass. The drop-in exists only while imgman boots the VM and is never written to the disk.
     - rsync treats `vsock/CID:/path` as a local path, because a slash comes before the colon. imgman gives rsync a plain host alias and passes the vsock target through `-e 'ssh -o ProxyCommand=...'` instead.
  3. **First Run (Convergence):** Runs `ansible-playbook` against the synced tree, with the same playbook, inventory, and limit that the `ansible_pull` unit on `HOST` passes to `ansible-pull`. `ansible-pull` is not used because it requires `--url` and updates the checkout from git, which would discard or refuse the synced changes. Asserts a zero exit status and `failed=0`.
  4. **Second Run (Idempotency):** Runs the same `ansible-playbook` command a second time. Asserts **`changed=0`** and `failed=0` in the play recap.
  5. Leaves the VM running for immediate debugging unless `--rm` is passed.
- **Options:**
  - `HOST`: Target host to test (default: this machine's short hostname).
  - `-a, --all`: Sequentially runs playbook tests across all hosts.
  - `--flavor NAME`: Tests the host's configuration on `NAME` instead of the host's flavor.
  - `--rm`: Automatically shuts down the VM upon test completion.
  - `--no-gui`: Runs headless with `-display none`.

#### `imgman test image [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** The fast loop for Containerfile and kickstart changes. Tests that a fresh install of the latest build, made with the host's kickstart, boots into a working system. It does not upgrade; `test upgrade` covers upgrades.
- **Under the hood:**
  1. **Smart Dependency Check:** Always runs `podman build` for the host's flavor; on a cache hit this finishes in < 0.5s and the image ID is unchanged. If the disk is missing or stale (see "Dependency Detection Logic"), automatically runs `machine init` to refresh the host's disk.
  2. Boots the VM with a fresh throwaway overlay (virtual graphics enabled by default; inspect live via `imgman machine gui` unless `--no-gui` is specified).
  3. Asserts filesystem invariants: `/usr` read-only, `/etc` and `/var` writable, `/srv -> /var/srv`.
  4. Asserts the kickstart's layout: `home` is a subvolume at `/var/home`, a file `sean` writes under `~/.cache` is absent from a snapshot of `home`, `sean` has UID 1000, and on desktop22 the stand-in games disk `vdb` is untouched.
  5. Asserts the boot reached `graphical.target` and the display manager is active, then runs the no-failed-units check (see "No Failed Units Check").
  6. Marks the test registry insecure in the VM over SSH, then runs `bootc upgrade --check`, which confirms the VM can reach the tag it tracks and that the image's signature policy accepts it, without downloading or rebooting.
  7. Records that the image ID passed on `HOST`, for `image promote`.
  8. Leaves the VM running unless `--rm` is passed.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Sequentially tests all hosts.
  - `--flavor NAME`: Tests `NAME` instead of the host's flavor.
  - `--rm`: Automatically shuts down the VM upon test completion.
  - `--no-gui`: Runs headless with `-display none`.

#### `imgman test upgrade [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** The thorough test, run before `image promote` and in CI, not while iterating. Tests that the working tree's playbook converges on a host running the current image, that upgrading that host to the latest build keeps it converged and working, and that rolling back does too.
- **Cached disks:** Installing and first converging a workstation are the slow parts, so both are cached per host and flavor, and rebuilt only when the current image changes:
  - `workstation-<flavor>-current.qcow2`: installed with the host's kickstart from `localhost/workstation-<flavor>:current`, pushed to `<host>/workstation-<flavor>:upgrade`. The VM tracks that tag, which `test image` never uses.
  - `workstation-<flavor>-converged.qcow2`: a copy-on-write layer on the current disk, holding the result of one playbook run at the time it was made.
  - Starting from a converged disk matches a real host: converged with an older playbook, then receiving the new playbook, and later the new image.
- **Under the hood:**
  1. Builds the latest image, as `test image` does. Exits with an error if the flavor has no current image, pointing to `image promote`.
  2. Rebuilds the cached disks if they are missing or stale: their `.inputs` file records a different `:current` image ID or kickstart hash.
  3. Boots the converged disk with a fresh throwaway overlay and runs the no-failed-units check. Syncs the working tree and runs the playbook twice, as `test playbook` does, then runs the capability tests.
  4. Pushes the latest build to `<host>/workstation-<flavor>:upgrade`, runs `bootc upgrade`, and reboots. `bootc upgrade` pulls only the layers that changed. Asserts the VM booted the new digest and runs the no-failed-units check, then runs the playbook twice, the capability tests, and the no-failed-units check again.
  5. Runs `bootc rollback` and reboots. Asserts the VM booted the current image's digest, runs the no-failed-units check, and runs the capability tests.
  6. Records that the image ID passed on `HOST`, for `image promote`.
  7. Leaves the VM running unless `--rm` is passed.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Sequentially tests all hosts.
  - `--flavor NAME`: Tests `NAME` instead of the host's flavor.
  - `--rm`: Automatically shuts down the VM upon test completion.
  - `--no-gui`: Runs headless with `-display none`.

#### `imgman test all [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** Full regression testing of the latest build. Sequentially executes `test image` (with auto-build/auto-init) followed by `test playbook`. It does not run `test upgrade`, which stays a separate step before promotion.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Runs complete regression across all hosts, each on the flavor it runs.
  - `--flavor NAME`: Runs the regression on `NAME` instead of the host's flavor.
  - `--rm`: Shuts down VMs upon completion.
  - `--no-gui`: Runs headless with `-display none`.

---

### Domain: `system`

#### `imgman system prune [HOST] [--all] [--disks]`
- **Purpose:** Safely reclaims storage without interrupting active work or deleting cached downloads.
- **Safety Guarantees:**
  - **Never touches running VMs:** If a host's VM is active, its overlay, disks, and runtime files are skipped.
  - **Never deletes the ISO:** `~/.cache/homelab-images/iso/*.iso` is preserved as a permanent asset.
- **Under the hood:**
  1. Inspects `~/.cache/homelab-images/<host>/run/`: checks `qemu.pid` with `os.kill(pid, 0)`. If the process is dead or missing, cleans up orphaned `run/` directories (dead overlays, stale keys/sockets from previous crashes). Actively running VMs are left untouched.
  2. With `--all`, and only when no VM of any host is running, stops and removes the shared `homelab-image-registry` container and deletes its storage in `~/.cache/homelab-images/registry/`. Pruning a single host never touches the registry.
  3. Removes the host's test registry tags from local Podman storage (`127.0.0.1:5000/<host>/...`), leaving `localhost/workstation-<flavor>` and its `:current` tag untouched.
  4. If `--disks` is passed: deletes the host's base, current, and converged `.qcow2` disks if the host is **inactive** (skipping any host whose VM is currently running).
- **Options:**
  - `HOST`: Target host to prune (default: this machine's short hostname).
  - `-a, --all`: Prunes across all hosts discovered in cache, and the shared registry when no VM is running.
  - `-d, --disks`: In addition to default cleanup, removes base `.qcow2` virtual disks for inactive hosts.

---

## 3. Workflows

### Scenario 1: Changing Playbooks / Roles / Dotfiles (95% Daily Loop)
You edit tasks or dotfiles on the host and want to test them before committing:

```sh
# 1. Boot a fresh VM of this machine into the background (always stops existing session and resets overlay):
imgman machine run

# 2. View the graphical desktop at any time without blocking your terminal:
imgman machine gui

# 3. Sync uncommitted host changes and test playbook convergence & idempotency:
#    (Reuses the warm running VM for fast < 2s iterations)
imgman test playbook

# 4. Want to verify cold-start convergence on a fresh, clean VM?
#    Simply reset with machine run, then test:
imgman machine run
imgman test playbook

# 5. Interactively verify or explore via shell:
imgman machine ssh nvim --version
imgman machine ssh

# 6. Test another host's configuration:
imgman test playbook desktop25

# 7. Clean pre-commit run (runs convergence + idempotency, then tears down):
imgman test playbook --rm
```

### Scenario 2: Changing the Base Image or Kickstart (5% Low-Frequency Loop)
You edit `Containerfile.kde`, `scripts/ansible.sh`, or `kickstart/<host>.ks`:

```sh
# One command does it all: detects changes, builds image, inits disk, runs tests:
imgman test image

# Open GUI viewer whenever desired to inspect the running desktop:
imgman machine gui

# Headless batch/CI run (no virtual display):
imgman test image --rm --no-gui

# Build and lint every flavor, including flavors no host uses:
imgman image build --all

# Try a host on a flavor it does not run yet, before switching it:
imgman test all desktop22 --flavor niri
```

### Scenario 3: Pre-Commit Full Verification
```sh
# Runs OS image test and playbook idempotence for every host on its flavor (pass --no-gui for batch CI):
imgman test all --all --rm
```

### Scenario 4: Promoting a Build
```sh
# Upgrade every host from the current image to the latest build, then promote it:
imgman test upgrade --all --rm --no-gui
imgman image promote kde
```

---

## 4. Technical Architecture & Implementation Details

### Dependency Detection Logic
A disk's inputs are the image ID it was installed from and the SHA-256 of the host's kickstart. `machine init` records both in a `.inputs` file next to the disk. A disk is stale when the file is missing or either value differs:

```python
flavor = args.flavor or hosts[host]["flavor"]
image = f"localhost/workstation-{flavor}"
disk_path = cache_dir / host / f"workstation-{flavor}.qcow2"
inputs_path = disk_path.with_suffix(".inputs")
kickstart_path = images_dir / "kickstart" / f"{host}.ks"

expected = {
    "image_id": run(["podman", "image", "inspect", "-f", "{{.Id}}", image]),
    "kickstart_sha256": hashlib.sha256(kickstart_path.read_bytes()).hexdigest(),
}
recorded = json.loads(inputs_path.read_text()) if inputs_path.exists() else None

stale = not disk_path.exists() or recorded != expected
```

- The image ID is derived from the image's content, so a `podman build` cache hit keeps it, and a rebuild with any change replaces it. File timestamps play no part, so `git checkout` and `touch` never cause a reinstall.
- The kickstart is the only kickstart input: its one `%include` names the file `%pre` writes, not a file in the repository.
- Disks are kept per flavor, so a flavor change in `hosts.toml` selects a different disk, which is missing or stale on its own terms.
- `test upgrade`'s current and converged disks use the same check, with the `:current` image ID in place of the latest build's.
- `test image` and `test upgrade` build first, then reinstall stale disks. `test playbook` and `machine run` don't build; they compare the disk with whatever `localhost/workstation-<flavor>` currently is and only warn.

### No Failed Units Check
`test image` runs it after its boot, and `test upgrade` after every boot and after the playbook converges on the new build:

1. Runs `systemctl is-system-running --wait` in the VM, which waits until startup finishes. `running` passes; `degraded` means at least one unit failed.
2. On failure, prints `systemctl --failed` and the last journal lines of each failed unit, so the cause shows without logging in.

A unit skipped by a condition, such as `ansible-pull.service` in the VM, is not failed and does not trip the check.

### Host and Kickstart File Organization
`images/hosts.toml` maps each host to its flavor, and each host has one Kickstart under `images/kickstart/`:
```text
images/
├── Containerfile.kde
├── Containerfile.kde-nvidia
├── hosts.toml
└── kickstart/
    ├── desktop22.ks      # Includes the secondary /games disk
    ├── desktop25.ks
    └── x1carbon2018.ks
```

```toml
[desktop22]
flavor = "kde-nvidia"

[desktop25]
flavor = "kde-nvidia"

[x1carbon2018]
flavor = "kde"
```

imgman reads `hosts.toml` with the standard library's `tomllib`. A flavor that no host lists is still built by `image build --all` and can be tested on any host with `--flavor`.

### Installer ISO
imgman never downloads the installer. The Fedora netinst ISO is a prerequisite you download, verify, and place yourself:

- **Location:** `~/.cache/homelab-images/iso/`, named as Fedora publishes it, such as `Fedora-Everything-netinst-x86_64-44-1.7.iso`.
- **Version:** the Fedora major version must match the Containerfiles' `FEDORA_MAJOR_VERSION`, so Anaconda and the image move to a new release together. Exactly one ISO for that version must be present.
- **Checked early:** `machine init`, `test image`, and `test all` check for the ISO in the prerequisite check, before building or booting anything, so a missing ISO fails in under a second. Other commands never need it.

When the ISO is missing, imgman lists it with the other missing prerequisites and exits 1:

```text
imgman: missing prerequisites:
    the Fedora 44 netinst ISO in ~/.cache/homelab-images/iso/
        Download Fedora-Everything-netinst-x86_64-44-*.iso and its CHECKSUM file from
        https://download.fedoraproject.org/pub/fedora/linux/releases/44/Everything/x86_64/iso/
        then verify and place it as described in "Installer ISO" in images/README.md.
```

When two or more ISOs match the version, imgman names them and asks you to remove all but one. `images/README.md` documents the download, verifying the `CHECKSUM` file's signature with Fedora's release key, and checking the ISO's SHA-256 against it.

### Local Registry & Installer Networking
Anaconda inside QEMU pulls the container image via QEMU's virtual user networking:
- Host loopback: `127.0.0.1:5000` (where `homelab-image-registry` container listens).
- Guest alias: `10.0.2.2:5000` (QEMU automatically forwards `10.0.2.2` to host loopback).
- Each host and flavor has its own repository, `<host>/workstation-<flavor>`, which the VM installs from and later upgrades from. Pushing a build for one host never changes what another host's VM installs or upgrades to, even when both hosts use the same flavor.
- Each host and flavor has two tags: `:test`, which base disks track, and `:upgrade`, which current disks track. `test image` and `test upgrade` never push to each other's tag.
- The registry serves plain HTTP. The kickstart's `%pre` marks it insecure for the installer, and imgman marks it insecure in the installed VM over SSH before running `bootc upgrade --check` or `bootc upgrade`.

### Kickstart Targets
Each host has one kickstart, `images/kickstart/<host>.ks`, which installs both the hardware and the VM. Only the image URL and the system disk differ. The kickstart leaves both out of its top-level commands; its `%pre` writes them to `/tmp/target.ks`, which the kickstart then includes. Anaconda resolves `%include` after `%pre` runs.

```text
%pre --erroronfail
url=$(sed -n 's/.*imgman\.url=\([^ ]*\).*/\1/p' /proc/cmdline)
if [ -n "$url" ]; then
    disk=$(sed -n 's/.*imgman\.disk=\([^ ]*\).*/\1/p' /proc/cmdline)
    printf '[[registry]]\nlocation = "%s"\ninsecure = true\n' "${url%%/*}" \
        >/etc/containers/registries.conf.d/50-imgman.conf
else
    url=ghcr.io/seantwie03/workstation-kde-nvidia:stable
    disk=disk/by-id/nvme-EXAMPLE
fi
cat >/tmp/target.ks <<EOF
ostreecontainer --url=$url --no-signature
ignoredisk --only-use=$disk
EOF
%end

%include /tmp/target.ks
```

- **Hardware:** booted with `inst.ks=https://...` or from a USB stick, with no `imgman.*` arguments, so `%pre` uses the hardware values written in the file.
- **VM:** `machine init` passes `imgman.url` and `imgman.disk`. `--flavor` changes only `imgman.url`.
- The kickstart names the system disk only in `ignoredisk`. `clearpart --all` and `part` lines without `--ondisk` then apply to that one disk, so every other disk, such as desktop22's games SSD, is left alone in both targets.
- `ksvalidator` cannot see the included commands, so imgman's unit tests validate each kickstart with both targets' commands filled in.

### Graphical Display & Viewer Architecture
- **Virtual Display by Default:** Desktop images run Wayland compositors (KWin for KDE Plasma, Niri) and display managers (SDDM). Both `machine run` and `test` commands configure virtual graphics hardware (`-device virtio-vga`) and serve the display over SPICE on a Unix socket (`-spice unix=on,addr=<run dir>/spice.sock,disable-ticketing=on`) by default.
- **Explicit Viewer (`imgman machine gui`):** To avoid unwanted popups and keep the terminal focused during test runs, `remote-viewer` is **not** launched automatically. When graphical inspection is needed, running `imgman machine gui [HOST]` launches `remote-viewer spice+unix://<run dir>/spice.sock`.
- **Local Socket, No Ports:** Each VM's socket lives in its host's `run/` directory, so `imgman machine run --all` runs several GUI sessions at once with nothing to allocate. Only your user can reach the socket, through the `run/` directory's permissions, so SPICE needs no password.
- **Guest Integration:** With `spice-vdagent` running in the guest, SPICE shares the clipboard and resizes the guest display to the viewer window. The prototype checks whether the image ships it.
- **Headless Opt-Out (`--no-gui`):** When `--no-gui` is passed, QEMU is launched with `-display none` and no SPICE socket is opened, conserving host resources.

### Requirements
Before doing any work, imgman checks what the command needs, lists everything missing at once, and exits 1. Each check applies only to the commands that need it, so a missing `remote-viewer` fails only `machine gui`.

| Where | Needs | Used for |
| --- | --- | --- |
| Host | `podman`, `qemu-system-x86_64`, `qemu-img`, `edk2-ovmf`, `qemu-ui-spice-core` | Builds, VMs, UEFI firmware, the SPICE display |
| Host | `xorriso` | Extracting the kernel, initrd, and volume label from the ISO |
| Host | `remote-viewer` (`virt-viewer`) | `machine gui` |
| Host | `rsync`, `ssh`, and an ssh configuration that sends `vsock/` hosts through `systemd-ssh-proxy` | Vsock SSH and the `test playbook` sync |
| Host | Read and write access to `/dev/kvm` and `/dev/vhost-vsock` | KVM and vsock |
| Host | The Fedora netinst ISO | `machine init` (see "Installer ISO") |
| Image | `rsync` | Receiving the `test playbook` sync |
| Image | `spice-vdagent` (optional) | Clipboard sharing and display resizing |

Workstations that run imgman are bootc hosts, so the host packages come from the workstation image, not a runtime role. Image packages missing from the base image are added to the image's build scripts.

### Vsock CID Allocation
Guest context IDs are shared by every VM on the machine, including VMs imgman did not start. imgman picks a random CID between 1000 and 60999. If QEMU fails to start because the CID is in use, imgman picks another and retries, up to 5 times, then fails with QEMU's error.

### Filesystem Layout per Host
To allow multiple hosts to build, run, and be inspected simultaneously without file collisions:

```text
~/.cache/homelab-images/
├── iso/
│   └── Fedora-Everything-netinst-x86_64-44-1.7.iso  # Installer ISO, placed by you
├── registry/                                     # Shared test registry storage
├── desktop22/
│   ├── workstation-kde-nvidia.qcow2              # Base disk (Kickstart provisioned)
│   ├── workstation-kde-nvidia.inputs             # Image ID and kickstart hash it was installed from
│   ├── workstation-kde-nvidia-current.qcow2      # Current image, for test upgrade
│   ├── workstation-kde-nvidia-converged.qcow2    # Converged layer on the current disk
│   ├── workstation-niri.qcow2                    # Only after --flavor niri
│   ├── passed/                                   # Image IDs that passed, for image promote
│   └── run/                                      # Ephemeral runtime directory
│       ├── qemu.pid                              # QEMU process ID
│       ├── cid                                   # Vsock guest context ID
│       ├── spice.sock                            # SPICE display socket
│       ├── id_ed25519                            # Ephemeral SSH private key
│       ├── overlay.qcow2                         # Throwaway copy-on-write overlay
│       ├── OVMF_VARS.fd                          # Per-VM UEFI NVRAM copy
│       └── console.log                           # Serial console output
└── desktop25/
    ├── workstation-kde-nvidia.qcow2
    └── run/
        ├── qemu.pid
        ├── cid
        ├── spice.sock
        └── overlay.qcow2
```

The registry is shared because one `homelab-image-registry` container serves every host. Repositories are named per host and flavor (`desktop22/workstation-kde-nvidia`), so hosts never collide on tags.

### Argument Parsing Structure
Implemented using nested `argparse` subparsers:
- Root: `imgman`
  - Subparser: `image` $\rightarrow$ `build`, `promote`
  - Subparser: `machine` $\rightarrow$ `init`, `run`, `gui`, `ssh`, `rm`
  - Subparser: `test` $\rightarrow$ `playbook`, `image`, `upgrade`, `all`
  - Subparser: `system` $\rightarrow$ `prune`

`image build` and `image promote` accept `[flavor]` as an optional positional argument, defaulting to the default host's flavor. Every other subparser accepts `[host]` as an optional positional argument, defaulting to `hostname --short` when it names a host in `images/hosts.toml`, alongside `-a, --all` flags where appropriate.
- `--flavor NAME`: Available on `machine init`, `machine run`, and all `test` subcommands to use a flavor other than the host's.
- `--no-gui`: Available on `machine run` and all `test` subcommands (`playbook`, `image`, `upgrade`, `all`) to disable virtual graphics and run headless (`-display none`).
- `--rm`: Available on all `test` subcommands to automatically remove the VM instance and its ephemeral overlay upon test completion.
- `-d, --disks`: Available on `system prune` to remove base `.qcow2` virtual disks for inactive hosts.
