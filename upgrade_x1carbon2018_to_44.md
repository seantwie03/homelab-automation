# Upgrade x1carbon2018 from Fedora 43 to Fedora 44

This procedure upgrades `x1carbon2018` using Fedora's supported DNF5 offline
system-upgrade workflow.

Host facts observed on June 13, 2026:

- Lenovo ThinkPad X1 Carbon 6th Gen (`20KG0022US`)
- Intel Core i7-8550U with Intel UHD Graphics 620
- Intel 8265/8275 Wi-Fi
- Fedora 43 with a Btrfs root filesystem
- `/boot` is part of the root subvolume; `/boot/efi` is a separate 1 GiB ESP
- `/`, `/home`, `/opt`, and `/var/lib/libvirt` are separate Btrfs subvolumes
- approximately 415 GiB was free on the 476 GiB Btrfs filesystem
- Secure Boot was disabled

References:

- [Fedora offline upgrade documentation](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/)
- [Fedora 44 common issues](https://fedoraproject.org/wiki/Common_F44_bugs)

## 1. Prepare this repository

The DNF role already uses the Fedora 44 canonical `dnf5-automatic.timer` and
`dnf5-automatic.service` names. It leaves the still-canonical
`dnf-makecache.timer` and `dnf-makecache.service` names unchanged.

Before upgrading:

1. Run the repository lint:

   ```bash
   cd /opt/homelab-automation
   ansible-lint
   ```

2. Commit and push all intended repository changes. This is particularly
   important on this host because `/opt` is a separate Btrfs subvolume and is
   not included in a Snapper snapshot of the root subvolume.
3. Apply the final Fedora 43 configuration and confirm that it succeeds:

   ```bash
   sudo h a test x1carbon2018.yml
   ```

4. Confirm that the DNF5 Automatic schedule and service override are loaded:

   ```bash
   systemctl cat dnf5-automatic.timer
   systemctl cat dnf5-automatic.service
   systemctl status dnf5-automatic.timer
   ```

The output should include the repository-managed schedule and Snapper pre/post
commands.

## 2. Review Fedora 44 issues

Immediately before the upgrade, review the
[Fedora 44 common issues](https://fedoraproject.org/wiki/Common_F44_bugs) page.
The wiki links to the current Fedora Discussion common-issues list.

Pay particular attention to:

- Intel graphics and Wayland
- Intel 8265 Wi-Fi, NetworkManager, and `wpa_supplicant`
- suspend, resume, USB-C charging, docks, and external displays
- Btrfs, GRUB, and EFI boot issues
- Niri, Hyprland, libvirt, RPM Fusion, and COPR compatibility

## 3. Update and verify Fedora 43

Install all Fedora 43 updates and reboot into the latest installed kernel:

```bash
sudo dnf upgrade --refresh
sudo reboot
```

This host was running kernel `7.0.10-101.fc43.x86_64` while
`7.0.12-100.fc43.x86_64` was already installed when this plan was written.
After rebooting, verify the release, running kernel, storage, and Btrfs health:

```bash
cat /etc/fedora-release
uname -r
rpm -q kernel-core
df -h / /boot/efi
findmnt --mountpoint /
findmnt --mountpoint /home
findmnt --mountpoint /opt
findmnt --mountpoint /var/lib/libvirt
findmnt --mountpoint /boot/efi
sudo btrfs filesystem usage /
sudo btrfs scrub status /
```

The Btrfs filesystem had ample free space when this plan was written, but
recheck it immediately before upgrading. Resolve any scrub or filesystem
errors before continuing.

Verify the RPM database and installed package dependencies:

```bash
sudo rpm --verifydb
sudo rpm -qa >/dev/null
sudo dnf check
```

Zoom is currently absent, and the `gui` role intentionally keeps it absent
because its RPM signature is incompatible with RPM 6. Confirm that it remains
absent:

```bash
rpm --nosignature -q zoom
```

`package zoom is not installed` is expected. If it is installed, apply the
current playbook again before continuing. Do not restore Zoom until its RPM
passes RPM 6 signature validation and the repository installation tasks are
re-enabled.

Check enabled repositories:

```bash
dnf repolist
```

This host currently uses Fedora, Fedora Cisco OpenH264, RPM Fusion, the
Hyprland and Yazi COPRs, HashiCorp, 1Password, NodeSource, Google Chrome,
VS Code, Wayscriber, and virtio-win repositories. It does not use the Docker
repository.

The upgrade solver is the final compatibility check for third-party
repositories. Do not use `--allowerasing` merely to hide an unavailable
repository or unexplained dependency conflict.

## 4. Create backups and snapshots

Connect AC power and keep the laptop plugged in for the remainder of the
upgrade. Confirm that the battery is charging and sufficiently charged:

```bash
upower -i "$(upower -e | grep BAT | head -1)"
```

Back up irreplaceable data to another physical device or machine. Btrfs
snapshots on this host are stored on the same NVMe drive and do not protect
against drive failure.

The root Snapper snapshot does not include separate nested subvolumes,
including `/home`, `/opt`, `/var/lib/libvirt`, `/var/log`, and `/var/spool`.
In particular:

- ensure `/opt/homelab-automation` is committed and pushed
- back up important files in `/home`
- export VM definitions and back up irreplaceable VM disk images from
  `/var/lib/libvirt`
- back up credentials and local data not reproducible by Ansible

For each important libvirt VM, record its definition:

```bash
sudo virsh list --all
sudo virsh dumpxml VM_NAME > VM_NAME.xml
```

Store the XML and VM backups outside this NVMe filesystem.

Create a fresh managed `/home` snapshot:

```bash
sudo btrbk -c /etc/btrbk/btrbk.conf run
sudo btrbk list snapshots
```

Create a manual Snapper snapshot of the root subvolume and record its number:

```bash
sudo snapper -c root create \
    --description "Before Fedora 44 system upgrade" \
    --cleanup-algorithm number \
    --print-number
sudo snapper -c root list
```

The EFI system partition is not included in either snapshot. Back it up
separately:

```bash
sudo tar -C /boot/efi -czf /PATH/ON/EXTERNAL/BACKUP/x1carbon2018-efi-before-f44.tar.gz .
```

Replace the destination with a path on an external backup device or machine.

## 5. Stop automated DNF activity

Prevent Ansible and automated DNF jobs from changing package state or metadata
while the upgrade transaction is prepared:

```bash
sudo systemctl stop \
    ansible-pull.timer \
    dnf5-automatic.timer \
    dnf-makecache.timer
systemctl --user stop dnf-makecache.timer
```

Confirm that no associated service is running:

```bash
systemctl is-active \
    ansible-pull.service \
    dnf5-automatic.service \
    dnf-makecache.service
systemctl --user is-active dnf-makecache.service
```

`inactive` is expected. If any service is active, wait for it to finish before
continuing.

## 6. Download the Fedora 44 transaction

The DNF5 system-upgrade plugin is supplied by `dnf5-plugins`, which is already
installed on this host. Confirm the command is available:

```bash
dnf system-upgrade --help
```

Download and solve the Fedora 44 upgrade:

```bash
sudo dnf system-upgrade download --releasever=44
```

Review every proposed removal and replacement before accepting the
transaction. Pay particular attention to packages from the Hyprland and Yazi
COPRs and the other third-party repositories listed above.

If the solver fails:

1. Record the conflicting packages and repositories.
2. Disable only the third-party repository causing the problem, or remove the
   replaceable third-party package.
3. Run the download command again.
4. Use `--allowerasing` only after reviewing every package it proposes to
   remove.

Do not remove the bootloader, kernel, networking, Btrfs, desktop, libvirt, or
Ansible packages merely to make the transaction solve.

Inspect the prepared transaction:

```bash
sudo dnf system-upgrade status
```

## 7. Perform the offline upgrade

Close applications, disconnect unnecessary USB devices and docks, keep the
laptop lid open, and leave AC power connected. Start the offline transaction:

```bash
sudo dnf system-upgrade reboot
```

Do not suspend, close the lid, interrupt the upgrade, or disconnect power. The
machine will reboot into Fedora 44 when the transaction finishes.

## 8. Verify Fedora 44

Confirm that the upgrade and boot succeeded:

```bash
cat /etc/fedora-release
uname -r
sudo dnf system-upgrade log
sudo systemctl --failed
sudo journalctl -b -p warning --no-pager
```

Synchronize installed packages with the Fedora 44 repositories and verify
package health:

```bash
sudo dnf distro-sync --refresh
sudo dnf check
sudo rpm --verifydb
sudo rpm -qa >/dev/null
```

Run the complete host configuration:

```bash
cd /opt/homelab-automation
sudo h a test x1carbon2018.yml
```

Run it a second time to check idempotency:

```bash
sudo h a test x1carbon2018.yml
```

The second run should complete with `failed=0`. Investigate unexpected changes
that repeat on every run.

## 9. Verify x1carbon2018

Check the services and timers most likely to expose an upgrade regression:

```bash
systemctl is-active \
    tailscaled \
    systemd-resolved \
    wpa_supplicant \
    bluetooth \
    cups \
    avahi-daemon \
    libvirtd

systemctl status \
    ansible-pull.timer \
    dnf5-automatic.timer \
    dnf-makecache.timer \
    btrbk.timer

systemctl --user status dnf-makecache.timer
systemctl cat dnf5-automatic.timer
systemctl cat dnf5-automatic.service
```

Verify networking, DNS, and network-storage automounts:

```bash
resolvectl query mirrors.fedoraproject.org
resolvectl status
tailscale status
findmnt --mountpoint /srv/tier1
findmnt --mountpoint /srv/tier2
findmnt --mountpoint /source
```

Accessing the NFS paths may trigger their automounts. A storage server outage
should not block boot because these mounts are configured with `nofail`,
`noauto`, and finite mount timeouts.

Verify the graphical session and hardware:

```bash
systemctl get-default
loginctl session-status
lspci -k | grep -A3 -E 'VGA|Network'
```

Then manually test:

- Niri and Hyprland sessions
- Intel graphics acceleration and video playback
- Wi-Fi, Ethernet through the adapter or dock, Tailscale, and DNS
- audio, microphone, webcam, Bluetooth, trackpad, TrackPoint, and keyboard
- brightness keys, volume keys, and other special keys
- USB-C charging, battery status, docks, and external displays
- suspend and resume on both battery and AC power
- libvirt virtual machines and networking
- NFS and bind-mounted network storage
- 1Password, Firefox, Chrome, VS Code, and Wayscriber
- Neovim, Node.js, Codex, Claude Code, Antigravity, and other CLI tools

Check the latest Ansible and automated update logs:

```bash
journalctl -u ansible-pull.service -n 100 --no-pager
journalctl -u dnf5-automatic.service -n 100 --no-pager
journalctl -u dnf-makecache.service -n 100 --no-pager
journalctl --user -u dnf-makecache.service -n 100 --no-pager
```

## Nice-to-have cleanup

Perform these tasks only after Fedora 44, networking, suspend/resume, and the
desktop sessions are stable.

### Confirm legacy DNF Automatic drop-ins are absent

The current role removes obsolete alias-named overrides. Verify that they are
gone:

```bash
sudo test ! -e /etc/systemd/system/dnf-automatic.timer.d
sudo test ! -e /etc/systemd/system/dnf-automatic.service.d
```

Do not remove the `dnf-makecache.*` overrides.

### Review duplicate packages and dependency problems

```bash
sudo dnf repoquery --duplicates
sudo dnf check
```

Investigate duplicates before removing anything.

### Review configuration file replacements

```bash
sudo find /etc -xdev \( -name '*.rpmnew' -o -name '*.rpmsave' \) -print
```

Merge relevant changes into Ansible-managed templates or files instead of
editing generated configuration without updating this repository.

### Remove unused packages and old cached data

Review the proposed package removals before accepting:

```bash
sudo dnf autoremove
sudo dnf clean packages
```

### Remove old kernels only after successful boots

Keep at least one known-working Fedora 43 or early Fedora 44 kernel until the
new kernel, graphics, Wi-Fi, suspend/resume, and virtualization have been
tested. Let Fedora's normal kernel retention policy remove older kernels
afterward.
