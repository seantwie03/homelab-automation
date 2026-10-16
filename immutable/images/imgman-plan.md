# imgman: Design & UX Plan

`imgman` (Image Manager) is a CLI tool for building, testing, and managing bootable container (`bootc`) images and virtual machines. Its interface is directly modeled after Podman's command hierarchy and lifecycle semantics.

---

## 1. Core Principles

1. **Hierarchy by Artifact Domain:**
   Commands are organized under four distinct namespaces:
   - **`image`**: Building and validating OCI container images from `Containerfile`s.
   - **`machine`**: Managing virtual machine disks (`.qcow2`), live instances, and remote access.
   - **`test`**: Automated test runners for OS images, upgrade/rollback, and Ansible playbooks.
   - **`system`**: System-wide housekeeping and resource reclamation.

2. **Test is Always Sufficient (Smart Dependency Resolution):**
   - You should never have to manually run `build` or `init` before testing. Running `imgman test ...` automatically checks dependencies:
     - If image source files or Kickstarts have changed, `imgman test image` automatically rebuilds the image and re-provisions the disk before testing.
     - If nothing has changed, it skips build and init in under a second and boots directly into the test suite.
   - The base `.qcow2` disk is mounted strictly read-only by QEMU (writes go exclusively to `overlay.qcow2`), keeping `disk.mtime` frozen and reliable.

3. **Installer & Filesystem Parity via Kickstart:**
   - Base virtual disks are provisioned using Anaconda and each host's production Kickstart recipe (`images/kickstart/<host>.ks`), the same file that installs the host's hardware.
   - Ensures exact parity with bare-metal hardware: identical Btrfs subvolume layouts (`home` at `/var/home`, nested `.cache`), pre-created user accounts (`sean` with UID 1000), and filesystem permissions. Playbooks encounter no artificial differences between VMs and physical machines.

4. **Unified Playbook Architecture (`site.yml`):**
   - All hosts and all flavors converge on a single universal playbook: `site.yml`.
   - Flavor-specific desktop roles (`wm/kde`, `wm/niri`) are included dynamically based on the booted image fact (`ansible_local.desktop.flavor`). Host-specific differences are driven by `host_vars/`.

5. **Podman-Style Positional Target (`[HOST]`):**
   - Images are named by flavor and machines by host, as Podman names images and machines separately. `image build` accepts an optional positional flavor argument (e.g., `kde`, `kde-nvidia`). Every `machine`, `test`, and `system` command accepts an optional positional host argument (e.g., `desktop22`, `x1carbon2018`).
   - A VM stands in for its host: it boots the host's flavor from a disk installed with the host's Kickstart, its hostname is set to `HOST`, and the playbook runs with the host's inventory and `host_vars/`.
   - `images/hosts.toml` maps each host to its flavor. Each host's Kickstart is found by convention at `images/kickstart/<host>.ks`.
   - If `HOST` is omitted, commands default to `hostname --short` when it names a host in `hosts.toml`, and exit with a usage error otherwise. If `FLAVOR` is omitted, `image build` builds the default host's flavor.
   - Commands accept `--all` (or `-a`) to target every host in `hosts.toml`. On `image build`, `--all` targets every flavor discovered dynamically on disk (`Containerfile.*`), so flavors no host uses are still built and linted.
   - `--flavor NAME` on `machine init`, `machine run`, and the `test` commands boots a host on a flavor other than its own, such as `desktop22` on `niri` before switching it to that desktop. Each host keeps one disk per flavor, so the override never replaces the host's normal disk.

6. **Persistent by Default, Fresh on `machine run`:**
   - In alignment with `podman machine start` and `podman run`, test VMs remain running after execution. This preserves live state for immediate debugging and inspection via `imgman machine ssh` or `imgman machine gui`.
   - **`machine run` always resets:** Each call to `imgman machine run [HOST]` is guaranteed to produce a clean baseline. Each host runs at most one VM at a time. If that host's VM is already running, it is immediately terminated, its old overlay is discarded, and a brand-new throwaway copy-on-write overlay is booted.
   - The `--rm` flag enables ephemeral execution on test commands, automatically terminating the VM and discarding the copy-on-write overlay when validation completes (ideal for CI and batch pipelines).

