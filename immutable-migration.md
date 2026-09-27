# Immutable Workstation Migration Plan

This plan outlines the architecture, tooling, and phased migration for converting `desktop22` (and eventually `desktop25`) from a traditional Fedora workstation into an atomic, container-based immutable system powered by **bootc** (Bootable Containers), while retaining **Ansible** for user-space CLI delivery, dotfiles, and homelab configuration.

---

## 1. Executive Summary & Design Principles

### The Goal
* **Stability & Instant Rollbacks:** Replace clunky Btrfs/Snapper rollbacks with transactional, single-command container rollbacks (`bootc rollback` or GRUB deployment selection).
* **Zero Desktop Cruft:** Cleanly switch between desktop environments (KDE Plasma ↔ Niri ↔ GNOME) via image tags (`bootc switch`) without lingering packages, conflicting display managers, or broken portals.
* **RHEL 10 Image Mode Alignment:** Use standard `Containerfile` and `bootc` mechanics directly applicable to enterprise Linux administration and teaching.
* **No Runtime Friction:** No Distrobox/Toolbx requirements for everyday CLI tools, no Homebrew sprawl, and no forced background reboot schedules.

### The Division of Responsibility

```
┌─────────────────────────────────────────────────────────────────┐
│  Layer 1: The Bootable Container (bootc / Containerfile)        │
│  "The Hardware & Desktop Foundation"                            │
│                                                                 │
│  - Linux Kernel & RPM Fusion NVIDIA Drivers (Pre-compiled)      │
│  - Secure Boot MOK Signing (Local & CI)                         │
│  - Display Server & DE (KDE Plasma, Niri, or GNOME)             │
│  - Core Daemons (PipeWire, Systemd, NetworkManager, Podman)     │
│  - Target: Read-only /usr                                       │
└────────────────────────────────┬────────────────────────────────┘
                                 │ boots into
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│  Layer 2: Ansible (Runtime via ansible-pull / h test)           │
│  "The Workstation & CLI Delivery Engine"                        │
│                                                                 │
│  - Static CLI Binaries into ~/bin via get_url                   │
│  - Unified Dotfiles Symlinking (nvim, bat, yazi, etc.)          │
│  - Flatpaks for GUI Apps (Firefox, Zoom, Flatseal)              │
│  - Host /etc Configurations (NextDNS, Tailscale, NFS mounts)    │
│  - Target: Writable /home/sean, /etc, /var                      │
└─────────────────────────────────────────────────────────────────┘
```

### Repository Responsibility Audit & Role Classification

To prevent runtime Ansible failures against bootc's read-only `/usr`, every role invoked in workstation configurations is audited and classified into image construction, runtime configuration, or obsolete tasks.

> [!IMPORTANT]
> **Minimal Base Image Tooling Principle**
> The base container image installs **only** the bare minimum CLI tools strictly necessary to bootstrap and run Ansible (`git`, `python3`, `ansible-core`, and required collections).
> All everyday developer CLI tools (`tmux`, `zsh`, `ripgrep`, `jq`, `fd-find`, `bat`, `yazi`, `nvim`, etc.) are **not** installed in the container image—they are delivered exclusively by the Ansible playbook into `$HOME/bin` with dotfiles symlinked into `$HOME`.

> [!NOTE]
> **Branch-Based Migration Strategy**
> All playbook and role refactoring occurs directly in this dedicated `immutable` Git branch. Workstation playbooks (`desktop22.yml`, `desktop25.yml`) and their underlying roles are modified directly in this branch to run natively on the bootc immutable architecture. This branch will only be merged to `main` once the immutable deployment is fully verified, operational, and tested.

| Role | Image Construction (Containerfile / Build Scripts) | Runtime Configuration (Ansible on Booted Host) | Obsolete on Bootc |
| :--- | :--- | :--- | :--- |
| **`ansible_pull`** | Pre-bake `python3`, `ansible-core` (providing `/usr/bin/ansible-pull`), `git`, pinned collections from `collections/requirements.yml`, and `/usr/bin/h`. | Template `/etc/systemd/system/ansible-pull.{service,timer}` (`ansible_pull_path: /usr/bin/ansible-pull`), logrotate config in `/etc`. | Drop pip package upgrades in `/usr`, drop `After=dnf-makecache.service`, drop Snapper rootfs pre/post hooks. |
| **`core`** | System packages, base utilities, ShellCheck. | `/etc` limits, sysctl tweaks, user group memberships (`wheel`, `devusers`). | — |
| **`btrfs`** | `btrbk` package in image. | `/etc/btrbk/btrbk.conf`, systemd backup timers. | — |
| **`rpm_fusion`** | Configured in `01-repositories.sh`. | — | **Obsolete at runtime** (remove role from playbook). |
| **`dnf`** | — | — | **Obsolete at runtime** (remove role from playbook; replaced by `bootc upgrade`). |
| **`wifi`** | NetworkManager, iwd, wireless firmware in image. | Wi-Fi connections in `/etc/NetworkManager/system-connections/`. | — |
| **`cli`** | — *(Only `git`/`python3`/`ansible` in image)* | Downloads all user CLI tools into `$HOME/bin`; symlinks dotfiles into `$HOME`. | Drop runtime DNF package tasks. |
| **`ai`** | Node.js runtime and basic dependencies in image. | User-space CLI deployment of `claude`, `agy` (Antigravity), `codex`, and `opencode` into `~/.local/bin` and `~/bin`; symlink dotfiles into `~/.config/antigravity` and `~/.codex`. | Drop system-wide `npm -g` installs (which fail on read-only `/usr`). |
| **`ai_health_monitor`** | Pre-create `ai-health-monitor` system user/group. | Deploy `/etc/sudoers.d/ai-health-monitor`, `/etc/logrotate.d/ai-health-monitor`, helper scripts to `/usr/local/bin` (persisted in `/var/usrlocal/bin`), and configure systemd service/timer. | Drop any runtime package installations. |
| **`devops`** | Pre-bake `vagrant`, `vagrant-libvirt`, `libvirt-devel` in image (if host virtualization used) or delegate to toolbox container. | Download pinned `terraform` and `awscli` into user-space `~/bin/` with checksum verification and clean staging. | Drop runtime HashiCorp YUM repo config and package tasks. |
| **`docker` / `podman`** | `podman`, `podman-docker` (or `docker-ce`) installed in image. | Enable `docker.service` or rootless podman socket; user in group `docker`. | Drop runtime package install. |
| **`libvirt`** | `@virtualization`, `qemu-kvm`, `libvirt`, `virtio-win` in image. | User in group `libvirt`; enable `libvirtd.service`; `/var/lib/libvirt` permissions. | Drop runtime package install. |
| **`fonts`** | System font packages in image. | User font cache rebuild (`fc-cache -f`) or user-local fonts in `~/.local/share/fonts`. | Drop runtime DNF font installs & `/usr/local/share/fonts` unarchive. |
| **`onepassword`** | `1password-cli` and GUI RPMs in image. | Polkit rules in `/etc/polkit-1/`, browser integration in `/home/sean/.config`. | Drop runtime repo/package tasks. |
| **`tailscale`** | `tailscale` package in image. | Enable `tailscaled.service`; sysctl IP forwarding in `/etc/sysctl.d/`; route advertisement. | Drop runtime package install. |
| **`nextdns`** | NextDNS package or `systemd-resolved` configs. | `/etc/systemd/resolved.conf.d/nextdns.conf` and service start. | Drop runtime package install. |
| **`network_storage`** | `nfs-utils` package in image; pre-create mount points. | Automount entries in `/etc/fstab`; user in group `networkshare`. | Drop runtime package install and `mkdir` on rootfs. |
| **`gaming`** | `steam`, `wine`, `kernel-modules-extra`, controller rules in image. | User autostart `.desktop`, Steam configurations in `/home/sean/.local/share/Steam`. | Drop runtime package install. |
| **`gui`** | Base graphical plumbing & Wayland utilities. | Flatpak apps (Firefox, Chrome, VS Code, Slack, Zoom) into `/var/lib/flatpak`. | Drop runtime RPM package installs. |
| **`wm/niri`** | Core compositor packages (`niri`, `uwsm`, `waybar`, `fuzzel`, `swaylock`, `swayidle`, `swaybg`, `pipewire`, `wireplumber`, `polkit-gnome`, `gnome-keyring`, `xwayland-satellite`, `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk`), pre-compilation and installation of `libniri_window_buttons.so` into `/usr/lib/waybar/`, default portal config in `/etc/xdg/xdg-desktop-portal/niri-portals.conf`. | Symlink dotfiles (`~/.config/niri`), copy wallpaper to `~/.local/share/backgrounds`, machine-specific symlink, install `gradia` flatpak, `.bash_profile` uwsm autostart hook. | Drop runtime RPM package install tasks, drop runtime `*-devel` package installs, drop runtime compilation and `/usr` installation of `niri_window_buttons`. |
| **`nodejs` / `python`** | System python/node runtimes in image. | User virtual environments or pnpm/cargo paths in `~/bin` or `~/.local`. | Drop system-wide pip/npm installs. |

### The Shared Filesystem Contract

All desktop image variants (`kinoite`, `silverblue`, `fedora-bootc`) adhere to an explicit filesystem contract:

1. **/usr (Read-Only)**: Contains all OS binaries, kernel modules, compositors, display managers, and system packages.
2. **/etc (Read-Write with 3-Way Merge)**: Host configuration, systemd unit overrides, NetworkManager profiles, `/etc/fstab`, and sysctl rules. Bootc preserves changes across OS updates via 3-way merge.
3. **/var (Persistent & Mutable)**: All runtime state (`/var/home`, `/var/opt`, `/var/srv`, `/var/lib/containers`, `/var/lib/flatpak`).
4. **Repository Location (`/var/opt/homelab-automation`)**: Rather than modifying or symlinking `/opt` (which is read-only in bootc), the repository's `playbook_path` variable is configured to `/var/opt/homelab-automation`. Because `/var` is natively persistent and mutable across OS updates, `ansible-pull` clones directly into `/var/opt/homelab-automation` without requiring any container image filesystem overrides.
5. **Top-Level Mount Points & Local Source**: The root filesystem `/` is read-only at runtime. External mount directories (`/source`, `/games`, `/srv/tier1`, `/srv/tier2`) are pre-created during image construction as empty mount points. For local development repositories, `/src` is provisioned during image build as a symlink pointing to `/var/src` (`RUN mkdir -p /var/src && ln -s var/src /src`). Because `/var` is persistent and mutable, Ansible can manage `/var/src` (ownership `sean:sourceshare`, mode `02775`) without triggering read-only filesystem errors.
6. **System Binaries (`/usr/bin/h`)**: The homelab management CLI `h` is pre-baked into `/usr/bin/h` during container image build so it is universally available without runtime templating into immutable paths. It is maintained as a static, parameterized script in `images/bin/h` with default environment fallbacks (`AUTOMATION_DIR="/var/opt/homelab-automation"`, `AUTOMATION_SERVICE_NAME="ansible-pull"`) and copied into `/usr/bin/h` with bash completion in `/etc/bash_completion.d/h`.
7. **/usr/local (Symlink to `/var/usrlocal`)**: In Fedora bootc and ostree, `/usr/local` is a system symlink pointing to `../var/usrlocal`. Software and scripts deployed to `/usr/local/bin` (such as NextDNS helper scripts and `ai-health-monitor` utilities) reside on persistent, mutable storage across OS updates. However, foundational host tooling required before user state is mounted (such as `/usr/bin/h`) is baked into `/usr/bin` in the image.

