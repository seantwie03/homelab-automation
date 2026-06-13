# Upgrade desktop22 from Fedora 43 to Fedora 44

This procedure upgrades `desktop22` using Fedora's supported DNF5 offline
system-upgrade workflow.

References:

- [Fedora offline upgrade documentation](https://docs.fedoraproject.org/en-US/quick-docs/upgrading-fedora-offline/)
- [Fedora 44 common issues](https://fedoraproject.org/wiki/Common_F44_bugs)

## 1. Prepare this repository

Complete these changes before upgrading the host:

1. Change the DNF Automatic role to use the canonical
   `dnf5-automatic.timer` and `dnf5-automatic.service` names for its drop-in
   directories, enable/start task, and handler.
2. Keep `dnf-makecache.timer` and `dnf-makecache.service` unchanged. Those are
   still the canonical Fedora 44 unit names.
3. Run the repository lint:

   ```bash
   cd /opt/homelab-automation
   ansible-lint
   ```

4. Commit and push all intended repository changes. Do not upgrade with
   uncommitted configuration that `ansible-pull` cannot reproduce.
5. Apply the final Fedora 43 configuration and confirm that it succeeds:

   ```bash
   sudo h a test desktop22.yml
   ```

6. Confirm that the DNF5 Automatic schedule and service override are loaded:

   ```bash
   systemctl cat dnf5-automatic.timer
   systemctl cat dnf5-automatic.service
   systemctl status dnf5-automatic.timer
   ```

The output should include the repository-managed schedule and the Snapper
pre/post commands.

## 2. Review Fedora 44 issues

Immediately before the upgrade, review the
[Fedora 44 common issues](https://fedoraproject.org/wiki/Common_F44_bugs) page.
Pay particular attention to graphics, boot, Btrfs, networking, Hyprland, Niri,
Docker, and virtualization issues.

## 3. Update and verify Fedora 43

Install all Fedora 43 updates and reboot into the latest kernel:

```bash
sudo dnf upgrade --refresh
sudo reboot
```

After rebooting, verify the release, kernel, free space, and Btrfs health:

```bash
cat /etc/fedora-release
uname -r
df -h / /boot /boot/efi
sudo btrfs filesystem usage /
sudo btrfs scrub status /
```

The root filesystem currently has ample space, but recheck it immediately
before upgrading. Resolve any Btrfs errors before continuing.

Verify the RPM database and installed package dependencies:

```bash
sudo rpm --verifydb
sudo rpm -qa >/dev/null
sudo dnf check
```

On this host, enumerating the RPM database currently reports a bad signature
on the installed Zoom package. If `rpm -qa` still produces that error, remove
Zoom before the upgrade:

```bash
sudo rpm -e --nosignature zoom
sudo rpm --verifydb
sudo rpm -qa >/dev/null
```

The `gui` role will reinstall the configured Zoom version when Ansible is run
after the upgrade. Do not continue until both RPM checks complete without an
RPM database error.

Check enabled repositories:

```bash
dnf repolist
```

`desktop22` uses Fedora, RPM Fusion, Docker, HashiCorp, 1Password, Tailscale,
NodeSource, Google Chrome, VS Code, Wayscriber, and virtio-win repositories.
The upgrade solver is the final compatibility check for these repositories.
Do not use `--allowerasing` merely to hide an unavailable third-party
repository or an unexplained dependency conflict.

## 4. Create backups and snapshots

Confirm that important files outside `/home` are backed up. In particular,
copy any irreplaceable configuration, credentials, VM definitions, and local
container data to another filesystem or machine.

Create a fresh managed `/home` snapshot:

```bash
sudo btrbk -c /etc/btrbk/btrbk.conf run
sudo btrbk list snapshots
```

Create a manual Snapper snapshot of the root filesystem and record its number:

```bash
sudo snapper -c root create \
    --description "Before Fedora 44 system upgrade" \
    --cleanup-algorithm number \
    --print-number
sudo snapper -c root list
```

Snapshots are not substitutes for an external backup. The EFI system
partition and all data outside the snapshotted subvolumes require separate
recovery coverage.

## 5. Stop automated package activity

Prevent `ansible-pull` and DNF Automatic from modifying packages while the
upgrade transaction is prepared:

```bash
sudo systemctl stop ansible-pull.timer
sudo systemctl stop dnf5-automatic.timer
```

Confirm that neither service is running:

```bash
systemctl is-active ansible-pull.service dnf5-automatic.service
```

`inactive` is expected.

## 6. Download the Fedora 44 transaction

The DNF5 system-upgrade plugin is provided by `dnf5-plugins`, which is already
installed on this host. Confirm the command is available:

```bash
dnf system-upgrade --help
```

Download and solve the Fedora 44 upgrade:

```bash
sudo dnf system-upgrade download --releasever=44
```

Review the proposed removals and replacements before accepting the
transaction. If the solver fails:

1. Record the conflicting packages and repositories.
2. Disable only the third-party repository causing the problem, or remove the
   replaceable third-party package.
3. Run the download command again.
4. Use `--allowerasing` only after reviewing every package it proposes to
   remove.

Do not remove core desktop, bootloader, networking, filesystem, or Ansible
packages just to make the transaction solve.

Inspect the prepared transaction:

```bash
sudo dnf system-upgrade status
```

## 7. Perform the offline upgrade

Close applications and make sure the machine has reliable power and network
connectivity. Start the offline transaction:

```bash
sudo dnf system-upgrade reboot
```

Do not interrupt the upgrade or power off the machine. It will reboot into
Fedora 44 when the transaction finishes.

## 8. Verify Fedora 44

Confirm that the upgrade and boot succeeded:

```bash
cat /etc/fedora-release
uname -r
sudo dnf system-upgrade log
sudo systemctl --failed
sudo journalctl -b -p warning
```

Synchronize installed packages with the Fedora 44 repositories and verify
package health:

```bash
sudo dnf distro-sync --refresh
sudo dnf check
sudo rpm --verifydb
```

Run the complete host configuration:

```bash
cd /opt/homelab-automation
sudo h a test desktop22.yml
```

Run it a second time to check idempotency:

```bash
sudo h a test desktop22.yml
```

The second run should complete with `failed=0`; investigate unexpected changes
that repeat on every run.

## 9. Verify desktop22 services

Check the services and timers most likely to expose an upgrade regression:

```bash
systemctl is-active \
    docker \
    tailscaled \
    systemd-resolved \
    wpa_supplicant \
    cups \
    avahi-daemon \
    libvirtd

systemctl status \
    ansible-pull.timer \
    dnf5-automatic.timer \
    dnf-makecache.timer \
    btrbk.timer

systemctl cat dnf5-automatic.timer
systemctl cat dnf5-automatic.service
```

Verify networking and DNS:

```bash
resolvectl query mirrors.fedoraproject.org
resolvectl status
tailscale status
```

Verify the graphical session and hardware:

```bash
systemctl get-default
loginctl session-status
```

Then manually test:

- Niri and Hyprland sessions
- Audio, Bluetooth, Wi-Fi, suspend, resume, and display outputs
- NVIDIA or other GPU acceleration, if applicable
- Docker containers
- libvirt virtual machines and networking
- 1Password, browsers, VS Code, Zoom, and gaming applications
- Neovim, Node.js, Codex, Claude Code, Antigravity, and other CLI tools

Check the latest Ansible run and automated update logs:

```bash
journalctl -u ansible-pull.service -n 100 --no-pager
journalctl -u dnf5-automatic.service -n 100 --no-pager
journalctl -u dnf-makecache.service -n 100 --no-pager
```

## Nice-to-have cleanup

These tasks are not required to complete the upgrade. Perform them only after
Fedora 44 and the desktop environment are stable.

### Replace deprecated DNS query commands

Replace `systemd-resolve` with `resolvectl query` in:

- `roles/system/nextdns/files/wait-dns-online.sh`
- `roles/system/dnf/files/dnf-makecache-user.service`

Fedora 44 still provides the compatibility command, so this is preventive
maintenance rather than an upgrade blocker.

### Remove old DNF Automatic drop-ins

After the role has migrated to canonical `dnf5-automatic` names and has run
successfully, remove obsolete alias-named overrides if they remain:

```bash
sudo rm -rf \
    /etc/systemd/system/dnf-automatic.timer.d \
    /etc/systemd/system/dnf-automatic.service.d
sudo systemctl daemon-reload
```

Do not remove the `dnf-makecache.*` overrides.

### Remove retired Fedora 43 packages

Install Fedora's retired-package utility and remove packages retired between
Fedora 43 and Fedora 44:

```bash
sudo dnf install remove-retired-packages
sudo remove-retired-packages 43
```

Review the proposed removals before confirming.

### Review duplicate and unsatisfied packages

```bash
sudo dnf repoquery --duplicates
sudo dnf repoquery --unsatisfied
sudo dnf check
```

Investigate duplicates before removing anything.

### Review configuration file replacements

```bash
sudo find /etc -xdev \( -name '*.rpmnew' -o -name '*.rpmsave' \) -print
```

Merge relevant changes into the Ansible-managed templates or files instead of
editing generated configuration without updating this repository.

### Remove unused packages and old cached data

Review before accepting:

```bash
sudo dnf autoremove
sudo dnf clean packages
```

### Remove old kernels only after successful boots

Keep at least one known-working Fedora 43 or early Fedora 44 kernel until the
new kernel, graphics stack, networking, suspend, and virtualization have been
tested. Let the normal Fedora kernel retention policy remove older kernels
afterward.