7. **Multi-VM Concurrency & Isolation:**
   - Workstations (e.g., desktop22, desktop25 with 64 GB RAM and multi-core Intel CPUs) can run several VMs concurrently.
   - Each host maintains an isolated runtime directory (`~/.cache/homelab-images/<host>/run/`), independent PID file, ephemeral overlay, random vsock context ID (CID), and dedicated VNC display port (e.g., 5900, 5901).
   - Running `imgman machine run --all` leaves all booted VMs running in parallel without port or socket collisions.

8. **Virtual Graphics by Default, Explicit Viewer via `imgman machine gui`:**
   - Both `machine run` and `test` commands boot with virtual graphics hardware (`-device virtio-vga`) and a local VNC listener enabled by default (unless `--no-gui` is passed).
   - `remote-viewer` is **not** launched automatically, keeping your terminal focused and preventing unwanted popups.
   - When you want to inspect the graphical desktop, display manager (SDDM), or compositor, simply run `imgman machine gui [HOST]` to connect `remote-viewer` to that host's allocated VNC port.
   - For automated CI or headless terminal workflows, pass `--no-gui` to boot QEMU with `-display none`.

---

## 2. Command Reference

```text
imgman
├── image
│   └── build [FLAVOR] [--all]
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

---

### Domain: `machine`

#### `imgman machine init [HOST] [--all] [--flavor NAME]`
- **Purpose:** Explicitly provisions a bootable virtual disk (`.qcow2`) for a host, using the host's production Kickstart layout and the host's flavor image.
- **Under the hood:**
  1. Starts the local container registry (`homelab-image-registry`) on `127.0.0.1:5000` and pushes `localhost/workstation-<flavor>`.
  2. Spawns a headless QEMU instance booting the cached Fedora NetInstall ISO with `images/kickstart/<host>.ks` attached.
  3. Anaconda pulls the image via `ostreecontainer --url=10.0.2.2:5000/workstation-<flavor>:test --no-signature`.
  4. Partitions the drive with production Btrfs subvolumes (`home` at `/var/home`, nested `.cache`), provisions user `sean` (UID 1000), and installs the bootloader.
  5. Powers down cleanly, leaving `~/.cache/homelab-images/<host>/workstation-<flavor>.qcow2`.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Provisions disks for every host in `images/hosts.toml`.
  - `--flavor NAME`: Installs `NAME` instead of the host's flavor.

#### `imgman machine run [HOST] [--all] [--flavor NAME] [--no-gui]`
- **Purpose:** Boots the host's virtual disk with a fresh throwaway copy-on-write overlay and leaves it running for interactive use (no automated assertions, no reboots, no test markers). Always terminates the host's currently running VM, if any, and resets to a clean overlay.
- **Under the hood:**
  1. Checks if a VM for `HOST` is running; if so, immediately terminates the QEMU process (`SIGTERM` / `SIGKILL`) and unlinks its runtime directory.
  2. Discards any previous ephemeral overlay and creates a fresh `overlay.qcow2` backed by the host's disk for the selected flavor.
  3. Allocates a unique VNC display port (e.g., 5900 for `desktop22`, 5901 for `desktop25`) and stores it in `run/vnc_port`.
  4. Spawns QEMU with KVM acceleration, OVMF UEFI firmware, vsock SSH, virtio-vga graphics, a local VNC listener, and a `system.hostname` systemd credential that sets the VM's hostname to `HOST`.
  5. Leaves the VM booted and ready for interactive SSH (`imgman machine ssh`) or graphical inspection (`imgman machine gui`).
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Sequentially resets and boots every host, leaving all of them running in parallel on separate VNC ports.
  - `--flavor NAME`: Boots the host's disk for `NAME` instead of the host's flavor.
  - `--no-gui`: Disables virtual display and VNC; runs QEMU headless (`-display none`).

#### `imgman machine gui [HOST]`
- **Purpose:** Launches `remote-viewer` to view and interact with the graphical desktop of a running VM.
- **Under the hood:**
  1. Checks if the VM for `HOST` is running; if not, informs the user to run `imgman machine run [HOST]` first.
  2. Reads the allocated VNC port from `~/.cache/homelab-images/<host>/run/vnc_port`.
  3. Spawns `remote-viewer vnc://127.0.0.1:<port>`.
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