---

## 2. Container Build Strategy (Modular Scripts, Pre-compiled NVIDIA RPMs & MOK Signing)

### A. Modular Scripts Architecture (`scripts/*.sh`)

Instead of inline multiline `RUN` commands with fragile `&& \` line continuations, all build logic is encapsulated in modular, testable shell scripts under `images/scripts/`.

#### Script Conventions & ShellCheck
Per repository conventions:
1. Every script starts with `set -euo pipefail` to ensure any command failure or unbound variable halts the build immediately.
2. Indentation is strictly **4 spaces**.
3. All scripts are linted with **ShellCheck** before container builds:
   ```sh
   shellcheck images/scripts/*.sh
   ```

#### How Podman's `COPY` Content Hashing Governs Cache Behavior
When Podman evaluates `COPY images/scripts/<name>.sh /tmp/`:
* Podman computes a cryptographic SHA256 checksum of the file's contents and metadata on disk.
* **Local Developer Iteration:** On local workstations, if the script and parent layers have not changed, Podman matches the cached layer hash (`--> Using cache`) and skips re-running the script. Editing a script invalidates its layer and all subsequent layers, allowing fast iterative debugging without touching the `Containerfile`.
* **Parent Image & Dependency Invalidation:** If the base image is refreshed (`--pull=newer`) or an upstream stage (such as `akmods_nvidia`) receives updated packages, the parent layer hash changes, triggering a rebuild of downstream layers regardless of script edits.
* **CI Runner Environment:** GitHub Actions runners start from fresh virtual machines without persistent local storage; CI builds always pull fresh base images and compile cleanly, ensuring published images reflect current upstream security updates.

---

### B. NVIDIA Integration: Maintained Pre-Compiled Modules (`ublue-os/akmods`)

Compiling the proprietary NVIDIA driver (`akmod-nvidia`) from source inside a container takes 10–15 minutes, requires fragile `kernel-devel` header matching against live mirrors, and demands maintaining private signing scripts and CI secret keys.

Instead, the build pipeline leverages **maintained pre-compiled, pre-signed kernel modules from Universal Blue (`ghcr.io/ublue-os/akmods-nvidia-open`)**:
* **Automated Upstream Build Farm**: Universal Blue builds and tests `akmod-nvidia-open` against Fedora kernel releases directly from Fedora Koji build servers, publishing them as OCI images. Open kernel modules are the upstream standard for Turing, Ampere, and Ada Lovelace GPUs (including the RTX 4070 SUPER on `desktop22`).
* **Zero Layer Bloat via Ephemeral Bind Mounts**: Using BuildKit/Podman's `--mount=type=bind`, the RPM packages are mounted ephemerally during the build step. Zero RPM payload bytes are copied into intermediate image layers.
* **Pre-Signed Kernel Modules**: Modules are pre-signed with Universal Blue's public MOK certificate, requiring a single one-time enrollment on the host motherboard. Zero private signing keys need to be generated or stored in GitHub Actions secrets.

```dockerfile
# images/Containerfile.kde (or Containerfile.niri)
ARG FEDORA_MAJOR_VERSION=44
ARG IMAGE_REGISTRY=ghcr.io/ublue-os

# Stage 0: Maintained pre-compiled NVIDIA open-kernel modules (matching Fedora release)
FROM ${IMAGE_REGISTRY}/akmods-nvidia-open:main-${FEDORA_MAJOR_VERSION} AS akmods_nvidia

# Stage 1: Upstream Fedora Atomic Base (pinned to major release)
FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_MAJOR_VERSION}

ARG NVIDIA=false

# -------------------------------------------------------------------------
# Layer 1: Repositories (RPM Fusion)
# -------------------------------------------------------------------------
COPY images/scripts/01-repositories.sh /tmp/
RUN /tmp/01-repositories.sh && rm /tmp/01-repositories.sh

# -------------------------------------------------------------------------
# Layer 2: NVIDIA Kernel Driver & Userspace (Zero Layer Bloat via Bind Mount)
# -------------------------------------------------------------------------
RUN --mount=type=bind,from=akmods_nvidia,src=/rpms,dst=/tmp/akmods-nv-rpms \
    if [ "$NVIDIA" = "true" ]; then \
        AKMODNV_PATH=/tmp/akmods-nv-rpms /tmp/akmods-nv-rpms/ublue-os/nvidia-install.sh; \
    fi

# -------------------------------------------------------------------------
# Layer 3: Base Virtualization, Tooling & Plumbing (Shared across all DEs)
# -------------------------------------------------------------------------
COPY collections/requirements.yml /tmp/collections-requirements.yml
COPY images/bin/h /usr/bin/h
RUN chmod 0755 /usr/bin/h
COPY images/files/h_completion.bash /etc/bash_completion.d/h
COPY images/scripts/03-virtualization.sh /tmp/
RUN /tmp/03-virtualization.sh && rm /tmp/03-virtualization.sh

# -------------------------------------------------------------------------
# Layer 4: Desktop Environment Specific Layer (KDE, Niri, or GNOME)
# -------------------------------------------------------------------------
COPY images/scripts/de-kde.sh /tmp/
RUN /tmp/de-kde.sh && rm /tmp/de-kde.sh
```

---

### C. The Build Scripts

#### 1. `images/scripts/01-repositories.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-"$(rpm -E %fedora)".noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-"$(rpm -E %fedora)".noarch.rpm

dnf clean all
```

#### 2. Maintained NVIDIA Installer (`ublue-os/nvidia-install.sh`)
Rather than maintaining a custom script that risks version drift, the build directly executes `/tmp/akmods-nv-rpms/ublue-os/nvidia-install.sh` from the upstream `akmods_nvidia` bind mount. This upstream installer:
* Sources kernel variable definitions matching the exact image kernel release.
* Installs `ublue-os-nvidia-addons` and matching `kmod-nvidia` + `nvidia-driver` userspace packages.
* Enforces strict ABI verification (`KMOD_VERSION == DRIVER_VERSION`), failing the build if mismatched.
* Configures early module loading in `/usr/lib/dracut/dracut.conf.d/99-nvidia.conf`.
* Enables `nvidia-persistenced.service` and `nvidia-cdi-refresh.service`.

#### 3. `images/scripts/03-virtualization.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# 1. Base virtualization, plumbing, and Ansible runtime dependencies
# (Only the minimal CLI tools required to run Ansible are installed here;
# developer tools like tmux, zsh, ripgrep, jq are installed into ~/bin by Ansible).
dnf install -y \
    podman \
    libvirt \
    tailscale \
    nfs-utils \
    curl \
    git \
    rsync \
    python3 \
    python3-pip \
    ansible-core

dnf clean all

# 2. Pre-create external mount directories on the read-only rootfs
mkdir -p /source /games /srv/tier1 /srv/tier2

# 3. Provision persistent /var backing directories and symlinks
mkdir -p /var/opt /var/src
ln -s var/src /src

# 4. Install pinned Ansible collections system-wide using repository requirements
if [ -f /tmp/collections-requirements.yml ]; then
    ansible-galaxy collection install \
        -r /tmp/collections-requirements.yml \
        -p /usr/share/ansible/collections
    rm -f /tmp/collections-requirements.yml
fi

# 5. Enable base system services
systemctl enable podman.socket libvirtd tailscaled
```

---

### D. Secure Boot MOK Enrollment & GitHub Actions CI

Because modules are pre-signed with Universal Blue's public MOK certificate, no private keys need to be generated locally or injected into CI.

#### 1. Enroll the Universal Blue Public MOK Key (One-Time Setup on NVIDIA Hosts)
Run on `desktop22`:
```sh
# 1. Download Universal Blue's active public MOK certificate
curl -Lo /tmp/ublue-os.der https://raw.githubusercontent.com/ublue-os/akmods/main/certs/public_key.der

# 2. Inspect certificate fingerprint to verify provenance:
openssl x509 -inform der -in /tmp/ublue-os.der -noout -fingerprint -sha256
# Expected Fingerprint: 4E:5C:68:47:4C:B1:33:FD:89:84:D9:59:97:62:CE:CE:91:00:C3:E6:CD:8A:97:09:AE:AA:BD:85:DD:9E:70:D1

# 3. Import key into system MOK list
sudo mokutil --import /tmp/ublue-os.der

# 4. Reboot into the blue MOK Management screen, select "Enroll MOK", and confirm with the temporary password.
```

#### 2. Local Builds (Non-NVIDIA vs. NVIDIA)

* **For Non-NVIDIA machines (`desktop25` today, `x1carbon2018` Intel laptop):**
  ```sh
  sudo podman build -t localhost/workstation-kde:latest -f images/Containerfile.kde .
  ```
  *(Standard container build installing shared virtualization and desktop plumbing).*

* **For NVIDIA machines (`desktop22` with RTX 4070 SUPER, `desktop25` after upgrade):**
  Passing `NVIDIA=true` binds the upstream pre-compiled module payload without C compilation:
  ```sh
  sudo podman build \
      --pull=newer \
      --build-arg NVIDIA=true \
      -t localhost/workstation-kde-nvidia:latest \
      -f images/Containerfile.kde .
  ```
  *(Eliminates the 10–15 minute kernel-devel compile cycle, installing pre-built signed RPMs directly).*

#### 3. GitHub Actions CI Builds (Public Repo Workflow)
Because no private keys are required, the GitHub Actions workflow runs cleanly without secret mounts:

```yaml
# .github/workflows/build-workstation-images.yml
name: Build Workstation Images

on:
  push:
    branches:
      - main
    paths:
      - 'images/**'
  schedule:
    - cron: '0 6 * * 1' # Weekly automated build to pull upstream security updates
  workflow_dispatch:      # Manual trigger

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    strategy:
      matrix:
        flavor: [kde, niri]
        nvidia: ["false", "true"]
        include:
          - nvidia: "false"
            suffix: ""
          - nvidia: "true"
            suffix: "-nvidia"

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Lint build scripts with ShellCheck
        run: shellcheck images/scripts/*.sh

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push image
        run: |
          IMAGE_NAME="ghcr.io/${{ github.repository }}/workstation-${{ matrix.flavor }}${{ matrix.suffix }}"
          BUILD_DATE="$(date -u +%Y.%m.%d)"
          COMMIT_SHA="$(git rev-parse --short HEAD)"
          RELEASE_TAG="${BUILD_DATE}-${COMMIT_SHA}"

          podman build \
            --pull=newer \
            --build-arg NVIDIA=${{ matrix.nvidia }} \
            -t "${IMAGE_NAME}:latest" \
            -t "${IMAGE_NAME}:${RELEASE_TAG}" \
            -f images/Containerfile.${{ matrix.flavor }} .

          podman push "${IMAGE_NAME}:latest"
          podman push "${IMAGE_NAME}:${RELEASE_TAG}"

          # Capture and log the immutable OCI image digest
          DIGEST="$(podman inspect --format '{{.Digest}}' "${IMAGE_NAME}:${RELEASE_TAG}")"
          echo "Pushed ${IMAGE_NAME}:${RELEASE_TAG} with digest: ${DIGEST}"
```

#### 4. Release Tagging, Digest Pinning & Promotion Strategy

Every build produces a non-overwriting release tag and an immutable cryptographic digest, generated identically in local environments and CI:

* **`${BUILD_DATE}-${COMMIT_SHA}`** (e.g. `workstation-kde:2026.09.26-c91da61`): The primary release tag.
  - Combines the build date and git commit SHA using standard Git and date tools.
  - Prevents scheduled weekly rebuilds from overwriting prior images (date advances even if commit SHA is unchanged).
  - Prevents multiple same-day commits from overwriting prior images (commit SHA differs).
  - Works identically whether generated locally on the host or inside GitHub Actions.
* **`IMAGE_NAME@sha256:...` (Immutable OCI Digest)**: The cryptographic anchor. Capturing and logging the digest after every push guarantees a verifiable, immutable reference that can never be modified or overwritten.
* **`workstation-kde:latest` (Floating Canary Tag)**: Tracks the most recent successful build; used for canary testing on `desktop22`.

#### Fleet Promotion Workflow
To prevent secondary fleet hosts (`desktop25`, `x1carbon2018`) from automatically pulling an untested compose directly from scheduled CI:
1. **Canary Verification**: `desktop22` consumes `:latest` or the freshly built `${BUILD_DATE}-${COMMIT_SHA}` tag.
2. **Promotion to Fleet**: Once verified on the canary, secondary machines are updated to the verified release tag (e.g. `sudo bootc switch ghcr.io/.../workstation-kde:2026.09.26-c91da61`), ensuring fleet machines run known-good, verified builds.
3. **Retention Policy**: GHCR package settings retain the last 30–60 days of tagged releases while pruning older untagged layers.

---

## 3. Extensible Multi-Image Architecture (Adding DEs & Hosts Over Time)

By combining separate Containerfiles for each desktop base with the `NVIDIA` build argument, you can maintain clean Intel/AMD and NVIDIA variants across any desktop environment with zero script duplication:

| Image Tag | Hardware Target | Description |
| :--- | :--- | :--- |
| **`workstation-kde`** | `x1carbon2018`, `desktop25` (today) | Clean KDE Plasma 6 on Intel/AMD Mesa drivers. No NVIDIA bloat. |
| **`workstation-kde-nvidia`** | `desktop22` (today), `desktop25` (after GPU) | KDE Plasma 6 with pre-compiled & signed NVIDIA drivers. |
| **`workstation-niri`** | `x1carbon2018`, `desktop25` (today) | Clean Niri Wayland compositor on Intel/AMD Mesa drivers. |
| **`workstation-niri-nvidia`** | `desktop22` (today), `desktop25` (after GPU) | Niri Wayland compositor with pre-compiled & signed NVIDIA drivers. |
| **`workstation-gnome`** | Any host | Clean GNOME Shell on Intel/AMD Mesa drivers. |
| **`workstation-gnome-nvidia`** | Any host with NVIDIA | GNOME Shell with pre-compiled & signed NVIDIA drivers. |

> [!NOTE]
> **Independent Layer Caches Per Base Image**
> Because each desktop environment starts from a distinct parent image (`kinoite:latest`, `silverblue:latest`, or `fedora-bootc:latest`), Podman cannot share cached layers across different desktop bases (the parent filesystem hash forms the base of the cache key for all subsequent instructions). Each base image maintains its own independent layer cache in local storage. Rebuilding `workstation-kde` reuses cached KDE layers, while rebuilding `workstation-niri` reuses cached Niri layers. Because all flavors share the exact same modular scripts (`01-repositories.sh`, `03-virtualization.sh`), improvements to the installation scripts benefit every image without duplicate code maintenance.

### Desktop Base Strategy & Base Image Provenance

Rather than trying to bolt desktop environments onto a generic minimal image (which leads to service crashes and missing portal configs), each desktop flavor builds from its respective Fedora base:

* **Official Minimal Base (`Containerfile.niri`):** Starts `FROM quay.io/fedora/fedora-bootc:${FEDORA_MAJOR_VERSION}` (Fedora Minimal). This is the official upstream release-supported Fedora bootc base. It builds a pristine Niri compositor stack from scratch.
* **KDE Flavor (`Containerfile.kde`):** Starts `FROM quay.io/fedora-ostree-desktops/kinoite:${FEDORA_MAJOR_VERSION}`. KDE Plasma 6, SDDM, Wayland, Dolphin, and Konsole are pre-configured. `de-kde.sh` only installs optional personal extras.
* **GNOME Flavor (`Containerfile.gnome`):** Starts `FROM quay.io/fedora-ostree-desktops/silverblue:${FEDORA_MAJOR_VERSION}`. GNOME Shell and GDM are pre-configured by the desktop team.

> [!NOTE]
> **Base Image Publishing Status & Release Pinning**
> * **Publishing Channel**: While `quay.io/fedora/fedora-bootc` is the official release-engineered base, `quay.io/fedora-ostree-desktops/` is currently maintained as a community/testing build channel (via GitLab CI) while Fedora transitions desktop spins to native OCI publishing. Both provide solid container-native bootc targets, but tracking explicit tags is critical.
> * **Major Version Pinning**: Base images pin an explicit major Fedora release matching the host environment via `ARG FEDORA_MAJOR_VERSION=44` rather than floating `:latest`. Floating `:latest` tags leave Fedora major-version transitions (e.g. F44 → F45) uncontrolled, risking sudden ABI or driver mismatches during scheduled weekly rebuilds. Major version upgrades become deliberate, tested pull requests.

All three share the exact same `01-repositories.sh` and `03-virtualization.sh` scripts, while NVIDIA variants bind-mount the upstream `akmods-nvidia-open` payload ephemerally during build.

### Directory Layout

```
images/
├── Containerfile.kde          # FROM kinoite + 01, nvidia bind-mount, 03, de-kde.sh
├── Containerfile.niri         # FROM fedora-bootc + 01, nvidia bind-mount, 03, de-niri.sh
├── Containerfile.gnome        # FROM silverblue + 01, nvidia bind-mount, 03
└── scripts/
    ├── 01-repositories.sh     # Shared RPM Fusion setup
    ├── 03-virtualization.sh   # Shared virtualization & core plumbing
    ├── de-kde.sh              # Optional KDE extras (e.g. pavucontrol)
    └── de-niri.sh             # Niri + Waybar + portals (on minimal base)
```

### Desktop Scripts

#### `images/scripts/de-kde.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# Kinoite already includes the full KDE Plasma 6 desktop, SDDM, Dolphin, and Konsole.
# Use this script strictly for extra utilities you want in the KDE image:
dnf install -y \
    pavucontrol

dnf clean all
```

#### `images/scripts/de-niri.sh`
```bash
#!/usr/bin/env bash
set -euo pipefail

# Built on top of fedora-bootc (minimal base) with zero full desktop environments (KDE/GNOME):
# Note: niri and uwsm are available directly in official Fedora repositories (no COPR needed).
dnf install -y \
    niri \
    uwsm \
    waybar \
    fuzzel \
    swaylock \
    swayidle \
    swaybg \
    xorg-x11-server-Xwayland \
    xwayland-satellite \
    polkit-gnome \
    gnome-keyring \
    pipewire \
    wireplumber \
    pavucontrol \
    pulseaudio-utils \
    playerctl \
    brightnessctl \
    nautilus \
    gnome-calculator \
    xdg-desktop-portal \
    xdg-desktop-portal-wlr \
    xdg-desktop-portal-gtk

# Zoom 6.7.5 screen sharing compatibility:
# Do NOT install xdg-desktop-portal-gnome; it causes pipewire format negotiation bugs in Zoom
# (Zoom's PipeWire consumer node registers zero accepted formats due to cross-thread pw_stream calls).
# Configure wlr as primary portal for screen capture, and gtk as fallback for file chooser and settings:
mkdir -p /etc/xdg/xdg-desktop-portal
cat <<'EOF' > /etc/xdg/xdg-desktop-portal/niri-portals.conf
[preferred]
default=wlr;gtk;
EOF

# Compile and install niri_window_buttons Waybar CFFI plugin into immutable /usr/lib/waybar:
dnf install -y cargo glib2-devel gtk3-devel pulseaudio-libs-devel git
mkdir -p /tmp/niri_window_buttons_build
git clone https://github.com/adelmonte/niri_window_buttons.git /tmp/niri_window_buttons_build
(
    cd /tmp/niri_window_buttons_build
    cargo build --release --locked
    mkdir -p /usr/lib/waybar
    cp target/release/libniri_window_buttons.so /usr/lib/waybar/libniri_window_buttons.so
    chmod 0755 /usr/lib/waybar/libniri_window_buttons.so
)
rm -rf /tmp/niri_window_buttons_build
dnf remove -y cargo glib2-devel gtk3-devel pulseaudio-libs-devel

dnf clean all
```

### Switching Environments at Will
To test or switch your entire machine's desktop environment, specify the appropriate image variant for your hardware:

```sh
# For Intel / AMD Mesa workstations (desktop25, x1carbon2018):
# Switch to Niri (clean minimal compositor):
sudo bootc switch --apply --transport containers-storage localhost/workstation-niri:latest

# Switch back to KDE:
sudo bootc switch --apply --transport containers-storage localhost/workstation-kde:latest

# For NVIDIA workstations (desktop22 with RTX 4070 SUPER):
# Switch to Niri with NVIDIA kmods:
sudo bootc switch --apply --transport containers-storage localhost/workstation-niri-nvidia:latest

# Switch back to KDE with NVIDIA kmods:
sudo bootc switch --apply --transport containers-storage localhost/workstation-kde-nvidia:latest

# Alternatively, use the 'h' helper to automatically detect your GPU:
h os-switch niri
```

> [!IMPORTANT]
> **`--transport containers-storage` & Root vs. Rootless Image Stores**
> * **Registry vs. Local Storage**: `bootc` defaults to resolving image references against remote container registries via standard registry transport (HTTP/HTTPS). When switching to an image built locally in container storage (e.g. `localhost/workstation-...`), you **must** supply `--transport containers-storage` to instruct `bootc` to query the host's local container engine storage (`/var/lib/containers/storage`) rather than attempting network registry resolution.
> * **Storage Boundary**: `bootc switch` runs with root privileges and reads exclusively from root's image store (`/var/lib/containers/storage`). Images built in rootless storage (`~/.local/share/containers/storage`) by unprivileged users or test frameworks are invisible to `bootc`. Host deployment images must be built into root storage via `sudo podman build` or `h os-build`, or transferred from rootless storage via `podman save <tag> | sudo podman load`.
Because `/usr` is cleanly swapped in the immutable OS tree, system-level desktop packages, default services, and system portal definitions are cleanly replaced without orphan system packages.

---

## 4. Ansible CLI Delivery & Dotfile Management

CLI tools are decoupled from the OS image. To optimize network usage, ensure deterministic execution, and support instantaneous offline rollback, tools are installed into version-isolated directories (`~/.local/share/{{ item.name }}/{{ item.version }}/`) and activated by symlinking the active binary to `~/bin/{{ item.name }}`. Before downloading any tool, Ansible checks whether the requested version already exists on disk. If the version is present, Ansible skips the download and hash comparison entirely, simply updating the `~/bin` symlink. If a new version is declared in Git, Ansible downloads the archive, validates its cryptographic checksum, extracts it via private staging into its versioned directory, and updates the symlink.

### A. Unified Data Declaration (`roles/apps/cli/vars/main.yml`)

Every tool specifies its download URL, type (`binary`, `tar`, `zip`, or `app_tree`), version, and SHA256 checksum:

```yaml
---
cli_tools:
  # Standalone executable binary
  - name: agg
    version: 1.5.0
    type: binary
    url: https://github.com/asciinema/agg/releases/download/v1.5.0/agg-x86_64-unknown-linux-gnu
    checksum: sha256:59673469d625df6f55c72159c84ffbb7af1348ac379d0e79db43f4b80fb986a3

  # Single-binary Tarballs (GNU tar supports --strip-components)
  - name: bat
    version: 0.24.0
    type: tar
    url: https://github.com/sharkdp/bat/releases/download/v0.24.0/bat-v0.24.0-x86_64-unknown-linux-musl.tar.gz
    checksum: sha256:d39a21e3da57fe6a3e07184b3c1dc245f8dba379af569d3668b6dcdfe75e3052
    binary_path: bat-v0.24.0-x86_64-unknown-linux-musl/bat

  - name: rg
    version: 15.2.0
    type: tar
    url: https://github.com/BurntSushi/ripgrep/releases/download/15.2.0/ripgrep-15.2.0-x86_64-unknown-linux-musl.tar.gz
    checksum: sha256:33e15bcf1624b25cdd2a55813a47a2f95dbe126268203e76aa6a585d1e7b149c
    binary_path: ripgrep-15.2.0-x86_64-unknown-linux-musl/rg

  # Zip Archive (extracted cleanly into private staging directory)
  - name: yazi
    version: 0.4.2
    type: zip
    url: https://github.com/sxyazi/yazi/releases/download/v0.4.2/yazi-x86_64-unknown-linux-musl.zip
    checksum: sha256:378bd0af3528479cbe79cb700b50aaeedeb6dcad1f0ad04083df0212f22d1e20
    binary_path: yazi-x86_64-unknown-linux-musl/yazi

  # Complete Application Bundle (preserves runtime/, lib/, and syntax/ trees intact)
  - name: nvim
    version: 0.10.4
    type: app_tree
    url: https://github.com/neovim/neovim/releases/download/v0.10.4/nvim-linux-x86_64.tar.gz
    checksum: sha256:95aaa8e89473f5421114f2787c13ae0ec6e11ebbd1a13a1bd6fcf63420f8073f
```

### B. Tasks Implementation (`roles/apps/cli/tasks/install_tools.yml`)

```yaml
---
# 0. Setup private user directories
- name: user-local bin and tools directories exist
  ansible.builtin.file:
    path: "{{ item }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0755
  loop:
    - /home/{{ user }}/bin
    - /home/{{ user }}/.local/share
    - /home/{{ user }}/.cache/homelab-automation/downloads

# 1. Check whether each tool's target version already exists on disk
- name: tool version existence is checked on disk
  ansible.builtin.stat:
    path: >-
      {{ '/home/' ~ user ~ '/.local/share/' ~ item.name ~ '/' ~ item.version ~ '/bin/' ~ item.name
         if item.type == 'app_tree'
         else '/home/' ~ user ~ '/.local/share/' ~ item.name ~ '/' ~ item.version ~ '/' ~ item.name }}
  register: installed_tool_versions
  loop: "{{ cli_tools }}"
  loop_control:
    label: "{{ item.name }} ({{ item.version }})"

# 2. Download missing tool archives and binaries (skipped entirely if version already on disk)
- name: missing CLI tools are downloaded with checksum validation
  when: not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  ansible.builtin.get_url:
    url: "{{ item.url }}"
    dest: "/home/{{ user }}/.cache/homelab-automation/downloads/{{ item.name }}-{{ item.version }}-{{ item.url | basename }}"
    checksum: "{{ item.checksum }}"
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0644
  loop: "{{ cli_tools }}"
  loop_control:
    label: "{{ item.name }} ({{ item.version }})"

# 3. Create target version directories for missing tools
- name: target version directory exists for missing tools
  when: not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  ansible.builtin.file:
    path: "/home/{{ user }}/.local/share/{{ item.name }}/{{ item.version }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0755
  loop: "{{ cli_tools }}"
  loop_control:
    label: "{{ item.name }} ({{ item.version }})"

# 4. Install Standalone Binaries (agg)
- name: standalone binary is copied to version directory
  when:
    - item.type == 'binary'
    - not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  ansible.builtin.copy:
    src: "/home/{{ user }}/.cache/homelab-automation/downloads/{{ item.name }}-{{ item.version }}-{{ item.url | basename }}"
    dest: "/home/{{ user }}/.local/share/{{ item.name }}/{{ item.version }}/{{ item.name }}"
    remote_src: true
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0755
  loop: "{{ cli_tools }}"
  loop_control:
    label: "{{ item.name }} ({{ item.version }})"

# 5. Extract Tar Archives (bat, rg)
- name: tar CLI binaries are extracted and installed
  when:
    - item.type == 'tar'
    - not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  block:
    - name: clean tar staging directory exists
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        state: directory
        owner: "{{ user }}"
        group: "{{ user }}"
        mode: 0700
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'tar') | list }}"

    - name: tar binary is extracted to private staging
      ansible.builtin.unarchive:
        src: "/home/{{ user }}/.cache/homelab-automation/downloads/{{ item.name }}-{{ item.version }}-{{ item.url | basename }}"
        dest: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        remote_src: true
        include:
          - "{{ item.binary_path }}"
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'tar') | list }}"

    - name: tar binary is copied to version directory
      ansible.builtin.copy:
        src: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}/{{ item.binary_path }}"
        dest: "/home/{{ user }}/.local/share/{{ item.name }}/{{ item.version }}/{{ item.name }}"
        remote_src: true
        owner: "{{ user }}"
        group: "{{ user }}"
        mode: 0755
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'tar') | list }}"

    - name: tar staging directory is cleaned up
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        state: absent
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'tar') | list }}"

# 6. Extract Zip Archives (yazi)
- name: zip CLI archives are extracted and installed
  when:
    - item.type == 'zip'
    - not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  block:
    - name: clean zip staging directory exists
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        state: directory
        owner: "{{ user }}"
        group: "{{ user }}"
        mode: 0700
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'zip') | list }}"

    - name: zip archive is extracted to private staging
      ansible.builtin.unarchive:
        src: "/home/{{ user }}/.cache/homelab-automation/downloads/{{ item.name }}-{{ item.version }}-{{ item.url | basename }}"
        dest: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        remote_src: true
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'zip') | list }}"

    - name: zip binary is copied to version directory
      ansible.builtin.copy:
        src: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}/{{ item.binary_path }}"
        dest: "/home/{{ user }}/.local/share/{{ item.name }}/{{ item.version }}/{{ item.name }}"
        remote_src: true
        owner: "{{ user }}"
        group: "{{ user }}"
        mode: 0755
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'zip') | list }}"

    - name: zip staging directory is cleaned up
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}"
        state: absent
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'zip') | list }}"

# 7. Complete Application Bundles (Neovim with full runtime tree)
- name: application bundles are extracted into version directory
  when:
    - item.type == 'app_tree'
    - not (installed_tool_versions.results | selectattr('item.name', 'equalto', item.name) | map(attribute='stat.exists') | first)
  block:
    - name: clean staging directory for application tree exists
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}-{{ item.version }}"
        state: directory
        owner: "{{ user }}"
        group: "{{ user }}"
        mode: 0700
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'app_tree') | list }}"

    - name: extract application tree into clean staging
      ansible.builtin.unarchive:
        src: "/home/{{ user }}/.cache/homelab-automation/downloads/{{ item.name }}-{{ item.version }}-{{ item.url | basename }}"
        dest: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}-{{ item.version }}"
        remote_src: true
        extra_opts:
          - --strip-components=1
        owner: "{{ user }}"
        group: "{{ user }}"
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'app_tree') | list }}"

    - name: move verified application tree to permanent version directory
      ansible.builtin.command:
        cmd: "cp -a /home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}-{{ item.version }}/. /home/{{ user }}/.local/share/{{ item.name }}/{{ item.version }}/"
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'app_tree') | list }}"

    - name: clean application tree staging directory
      ansible.builtin.file:
        path: "/home/{{ user }}/.cache/homelab-automation/staging/{{ item.name }}-{{ item.version }}"
        state: absent
      loop: "{{ cli_tools | selectattr('type', 'equalto', 'app_tree') | list }}"

# 8. Activate declared version via ~/bin symlink
- name: active version binary is symlinked to ~/bin
  ansible.builtin.file:
    src: >-
      {{ '/home/' ~ user ~ '/.local/share/' ~ item.name ~ '/' ~ item.version ~ '/bin/' ~ item.name
         if item.type == 'app_tree'
         else '/home/' ~ user ~ '/.local/share/' ~ item.name ~ '/' ~ item.version ~ '/' ~ item.name }}
    dest: "/home/{{ user }}/bin/{{ item.name }}"
    state: link
    force: true
    owner: "{{ user }}"
    group: "{{ user }}"
  loop: "{{ cli_tools }}"
  loop_control:
    label: "~/bin/{{ item.name }} -> {{ item.version }}"
  notify: rebuild bat cache

### C. Dotfile Deployment & Hook Notifications (`roles/apps/cli/tasks/dotfiles.yml`)

Dotfiles are symlinked from the repository checkout into `$HOME/.config`. Modifications to configuration files trigger appropriate post-deployment handlers:

```yaml
---
- name: dotfile directories exist
  ansible.builtin.file:
    path: "/home/{{ user }}/.config/{{ item }}"
    state: directory
    owner: "{{ user }}"
    group: "{{ user }}"
    mode: 0755
  loop:
    - bat
    - nvim
    - yazi

- name: bat configuration is symlinked
  ansible.builtin.file:
    src: "{{ dotfiles_path }}/bat/config"
    dest: /home/{{ user }}/.config/bat/config
    state: link
    follow: false
    owner: "{{ user }}"
    group: "{{ user }}"
  notify: rebuild bat cache

- name: nvim dotfiles directory is symlinked
  ansible.builtin.file:
    src: "{{ dotfiles_path }}/nvim"
    dest: /home/{{ user }}/.config/nvim
    state: link
    follow: false
    owner: "{{ user }}"
    group: "{{ user }}"
```

### D. Handlers & Cache Building (`roles/apps/cli/handlers/main.yml`)

Post-install hooks run via handlers only when binaries or dotfiles are modified, using an explicit absolute path to avoid missing PATH issues:

```yaml
---
- name: rebuild bat cache
  ansible.builtin.command:
    cmd: /home/{{ user }}/bin/bat cache --build
  become: true
  become_user: "{{ user }}"
```

---

## 5. Daily Workflow & Fleeting Integration

### Local Canary Loop (Interactive on `desktop22`)
1. Edit a script in `images/scripts/` or a `Containerfile`.
2. Lint scripts:
   ```sh
   shellcheck images/scripts/*.sh
   ```
3. Build locally with NVIDIA drivers enabled (`desktop22` has an NVIDIA RTX 4070 SUPER):
   ```sh
   sudo podman build \
       --pull=newer \
       --build-arg NVIDIA=true \
       -t localhost/workstation-kde-nvidia:latest \
       -f images/Containerfile.kde .
   ```
4. Apply and reboot:
   ```sh
   sudo bootc switch --apply --transport containers-storage localhost/workstation-kde-nvidia:latest
   ```
5. Verify on bare metal. If broken, pick the previous deployment in GRUB.

### Fleet Synchronization (Asynchronous via Git & CI)
1. Commit the verified change:
   ```sh
   git commit -am "Update KDE image packages"
   git push origin main
   ```
2. GitHub Actions runs ShellCheck, builds both Intel/AMD Mesa and NVIDIA variants with Universal Blue pre-compiled kmods, and pushes multi-tag releases (date, commit SHA, and latest) to GHCR.
3. When sitting at `desktop25` (Intel/AMD Mesa target), run:
   ```sh
   sudo bootc upgrade
   ```

### Updates to the `h` Management Tool

The homelab management tool `h` is maintained as a static, parameterized script in [`images/bin/h`](file:///home/sean/s/homelab-automation-immutable/images/bin/h) and pre-baked into `/usr/bin/h` in the base image with default fallbacks (`AUTOMATION_DIR="${AUTOMATION_DIR:-/var/opt/homelab-automation}"`, `AUTOMATION_SERVICE_NAME="${AUTOMATION_SERVICE_NAME:-ansible-pull}"`). The script **automatically detects whether the local machine has an NVIDIA GPU** by querying the PCI bus for vendor ID `10de`.

#### Automatic Detection Logic in `h`:

```bash
# Helper function for OS container builds
detect_gpu_and_build() {
    local flavor="${1:-kde}"
    local has_nvidia="false"
    local tag_suffix=""

    # 1. Automatic GPU Detection (10de = NVIDIA PCI Vendor ID)
    if lspci -d 10de: -n 2>/dev/null | grep -q '10de:'; then
        has_nvidia="true"
        tag_suffix="-nvidia"
    fi

    # 2. Deterministic Release Tag Generation (matching CI)
    local build_date
    local commit_sha
    local release_tag
    build_date="$(date -u +%Y.%m.%d)"
    commit_sha="$(git -C "${AUTOMATION_DIR}" rev-parse --short HEAD)"
    release_tag="${build_date}-${commit_sha}"
    if [ -n "$(git -C "${AUTOMATION_DIR}" status --porcelain)" ]; then
        release_tag="${release_tag}-dirty"
    fi

    local image_base="localhost/workstation-${flavor}${tag_suffix}"
    local image_tag="${image_base}:latest"
    local release_image="${image_base}:${release_tag}"

    # 3. Lint Build Scripts
    echo "Running ShellCheck on build scripts..."
    shellcheck "${AUTOMATION_DIR}/images/scripts/"*.sh

    # 4. Podman Build (tags both :latest and :YYYY.MM.DD-<sha>)
    echo "Building ${release_image} (NVIDIA=${has_nvidia})..."
    sudo podman build \
        --pull=newer \
        --build-arg NVIDIA="${has_nvidia}" \
        -t "${image_tag}" \
        -t "${release_image}" \
        -f "${AUTOMATION_DIR}/images/Containerfile.${flavor}" \
        "${AUTOMATION_DIR}"

    echo "${image_tag}"
}
```

#### New Subcommands:
* `h os-build [flavor]`: Calls `detect_gpu_and_build` to compile and tag the image locally.
* `h os-switch [flavor]`: Deploys the built image via `sudo bootc switch --apply --transport containers-storage <tag>`.
* `h os-test [flavor]`: Combines build and switch in a single step (ideal for the local canary workflow on `desktop22`).
* `h os-upgrade`: Runs `sudo bootc upgrade` (for secondary fleet machines tracking GHCR).

---

## 6. AI Agent Test Harness, Skill (`test-workstation-image`), & Testing Pyramid

During this migration, autonomous AI agents (Google Antigravity / AGY, Claude Code, and Codex) will be used extensively to iterate on container definitions, build scripts, Ansible roles, and configuration files.

To prevent regressions, ensure idempotency, and allow agents and humans to iterate quickly and autonomously without risking personal data (`~/.ssh`, `~/.aws`, 1Password) or corrupting the host operating system, testing is organized into a **3-Tier Testing Pyramid**.

### The 3-Tier Testing Pyramid

An ordinary container runtime shares the host kernel, lacks ostree sysroot immutability, and cannot load host GPU kernel drivers. The test architecture explicitly acknowledges these boundaries:

| Tier | Environment | Primary Focus | Invariants Validated | Limitations |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1: Molecule (Podman)** | Fast disposable container (`systemd` PID 1) | Fast developer/agent loop for Ansible role tasks, dotfiles symlinks, CLI binary downloads into `~/bin`. | Playbook convergence, Ansible idempotence (`changed=0`), CLI download checksums, `$HOME` symlinks. | Shares host kernel; `/usr` is container-isolated but not a bootc sysroot; cannot test kernel modules (`nvidia.ko`). |
| **Tier 2: Booted VM (QEMU/KVM)** | Headless VM from bootc QCOW2 disk image (`snapshot=on`) | OS-level integration, read-only ostree filesystem, bootc updates and rollbacks. | Kernel-enforced read-only `/usr`, 3-way merge on `/etc`, persistent `/var`, `systemd-resolved`, `tailscaled`, `bootc upgrade/rollback`. | Slower boot (~15–30s); no physical GPU acceleration unless VFIO passthrough is configured. |
| **Tier 3: Bare Metal Canary (`desktop22`)** | Physical hardware deployment | End-to-end hardware, graphical compositor, audio, and proprietary driver validation. | Real NVIDIA RTX 4070 SUPER driver loading (`akmod-nvidia`), Secure Boot MOK enrollment, Wayland session (KDE/Niri), multi-monitor displays, and Steam. | Slower feedback cycle; requires reboot or live canary session. |

### Sandboxing & Security Boundaries

1. **Audited Host Wrapper**: Agents never execute raw, unconstrained privileged commands on the host. Instead, agents invoke the convenience wrapper script:
   ```sh
   .agents/skills/test-workstation-image/scripts/test-workstation [subcommand] [options]
   ```
   > [!NOTE]
   > **Productivity Tooling, Not a Hypervisor Security Jail**
   > The `test-workstation` script is an audited developer/agent convenience and workflow tool to standardize test commands across human and agent workflows. It does not replace kernel-level container cgroups or virtual machine boundaries.

2. **Credential & Host Isolation**:
   - Host private directories (`~/.ssh`, `~/.aws`, `~/.config/1Password`, GPG sockets) are **never** mounted or forwarded into test containers.
   - Any test credentials (e.g. ephemeral SSH keypairs for Tier 2 VM access) are generated on-the-fly inside temporary scratch directories.
   - The repository directory is mounted **read-only** into containers (`--volume ${HOMELAB_REPO_PATH}:/var/opt/homelab-automation:ro` with `security_opts: ["label=disable"]`), ensuring test runs cannot modify git history, relabel host files, or mutate tracked repository files directly. Tasks must not attempt to modify the checkout (e.g. machine-specific dotfile symlinks belong in `/home/sean/.config` rather than mutating `/var/opt/homelab-automation/dotfiles`).

3. **Lifecycle & Disposable State**:
   - Standard test runs automatically destroy containers upon completion.
   - For troubleshooting, an opt-in `--preserve` flag preserves the container after the run (`--destroy=never`) so agents can triage via `test-workstation exec` without starting over.
   - VM runs use copy-on-write disk overlays (`-drive file=...,snapshot=on`), ensuring that any mutations or package upgrades during test VM boots vanish on process termination.

```mermaid
flowchart TD
    subgraph Host["Host Machine (Untouched)"]
        A["Agent: AGY / Claude / Codex"] -->|Invokes wrapper| B["test-workstation script"]
        B -->|Builds test image| C["podman build (localhost/workstation-*:test)"]
    end

    subgraph Tier1["Tier 1: Molecule Container Mode (Fast Iteration)"]
        B -->|Runs molecule test| D["Molecule (Podman Driver)"]
        D -->|Boots container| E["Custom Bootc Container (systemd PID 1)"]
        E -->|Mounts repo read-only| F["/var/opt/homelab-automation:ro"]
        F -->|Converge| G["Ansible Playbook / CLI Engine"]
        G -->|Idempotence Check| H{"Idempotent (changed=0)?"}
        H -- No & --preserve --> I["Container Kept Alive for Triage"]
        I -->|Agent runs test-workstation exec| J["Inspect logs / files via podman exec"]
        J -->|Agent fixes role| K["test-workstation converge"]
        K --> H
        H -- Yes --> L["Run committed verify.yml assertions"]
    end

    subgraph Tier2["Tier 2: Booted OS Sandbox (test-workstation vm)"]
        B -->|Generates QCOW2 / Launches QEMU| M["QEMU Headless VM (snapshot=on)"]
        M -->|Automated SSH Assertions via hostfwd port 22222| N["Verify Read-Only /usr, Resolved, Bootc Updates"]
        N -->|Propagates Exit Code| O{"Assertions Passed?"}
    end

    subgraph Tier3["Tier 3: Physical Canary (desktop22)"]
        P["sudo bootc switch / test"] --> Q["Physical Hardware (NVIDIA RTX 4070, Secure Boot, Wayland)"]
    end

    L -->|Exit code 0 or error| R["Feedback to Agent / CI"]
    O -->|Exit code 0 or error| R
```

### Why the Wrapper Script is Essential Alongside Molecule

1. **Non-Interactive Execution for Agents (`test-workstation exec`)**: Molecule provides `molecule login` which requires an interactive TTY. It lacks a native non-interactive `molecule exec -- <cmd>` interface. When an idempotence check or assertion fails, the wrapper provides `test-workstation exec "<cmd>"`, routing directly to `podman exec` inside the active container so agents can inspect `journalctl`, `systemctl status`, or file permissions non-interactively.
2. **Preserving State During Triage**: By default, `molecule test` cleans up containers. With `--preserve`, the wrapper passes `--destroy=never`, enabling agents to triage, apply fixes, and re-run `converge` without rebuilding.
3. **Dynamic Multi-Flavor Support**: The wrapper accepts `--flavor <kde|niri|gnome>`, builds the matching image tag, and exports `MOLECULE_IMAGE="localhost/workstation-${flavor}:test"`, which Molecule reads directly.
4. **Scenario Routing**: The wrapper routes `-s cli` directly to `roles/apps/cli` (executing scenario `default`) and `-s workstation` to the root-level integration scenario `molecule/workstation/`.
5. **Automated Headless VM Execution**: The wrapper launches headless QEMU with copy-on-write snapshots (`snapshot=on`) and user-mode SSH port forwarding (`hostfwd=tcp::22222-:22`), runs automated verification assertions over SSH (checking kernel-enforced read-only `/usr`, `systemd-resolved`, and ostree updates), and propagates guest exit codes to the host test runner without requiring root privileges or bridge setup. For full multi-host LAN or NFS routing tests, QEMU can optionally attach to `virbr0` via the bridge helper.

### Committed Molecule Scenarios in Git

The repository maintains two permanent Molecule scenarios:

#### 1. Role-Level Scenario: `roles/apps/cli/molecule/default/`
Validates that all static CLI tools download, verify checksums, extract, install to `$HOME/bin`, symlink dotfiles, and execute properly.

* **`roles/apps/cli/molecule/default/molecule.yml`**:
```yaml
---
dependency:
  name: galaxy
driver:
  name: podman
platforms:
  - name: cli-test
    image: "${MOLECULE_IMAGE:-localhost/workstation-kde:test}"
    command: /sbin/init
    systemd: always
    capabilities:
      - SYS_ADMIN
    security_opts:
      - label=disable
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - "${HOMELAB_REPO_PATH:-/var/opt/homelab-automation}:/var/opt/homelab-automation:ro"
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        user: sean
        dotfiles_path: /var/opt/homelab-automation/dotfiles
        playbook_path: /var/opt/homelab-automation
        is_graphical_system: true
  playbooks:
    converge: converge.yml
    verify: verify.yml
verifier:
  name: ansible
```

* **`roles/apps/cli/molecule/default/verify.yml`**:
```yaml
---
- name: verify CLI tools and dotfiles
  hosts: all
  gather_facts: false
  tasks:
    - name: verify ripgrep is executable in ~/bin
      ansible.builtin.stat:
        path: /home/sean/bin/rg
      register: rg_stat
      failed_when: not rg_stat.stat.exists or not rg_stat.stat.executable

    - name: verify nvim symlink points to active bundle
      ansible.builtin.stat:
        path: /home/sean/bin/nvim
      register: nvim_stat
      failed_when: not nvim_stat.stat.islnk

    - name: verify nvim dotfiles symlink
      ansible.builtin.stat:
        path: /home/sean/.config/nvim
      register: nvim_dotfiles
      failed_when: not nvim_dotfiles.stat.islnk

    - name: verify bat executes cleanly
      ansible.builtin.command:
        cmd: /home/sean/bin/bat --version
      changed_when: false
```

#### 2. Root-Level Integration Scenario: `molecule/workstation/`
Validates that the entire workstation configuration applies cleanly to the bootc container image, passes idempotence, and configures core host services.

* **`molecule/workstation/molecule.yml`**:
```yaml
---
dependency:
  name: galaxy
driver:
  name: podman
platforms:
  - name: workstation-test
    image: "${MOLECULE_IMAGE:-localhost/workstation-kde:test}"
    command: /sbin/init
    systemd: always
    capabilities:
      - SYS_ADMIN
    security_opts:
      - label=disable
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:rw
      - "${HOMELAB_REPO_PATH:-/var/opt/homelab-automation}:/var/opt/homelab-automation:ro"
provisioner:
  name: ansible
  inventory:
    group_vars:
      all:
        user: sean
        dotfiles_path: /var/opt/homelab-automation/dotfiles
        playbook_path: /var/opt/homelab-automation
        is_graphical_system: true
  playbooks:
    converge: converge.yml
    verify: verify.yml
verifier:
  name: ansible
```

* **`molecule/workstation/verify.yml`**:
```yaml
---
- name: verify workstation configuration
  hosts: all
  gather_facts: false
  tasks:
    - name: verify systemd-resolved service is active
      ansible.builtin.service:
        name: systemd-resolved
        state: started
      check_mode: true
      register: resolved_status
      failed_when: resolved_status.changed

    - name: verify nextdns DoT configuration in resolved.conf.d exists
      ansible.builtin.stat:
        path: /etc/systemd/resolved.conf.d/nextdns.conf
      register: nextdns_conf
      failed_when: not nextdns_conf.stat.exists

    - name: verify nextdns upstream DNS is configured
      ansible.builtin.lineinfile:
        path: /etc/systemd/resolved.conf.d/nextdns.conf
        line: "DNS=45.90.28.0#e8fc2a.dns.nextdns.io"
        state: present
      check_mode: true
      register: nextdns_line
      failed_when: nextdns_line.changed
```

> [!NOTE]
> **Filesystem Immutability Verification**
> Container-based Molecule runs cannot enforce true bootc ostree sysroot immutability because containers share the host kernel and container filesystems remain mutable unless explicitly configured otherwise. Verification of genuine kernel-enforced read-only `/usr`, 3-way merge on `/etc`, and ostree rollbacks is performed exclusively in **Tier 2 (Booted VM)** and **Tier 3 (Physical Canary)**.

### The Wrapper CLI Interface (`scripts/test-workstation`)

The wrapper provides a clean, predictable command set:

```sh
# 1. Run Molecule test suite (destroys container on completion by default)
.agents/skills/test-workstation-image/scripts/test-workstation test [--flavor kde|niri|gnome] [-s workstation|cli]

# 2. Run with --preserve to keep container alive on failure for triage
.agents/skills/test-workstation-image/scripts/test-workstation test --preserve [-s workstation|cli]

# 3. Exec arbitrary commands inside the running test container (non-interactive diagnostic)
.agents/skills/test-workstation-image/scripts/test-workstation exec "journalctl -xe"
.agents/skills/test-workstation-image/scripts/test-workstation exec "ls -la /home/sean/bin"

# 4. Iterative debugging loop (re-test without rebuilding)
.agents/skills/test-workstation-image/scripts/test-workstation converge [-s workstation|cli]
.agents/skills/test-workstation-image/scripts/test-workstation idempotence [-s workstation|cli]
.agents/skills/test-workstation-image/scripts/test-workstation verify [-s workstation|cli]

# 5. Clean up the test container
.agents/skills/test-workstation-image/scripts/test-workstation destroy [-s workstation|cli]

# 6. Tier 2 Booted VM Mode (boots QEMU/KVM for real kernel/bootc invariant verification)
.agents/skills/test-workstation-image/scripts/test-workstation vm-build [--flavor kde]
.agents/skills/test-workstation-image/scripts/test-workstation vm [--flavor kde]
```

### Audited Host Wrapper Implementation (`scripts/test-workstation`)

```bash
#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
usage: test-workstation <subcommand> [options]

Subcommands:
    test [options]       Run Molecule test suite (destroys on completion by default).
    exec "<cmd>"         Execute command inside active test container (non-interactive).
    converge [options]   Re-run playbook convergence on active container.
    idempotence [opts]   Re-run idempotency check on active container.
    verify [options]     Re-run verification assertions on active container.
    destroy [options]    Destroy active test container.
    vm-build [options]   Build a bootable QCOW2 VM disk from container via bootc-image-builder.
    vm [options]         Launch headless QEMU/KVM VM and execute automated SSH assertions.
    help                 Show this help text.

Options:
    --flavor FLAVOR      Workstation flavor to test (kde|gnome|niri, default: kde).
    --scenario|-s SCEN   Molecule scenario: 'workstation' or 'cli' (default: workstation).
    --preserve           Preserve test container after run for interactive triage (--destroy=never).
    --rebuild            Force rebuild of the container image before testing.
EOF
}

if [ "$#" -eq 0 ]; then
    usage
    exit 1
fi

subcommand="$1"
shift

repo_root="$(git rev-parse --show-toplevel)"
export HOMELAB_REPO_PATH="${repo_root}"
flavor="kde"
scenario="workstation"
rebuild=false
preserve=false
extra_args=()

while [ "$#" -gt 0 ]; do
    case "$1" in
        --flavor)
            flavor="$2"
            shift 2
            ;;
        --scenario|-s)
            scenario="$2"
            shift 2
            ;;
        --preserve)
            preserve=true
            shift
            ;;
        --rebuild)
            rebuild=true
            shift
            ;;
        *)
            extra_args+=("$1")
            shift
            ;;
    esac
done

image_tag="localhost/workstation-${flavor}:test"
export MOLECULE_IMAGE="$image_tag"

ensure_image() {
    if "$rebuild" || ! podman image exists "$image_tag"; then
        echo "Building test image ${image_tag}..."
        podman build \
            --build-arg NVIDIA=false \
            -t "$image_tag" \
            -f "${repo_root}/images/Containerfile.${flavor}" \
            "${repo_root}"
    fi
}

resolve_scenario_dir() {
    if [ "$scenario" = "cli" ]; then
        echo "${repo_root}/roles/apps/cli"
    elif [ "$scenario" = "workstation" ]; then
        echo "${repo_root}"
    else
        echo "${repo_root}"
    fi
}

resolve_molecule_scenario_name() {
    if [ "$scenario" = "cli" ]; then
        echo "default"
    else
        echo "$scenario"
    fi
}

get_container_name() {
    local sc_name
    sc_name="$(resolve_molecule_scenario_name)"
    podman ps --filter "name=^(${sc_name}-test|cli-test|workstation-test)$" --format "{{.Names}}" | head -n 1
}

run_molecule() {
    local action="$1"
    shift
    local scen_dir
    local scen_name
    scen_dir="$(resolve_scenario_dir)"
    scen_name="$(resolve_molecule_scenario_name)"

    pushd "$scen_dir" > /dev/null
    echo "Running 'molecule ${action}' for scenario '${scen_name}' with image '${MOLECULE_IMAGE}'..."
    molecule "$action" -s "$scen_name" "$@"
    popd > /dev/null
}

case "$subcommand" in
    test)
        ensure_image
        scen_flags=()
        if "$preserve"; then
            scen_flags+=(--destroy=never)
        fi
        run_molecule test "${scen_flags[@]}" "${extra_args[@]}"
        ;;
    exec)
        container_name="$(get_container_name)"
        if [ -z "$container_name" ]; then
            echo "Error: No active Molecule container found for scenario '${scenario}'." >&2
            exit 1
        fi
        echo "Executing inside container '${container_name}': ${extra_args[*]}"
        podman exec "$container_name" sh -c "${extra_args[*]}"
        ;;
    converge)
        ensure_image
        run_molecule converge "${extra_args[@]}"
        ;;
    idempotence)
        run_molecule idempotence "${extra_args[@]}"
        ;;
    verify)
        run_molecule verify "${extra_args[@]}"
        ;;
    destroy)
        run_molecule destroy "${extra_args[@]}"
        ;;
    vm-build)
        ensure_image
        echo "Provisioning ephemeral VM test credentials..."
        mkdir -p "${repo_root}/build/vm"
        ssh_key="${repo_root}/build/vm/test_id_ed25519"
        if [ ! -f "$ssh_key" ]; then
            ssh-keygen -t ed25519 -N "" -f "$ssh_key" -C "test-workstation-vm" >/dev/null
        fi

        test_vm_image="${image_tag}-vm"
        echo "Injecting test credentials and sshd into ${test_vm_image}..."
        podman build -t "$test_vm_image" - <<EOF
FROM ${image_tag}
RUN id -u sean 2>/dev/null || useradd -m -u 1000 -G wheel sean && \\
    mkdir -p /etc/sudoers.d /home/sean/.ssh && \\
    echo "%wheel ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/wheel-nopasswd && \\
    chmod 0440 /etc/sudoers.d/wheel-nopasswd && \\
    echo "$(cat "${ssh_key}.pub")" >> /home/sean/.ssh/authorized_keys && \\
    chmod 0700 /home/sean/.ssh && \\
    chmod 0600 /home/sean/.ssh/authorized_keys && \\
    chown -R sean:sean /home/sean && \\
    systemctl enable sshd
EOF

        # bootc-image-builder runs as root and mounts /var/lib/containers/storage.
        # Transfer the image from rootless storage into root storage if missing or updated:
        if ! sudo podman image exists "$test_vm_image" || [ "$(podman inspect --format '{{.Id}}' "$test_vm_image")" != "$(sudo podman inspect --format '{{.Id}}' "$test_vm_image" 2>/dev/null)" ]; then
            echo "Transferring ${test_vm_image} from rootless storage to root storage for bootc-image-builder..."
            podman save "$test_vm_image" | sudo podman load
        fi
        echo "Building QCOW2 VM disk from ${test_vm_image} using bootc-image-builder..."
        sudo podman run --rm --privileged \
            -v /var/lib/containers/storage:/var/lib/containers/storage \
            -v "${repo_root}/build/vm":/output \
            quay.io/centos-bootc/bootc-image-builder:latest \
            --type qcow2 \
            --local "${test_vm_image}"
        mv "${repo_root}/build/vm/qcow2/disk.qcow2" "${repo_root}/build/vm/workstation-${flavor}.qcow2"
        echo "VM disk ready at ${repo_root}/build/vm/workstation-${flavor}.qcow2"
        ;;
    vm)
        base_disk="${repo_root}/build/vm/workstation-${flavor}.qcow2"
        ssh_key="${repo_root}/build/vm/test_id_ed25519"
        if [ ! -f "$base_disk" ] || [ ! -f "$ssh_key" ]; then
            echo "Error: Base VM disk '$base_disk' or test key '$ssh_key' not found." >&2
            echo "Run 'test-workstation vm-build --flavor ${flavor}' first." >&2
            exit 1
        fi

        echo "Starting headless QEMU/KVM test VM with copy-on-write snapshot..."
        ssh_port=22222
        vm_run_dir="$(mktemp -d "/tmp/test-workstation-vm.XXXXXX")"
        qemu_pid_file="${vm_run_dir}/qemu.pid"
        qemu_log="${vm_run_dir}/qemu.log"

        cleanup_vm() {
            echo "Stopping QEMU test VM..."
            if [ -f "$qemu_pid_file" ]; then
                kill "$(cat "$qemu_pid_file")" 2>/dev/null || true
            fi
            rm -rf "$vm_run_dir"
        }
        trap cleanup_vm EXIT INT TERM

        # Launch QEMU with loopback forwarding, snapshot=on, headless display, and serial log:
        qemu-system-x86_64 \
            -enable-kvm \
            -m 4G \
            -smp 4 \
            -drive "file=${base_disk},if=virtio,snapshot=on" \
            -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${ssh_port}-:22" \
            -device virtio-net-pci,netdev=net0 \
            -display none \
            -serial "file:${qemu_log}" \
            -pidfile "$qemu_pid_file" &

        ssh_opts=(
            -i "$ssh_key"
            -o StrictHostKeyChecking=no
            -o UserKnownHostsFile=/dev/null
            -o BatchMode=yes
            -o ConnectTimeout=2
            -o LogLevel=ERROR
            -p "${ssh_port}"
            sean@127.0.0.1
        )

        echo "Waiting for VM SSH on 127.0.0.1:${ssh_port}..."
        ssh_ready=false
        for _ in $(seq 1 45); do
            if ssh "${ssh_opts[@]}" true 2>/dev/null; then
                ssh_ready=true
                break
            fi
            sleep 2
        done

        if ! "$ssh_ready"; then
            echo "[FAIL] VM SSH readiness timed out after 90 seconds." >&2
            if [ -f "$qemu_log" ]; then
                echo "--- QEMU Serial Console Log ---" >&2
                tail -n 40 "$qemu_log" >&2
            fi
            exit 1
        fi

        echo "Running Tier 2 OS invariant assertions over SSH..."
        test_failed=0

        # Assert 1: /usr is kernel-enforced read-only against root (assert EROFS)
        ro_output="$(ssh "${ssh_opts[@]}" "sudo touch /usr/.immutable_test 2>&1 || true")"
        if echo "$ro_output" | grep -qi "Read-only file system"; then
            echo "[PASS] /usr is strictly read-only (kernel EROFS asserted)."
        else
            echo "[FAIL] Expected EROFS 'Read-only file system' on /usr, got: $ro_output" >&2
            test_failed=1
        fi

        # Assert 2: /var is persistent and writable
        if ssh "${ssh_opts[@]}" "sudo touch /var/.persist_test && sudo rm -f /var/.persist_test"; then
            echo "[PASS] /var is persistent and writable."
        else
            echo "[FAIL] /var is not writable!" >&2
            test_failed=1
        fi

        # Assert 3: /etc is writable with ostree 3-way merge support
        if ssh "${ssh_opts[@]}" "sudo touch /etc/.rw_test && sudo rm -f /etc/.rw_test"; then
            echo "[PASS] /etc is writable."
        else
            echo "[FAIL] /etc is not writable!" >&2
            test_failed=1
        fi

        # Assert 4: systemd-resolved is active
        if ! ssh "${ssh_opts[@]}" "systemctl is-active systemd-resolved"; then
            echo "[FAIL] systemd-resolved is not active!" >&2
            test_failed=1
        else
            echo "[PASS] systemd-resolved is active."
        fi

        # Assert 5: bootc status reports active ostree deployment
        if ! ssh "${ssh_opts[@]}" "sudo bootc status"; then
            echo "[FAIL] bootc status failed!" >&2
            test_failed=1
        else
            echo "[PASS] bootc deployment verified."
        fi

        if [ "$test_failed" -ne 0 ]; then
            echo "VM verification failed!" >&2
            exit 1
        fi
        echo "VM verification passed successfully."
        ;;
    help|--help|-h)
        usage
        exit 0
        ;;
    *)
        echo "Error: Unknown subcommand '$subcommand'." >&2
        usage
        exit 1
        ;;
esac
```

### Multi-Agent Compatibility (AGY, Claude Code, Codex)

To ensure this skill operates identically across all AI harnesses, it follows the repository standard established in `AGENTS.md`:

* **Source of Truth**: The skill lives in `.agents/skills/test-workstation-image/`.
* **Codex & AGY**: Codex and Google Antigravity discover skills in `.agents/skills/` natively.
* **Claude Code**: `.claude/skills/test-workstation-image` is a symbolic link pointing to `../../.agents/skills/test-workstation-image`.
* **Tool-Agnostic Interface**: The skill documentation in `SKILL.md` specifies standard command execution lines (`.agents/skills/test-workstation-image/scripts/test-workstation ...`) that map directly to AGY's `run_command`, Claude Code's `Bash`, and Codex's shell execution tools.

---

## 7. Multi-Host Agent Synchronization & YOLO Sandboxing (Optional enhancement)

To allow AI agent harnesses (Google Antigravity / AGY, Claude Code, and Codex) to operate in autonomous "YOLO" mode across the fleet (`desktop22`, `desktop25`, `x1carbon2018`), the system establishes a dedicated unprivileged user: **`agent`**.

This design accomplishes two critical goals:
1. **Host & Personal Data Security**: Complete isolation of personal credentials (`~/.ssh`, `~/.aws`, 1Password) and host OS integrity without the overhead or latency of running a full VM for editing.
2. **Fleet-Wide Session Mobility**: Centralized storage on `odroidh3plus` so that conversation histories, transcripts, and brain artifacts follow you seamlessly from desktop to laptop.

### Storage & Access Control Architecture

The `agent` user requires granular permissions: full read/write access to project code repositories, but **zero access** to personal directories or general homelab network storage:

| Path | Location | Intended Access | Enforcement Mechanism |
| :--- | :--- | :--- | :--- |
| **`/home/sean`** | Local Host | **DENIED (0 access)** | Standard Linux DAC: mode `0700` (`drwx------`) owned by `sean:sean`. |
| **`/srv/tier1`** | NFS (`odroidh3plus`) | **DENIED (0 access)** | Mount/export mode `0770` (`drwxrwx---`) owned by `sean:networkshare`. `agent` is strictly **excluded** from `networkshare`. |
| **`/srv/tier2`** | NFS (`odroidh3plus`) | **DENIED (0 access)** | Mount/export mode `0770` (`drwxrwx---`) owned by `sean:networkshare`. `agent` is strictly **excluded** from `networkshare`. |
| **`/source`** | NFS (`odroidh3plus`) | **Read / Write** | Dedicated group `sourceshare` (GID `5568`). Both `sean` and `agent` are members. Export uses standard `root_squash` (no `all_squash`). |
| **`/src`** | Local Host | **Read / Write** | Dedicated group `sourceshare` with `setgid` bit (`2775`) and user `umask 0002`. |
| **`/var/opt/homelab-automation`** | Local Host | **Read / Write** | Owned by `root:sourceshare` with `setgid` bit (`2775`) and `git config core.sharedRepository group`. `agent` is **never** added to `wheel` or `docker`. |

#### Why This Access Model is Secure
* **NFS Trusted-Client & Server Enforcement**: Standard NFS (`AUTH_SYS`) relies on trusted client OS kernels to enforce user boundaries locally. On managed workstations (`desktop22`, `desktop25`, etc.), unprivileged user `agent` (UID 1500) is barred by local DAC from accessing `/home/sean` or forging RPC credentials. `odroidh3plus` runs standard `root_squash` and rejects client UID 1500 from accessing `/srv/tier1` and `/srv/tier2` (mode `0770` owned by `sean:networkshare`).
* **Locking out `/srv/tier1` and `/srv/tier2`**: By maintaining export and directory permissions on `tier1` and `tier2` at `0770` and ensuring `agent` is not in `networkshare` (GID 5567), `other` bits have no permissions (`---`). Any attempt by `agent` to traverse, read, or write to these shares is blocked immediately by the server with `EACCES (Permission denied)`.
* **Safe write access to `/var/opt/homelab-automation` and `/src` via `setgid` & Git Shared Repository**: Rather than fragile POSIX ACLs, multi-user collaboration uses standard Unix `setgid` (`02775`) on directories owned by group `sourceshare`. Any new file or subdirectory created automatically inherits group `sourceshare`. In Git repositories, configuring `git config core.sharedRepository group` instructs Git to create repository objects, refs, and working-tree files group-writable (`0664`/`0775`), allowing `sean` and `agent` to collaborate without requiring ACL tooling or sudo/wheel membership.
* **Dotfiles Symlinks & Accepted Risk**: Per repository convention in `AGENTS.md`, dotfiles under `/var/opt/homelab-automation/dotfiles` are symlinked into `/home/sean` so that live edits in the user environment sync directly to the git repo without manual copying. Because of these symlinks, modifications by the agent to files in `dotfiles/` take effect immediately in Sean's interactive desktop session upon next editor/shell invocation. Retaining symlinks is an explicit, conscious trade-off prioritized for authoring ergonomics and live testing speed.

---

### Cross-Machine Chat Synchronization

When moving between workstations, conversation state (transcripts, context memories, brain artifacts) should persist centrally. Two synchronization architectures are supported:

#### Option A: Full Agent Home on NFS (Primary Architecture)
The home directory or centralized state of the `agent` user is mounted from `odroidh3plus` under the shared `/source` export via NFS automount (`odroidh3plus:/source/agent-homes` or `/source/agent-state`).

```text
odroidh3plus (NFS Server)
└── /source/agent-state/
    ├── .gemini/antigravity-cli/brain/   <-- AGY transcripts & artifacts
    ├── .claude/                         <-- Claude Code projects & history
    ├── .codex/sessions/                 <-- Codex session state
    ├── .bashrc                          <-- Shell environment & PATH
    └── .env                             <-- Dedicated AI API keys ONLY
```
*(Placing agent state under `/source` avoids the directory traversal block on `/srv/tier1`, since `/source` is an independent NFS export already authorized for `sourceshare`).*

##### Critical NFS Safeguards for Option A
To prevent standard NFS pitfalls (socket errors, cache latency, locking collisions), the following configuration is enforced:

1. **Pinned Fleet-Wide UID/GID**:
   NFS maps permissions strictly by numeric ID. The `agent` user is pinned across all managed hosts and `odroidh3plus` to:
   - `uid: 1500`
   - `gid: 1500`
2. **Diverting UNIX Domain Sockets to RAM (`XDG_RUNTIME_DIR`)**:
   UNIX domain sockets (`.sock`) cannot be bound over NFS. In `~agent/.bashrc`:
   ```bash
   export XDG_RUNTIME_DIR="/run/user/1500"
   ```
   Sockets for IPC and background daemons are created on local host tmpfs, avoiding NFS failures.
3. **Diverting High-Frequency Caches to Local NVMe (`XDG_CACHE_HOME`)**:
   Package managers (`npm`, `pip`, `cargo`) create tens of thousands of tiny files in `~/.cache`. In `~agent/.bashrc`:
   ```bash
   export XDG_CACHE_HOME="/var/tmp/agent-cache"
   ```
   Compilation and package caching run at local NVMe speeds, eliminating NFS network latency.
4. **Concurrency Operational Rule**:
   Because you are a single user moving between desks, avoid prompting the *exact same active conversation ID* from two machines at the same physical second to prevent write race conditions. Resuming prior chats or starting new chats across hosts is fully supported.

---

#### Option B: Local Home + Dedicated State Symlinks (Alternative Architecture)
If full home NFS mounting causes lock friction with hidden dotfiles, Option B maintains `/var/home/agent` locally on each workstation's NVMe drive, symlinking only the state and history directories to the shared `/source` NFS mount:

```bash
# State directories symlinked to shared NFS storage
~agent/.gemini -> /source/agent-state/.gemini
~agent/.claude -> /source/agent-state/.claude
~agent/.codex  -> /source/agent-state/.codex
~agent/.env    -> /source/agent-state/.env
```

* **Pros**: Zero possibility of NFS dotfile locking; 100% local shell performance.
* **Cons**: Dotfiles and installed tool versions must be provisioned locally on each machine by Ansible.

---

### Ansible Implementation Blueprint

A dedicated role (`roles/system/agent_harness`) or extension to `roles/system/core` configures this architecture declaratively:

```yaml
---
- name: dedicated agent group exists
  ansible.builtin.group:
    name: agent
    gid: 1500

- name: sourceshare group exists for code access
  ansible.builtin.group:
    name: sourceshare
    gid: 5568

- name: agent user exists with restricted group membership
  ansible.builtin.user:
    name: agent
    uid: 1500
    group: agent
    groups:
      - sourceshare
    append: false
    shell: /bin/bash
    home: /var/home/agent

- name: /var/opt/homelab-automation group ownership is sourceshare with setgid
  ansible.builtin.file:
    path: /var/opt/homelab-automation
    group: sourceshare
    mode: 02775
    state: directory
    recurse: false

- name: git shared repository configuration is set on homelab-automation
  community.general.git_config:
    repo: /var/opt/homelab-automation
    name: core.sharedRepository
    value: group
    scope: local

- name: /var/src directory exists with shared development permissions
  ansible.builtin.file:
    path: /var/src
    state: directory
    owner: "{{ user }}"
    group: sourceshare
    mode: 02775

- name: NFS automount configured for agent home (Option A)
  ansible.posix.mount:
    path: /var/home/agent
    src: "odroidh3plus:/source/agent-homes"
    fstype: nfs
    boot: false
    opts: x-systemd.automount,x-systemd.mount-timeout=10,nofail
    state: present
```

### Daily Usage: The `yolo-agent` Launcher

To launch any harness in YOLO mode without typing sudo passwords or switching shells, add a desktop launcher or helper in `/home/sean/bin/yolo-agent`:

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-/var/opt/homelab-automation}"

echo "Launching Agent in YOLO mode on ${TARGET_DIR} (as unprivileged user 'agent')..."
exec sudo -u agent -i bash -c "cd '${TARGET_DIR}' && exec agy"
# Or Claude Code:
# exec sudo -u agent -i bash -c "cd '${TARGET_DIR}' && exec claude --dangerously-skip-permissions"
```

---

## 8. Phased Migration Checklist

- [ ] **Phase 0: Implement the `test-workstation-image` Skill, Molecule Framework, & VM Rehearsal**
  - Create `.agents/skills/test-workstation-image/` (`SKILL.md` and `scripts/test-workstation`).
  - Create symlink `.claude/skills/test-workstation-image -> ../../.agents/skills/test-workstation-image` to maintain full AGY, Claude Code, and Codex synchronization.
  - Implement top-level Molecule scenario `molecule/workstation/` (`molecule.yml`, `converge.yml`, `verify.yml`) pointing to `${MOLECULE_IMAGE}`.
  - Wire `test-workstation` to orchestrate Molecule with subcommands: `test` (with optional `--preserve`), `exec` (`podman exec`), `converge`, `idempotence`, `verify`, and `destroy`.
  - Implement `vm-build` (via `bootc-image-builder`) and `vm` mode using QEMU/KVM (`snapshot=on`) with automated SSH invariant assertions over forwarded port 22222.
  - Rehearse the clean installation and disk layout in a virtual machine before touching physical hardware.
- [ ] **Phase 1: Refactor CLI, Roles & Playbooks in Ansible (`immutable` branch)**
  - Implement `cli_tools` data structure and tasks in `roles/apps/cli` to deliver binaries into `$HOME/bin`.
  - Refactor `desktop22.yml` and underlying roles directly in the `immutable` branch based on the responsibility audit (removing obsolete `dnf`/`rpm_fusion` roles and separating image-baked packages from runtime config).
  - Create `roles/apps/cli/molecule/default/` (`molecule.yml`, `converge.yml`, `verify.yml`) to test tool installation and symlinks.
  - Validate in Phase 0 harness (`test-workstation test -s cli`).
  - Verify idempotency passes cleanly (`changed=0` on second converge).
  - Verify all binaries download cleanly into `~/bin` and dotfiles symlink properly.
  - Add GitHub Actions step running `molecule test` on push and pull requests.
- [ ] **Phase 2: Set up Container Build & Secure Boot MOK Enrollment**
  - Enroll Universal Blue public MOK key (`ublue-os.der`) via `mokutil` on `desktop22`.
  - Verify `shellcheck images/scripts/*.sh` passes.
  - Test local build of `images/Containerfile.kde` with `NVIDIA=true` using pre-compiled `kmods-nvidia`.
  - Ensure image pre-bakes Python/Ansible bootstrap, pre-creates mount points (`/source`, `/src`, `/games`, `/srv/tier1`, `/srv/tier2`), and ensures `/var/opt` exists.
  - Verify NVIDIA modules load cleanly under Secure Boot and Wayland (KDE/SDDM).
- [ ] **Phase 3: Install Atomic OS on `desktop22`**
  - **User Data Backup**: Back up personal data, documents, and credentials from `/home/sean` to external storage or `/source` on NFS (preserving the separate `/games` physical SSD on `/dev/sda1` as-is).
  - **Clean OS Installation**: Install stock Fedora Kinoite on target NVMe drive (`nvme1n1`), formatting fresh EFI and Btrfs root partitions with `/var/home`.
  - **Restore User Data & Mounts**:
    - Mount `/dev/sda1` (XFS, UUID `b590b81d-172c-4951-a4bd-9eec0dc290db`) to `/games` in `/etc/fstab`.
    - Create user `sean` with `uid: 1000, gid: 1000`.
    - Copy backed-up user data into `/var/home/sean` and verify ownership.
    - Run `restorecon -Rv /var/home/sean` to ensure correct SELinux contexts on restored files.
  - **Transition to Custom bootc Image**:
    - Switch host to local or GHCR image:
      ```sh
      sudo bootc switch --apply --transport containers-storage localhost/workstation-kde-nvidia:latest
      ```
    - Reboot into the custom immutable image.
- [ ] **Phase 4: Run Ansible & Complete Workstation Acceptance Suite**
  - Clone repo to `/var/opt/homelab-automation` and run initial playbook:
    ```sh
    sudo ansible-pull --directory /var/opt/homelab-automation desktop22.yml
    ```
  - **Run Post-Migration Acceptance Checklist**:
    1. [ ] **CLI Delivery**: All `$HOME/bin` tools (`nvim`, `rg`, `fd`, `bat`, `yazi`, `zsh`, `tmux`) execute cleanly; Neovim loads runtime trees from `~/.local/share/nvim-dist`.
    2. [ ] **DNS & Networking**: `systemd-resolved` active; DNS over TLS queries to NextDNS resolve correctly (`resolvectl status`); short hostnames (`odh3p.3246.win`) resolve via search domain.
    3. [ ] **NFS Homelab Storage**: Automounts to `odroidh3plus` (`/source`, `/srv/tier1`, `/srv/tier2`) mount on access with proper permissions (`networkshare` / `sourceshare`).
    4. [ ] **Network & VPN**: Tailscale authenticates and routes LAN/remote traffic (`tailscale status`).
    5. [ ] **Audio & Media**: PipeWire and WirePlumber running; sound outputs switch cleanly in `pavucontrol`; volume/media keys function via `playerctl` and `wpctl`.
    6. [ ] **Gaming**: Steam launches, recognizes the `/games` library on `/dev/sda1`, Proton games launch, and gamepad rules work.
    7. [ ] **Communication & Portals**: Zoom Flatpak launches; Wayland screensharing works via WLR/GTK portal priority (`/etc/xdg/xdg-desktop-portal/niri-portals.conf`); audio input/output works in Zoom.
    8. [ ] **NVIDIA GPU Acceleration**: `nvidia-smi` confirms driver version and RTX 4070 SUPER; CUDA runtime functional; Wayland desktop rendering is smooth.
    9. [ ] **Upgrade & Rollback Invariance**:
       - Run `sudo bootc upgrade` (or switch to a new test tag). Reboot and verify new deployment.
       - Run `sudo bootc rollback`. Reboot into previous deployment.
       - Confirm mutable user data in `/var/home/sean` and `/games` remains 100% intact across rollbacks.
- [ ] **Phase 5: Expand to `desktop25` & Other DEs**
  - Add `images/Containerfile.niri` to test Niri switching.
  - Refactor `desktop25.yml` for immutable deployment.
  - Enroll MOK key on `desktop25` and point it to the GHCR image.
- [ ] **Phase 6: Multi-Host Agent Sandboxing & Fleet Mobility (Post-Migration Project)**
  - Provision unprivileged `agent` user (UID/GID 1500) with access to `/source`, `/src`, and `/var/opt/homelab-automation`, ensuring complete denial to `/srv/tier1`, `/srv/tier2`, and `/home/sean`.
  - Update `roles/services/nfs` on `odroidh3plus` to replace `all_squash,anonuid,anongid` with standard `root_squash` to enforce server-side UID/GID permissions.
  - Configure network storage synchronization for agent workspace.