All `test` commands automatically detect stale dependencies and build what is needed.

#### `imgman test playbook [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** Tests Ansible playbook convergence and idempotence for a host against uncommitted local code.
- **Under the hood:**
  1. Ensures the host's VM is running; if not, boots it with a fresh throwaway overlay (virtual graphics enabled by default; inspect live via `imgman machine gui` unless `--no-gui` is specified).
  2. Uses `rsync --delete` over vsock SSH to sync the host's working tree, including uncommitted and untracked changes, into `/opt/homelab-automation` inside the VM (< 200ms).
     - Excludes `.git` and anything matched by `.gitignore`. Without `.git`, an `ansible-pull.timer` run inside the VM fails to update the checkout and exits instead of replacing the synced tree with the published branch.
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
- **Purpose:** Tests OS-level invariants and transactional `bootc` upgrades and rollbacks for the host's flavor.
- **Under the hood:**
  1. **Smart Dependency Check:** Always runs `podman build` for the host's flavor. If cache hits, finishes in < 0.5s without updating `image.created`. If `(image_created > disk_mtime)` or `(kickstart_mtime > disk_mtime)`, automatically runs `machine init` to refresh the host's disk.
  2. Boots the VM with a fresh throwaway overlay (virtual graphics enabled by default; inspect live via `imgman machine gui` unless `--no-gui` is specified).
  3. Asserts filesystem invariants (`/usr` read-only, `/etc` and `/var` writable, `/srv -> /var/srv`).
  4. Pushes a synthetic layer to the local registry, runs `bootc upgrade` in the VM, reboots, and verifies the upgrade marker.
  5. Runs `bootc rollback` in the VM, reboots, and verifies the marker is removed.
  6. Leaves the VM running unless `--rm` is passed.
- **Options:**
  - `HOST`: Target host (default: this machine's short hostname).
  - `-a, --all`: Sequentially tests all hosts.
  - `--flavor NAME`: Tests `NAME` instead of the host's flavor.
  - `--rm`: Automatically shuts down the VM upon test completion.
  - `--no-gui`: Runs headless with `-display none`.

#### `imgman test all [HOST] [--all] [--flavor NAME] [--rm] [--no-gui]`
- **Purpose:** Full regression testing. Sequentially executes `test image` (with auto-build/auto-init) followed by `test playbook`.
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
  3. Removes synthetic test tags for the host's flavors from local Podman storage (`localhost/workstation-<flavor>:upgrade-test`, `127.0.0.1:5000/...`), leaving production base images untouched.
  4. If `--disks` is passed: deletes the host's `workstation-<flavor>.qcow2` disks if the host is **inactive** (skipping any host whose VM is currently running).
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

---

## 4. Technical Architecture & Implementation Details

### Dependency Detection Logic (`test image`)
When `imgman test image [HOST]` is invoked:
1. Resolves the flavor (`--flavor`, or the host's flavor from `images/hosts.toml`) and executes `podman build -f images/Containerfile.<flavor> -t localhost/workstation-<flavor> images`.
   - On cache hit: completes in < 0.5s without modifying `image.created`.
   - On change: compiles new layer and updates `image.created`.
2. Evaluates staleness:
   ```python
   flavor = args.flavor or hosts[host]["flavor"]
   image = f"localhost/workstation-{flavor}"
   disk_path = cache_dir / host / f"workstation-{flavor}.qcow2"
   kickstart_path = images_dir / "kickstart" / f"{host}.ks"

   image_created = int(run(["podman", "inspect", "-f", "{{.Created.Unix}}", image]))
   disk_mtime = disk_path.stat().st_mtime if disk_path.exists() else 0
   ks_mtime = kickstart_path.stat().st_mtime if kickstart_path.exists() else 0

   if not disk_path.exists() or image_created > disk_mtime or ks_mtime > disk_mtime:
       run_machine_init(host, flavor)
   ```
3. Because QEMU mounts the base `.qcow2` disk strictly read-only and directs all writes to `overlay.qcow2`, `disk_mtime` stays frozen regardless of how long or how often VMs run.

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

### Local Registry & Installer Networking
Anaconda inside QEMU pulls the container image via QEMU's virtual user networking:
- Host loopback: `127.0.0.1:5000` (where `homelab-image-registry` container listens).
- Guest alias: `10.0.2.2:5000` (QEMU automatically forwards `10.0.2.2` to host loopback).
- Anaconda directive in Kickstart:
  ```text
  ostreecontainer --url=10.0.2.2:5000/workstation-kde:test --no-signature
  ```

### Graphical Display & Viewer Architecture
- **Virtual Display by Default:** Desktop images run Wayland compositors (KWin for KDE Plasma, Niri) and display managers (SDDM). Both `machine run` and `test` commands configure virtual graphics hardware (`-device virtio-vga`) and start a local VNC display server (`-vnc 127.0.0.1:<vnc_display>`) by default.
- **Explicit Viewer (`imgman machine gui`):** To avoid unwanted popups and keep the terminal focused during test runs, `remote-viewer` is **not** launched automatically. When graphical inspection is needed, running `imgman machine gui [HOST]` reads `run/vnc_port` and launches `remote-viewer vnc://127.0.0.1:<port>`.
- **Deterministic Port Allocation:** Each host is assigned a dedicated VNC port (`5900 + host_index` or dynamic free port starting at 5900) recorded in `~/.cache/homelab-images/<host>/run/vnc_port` (e.g., `desktop22` on 5900, `desktop25` on 5901). This allows `imgman machine run --all` to run multiple GUI sessions simultaneously without display conflicts.
- **Headless Opt-Out (`--no-gui`):** When `--no-gui` is passed, QEMU is launched with `-display none` and no VNC listener is opened, conserving host resources.

### Filesystem Layout per Host
To allow multiple hosts to build, run, and be inspected simultaneously without file collisions:

```text
~/.cache/homelab-images/
├── iso/
│   └── Fedora-Everything-netinst-x86_64-44.iso   # Cached installer ISO
├── registry/                                     # Shared test registry storage
├── desktop22/
│   ├── workstation-kde-nvidia.qcow2              # Base disk (Kickstart provisioned)
│   ├── workstation-niri.qcow2                    # Only after --flavor niri
│   └── run/                                      # Ephemeral runtime directory
│       ├── qemu.pid                              # QEMU process ID
│       ├── cid                                   # Vsock guest context ID
│       ├── vnc_port                              # VNC display port (e.g. 5900)
│       ├── id_ed25519                            # Ephemeral SSH private key
│       ├── overlay.qcow2                         # Throwaway copy-on-write overlay
│       ├── OVMF_VARS.fd                          # Per-VM UEFI NVRAM copy
│       └── console.log                           # Serial console output
└── desktop25/
    ├── workstation-kde-nvidia.qcow2
    └── run/
        ├── qemu.pid
        ├── cid
        ├── vnc_port
        └── overlay.qcow2
```

The registry is shared because one `homelab-image-registry` container serves every host. Repositories are named per flavor (`workstation-kde`, `workstation-niri`), so hosts never collide on tags.

### Argument Parsing Structure
Implemented using nested `argparse` subparsers:
- Root: `imgman`
  - Subparser: `image` $\rightarrow$ `build`
  - Subparser: `machine` $\rightarrow$ `init`, `run`, `gui`, `ssh`, `rm`
  - Subparser: `test` $\rightarrow$ `playbook`, `image`, `all`
  - Subparser: `system` $\rightarrow$ `prune`

`image build` accepts `[flavor]` as an optional positional argument, defaulting to the default host's flavor. Every other subparser accepts `[host]` as an optional positional argument, defaulting to `hostname --short` when it names a host in `images/hosts.toml`, alongside `-a, --all` flags where appropriate.
- `--flavor NAME`: Available on `machine init`, `machine run`, and all `test` subcommands to use a flavor other than the host's.
- `--no-gui`: Available on `machine run` and all `test` subcommands (`playbook`, `image`, `all`) to disable virtual graphics and run headless (`-display none`).
- `--rm`: Available on all `test` subcommands to automatically remove the VM instance and its ephemeral overlay upon test completion.
- `-d, --disks`: Available on `system prune` to remove base `.qcow2` virtual disks for inactive hosts.
