# GUI

Install graphical software packages. These are packages that I would install on ANY graphical fedora system regardless of Desktop Environment or Window Manager.

## Emacs

Emacs is provided by the `emacs` role dependency.

## Google Chrome Signing Key Rotation

The Google Linux RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-google`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

If Google rotates its Linux RPM signing key, Chrome package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://dl.google.com/linux/linux_signing_key.pub \
    -o roles/apps/gui/files/google_linux_signing_key.pub
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/apps/gui/files/google_linux_signing_key.pub
```

Update the `fingerprint` value in `roles/apps/gui/tasks/google_chrome.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: eb4c1bfd4f042f6dddccec917721f63bd38b4796
```

## VS Code Signing Key Rotation

The Microsoft RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-microsoft`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

If Microsoft rotates its RPM signing key, VS Code package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://packages.microsoft.com/keys/microsoft.asc \
    -o roles/apps/gui/files/microsoft.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/apps/gui/files/microsoft.asc
```

Update the `fingerprint` value in `roles/apps/gui/tasks/vscode.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: bc528686b50d79e339d3721ceb3e94adbe1229cf
```

## Zoom Updates

Zoom is installed from an official, versioned remote RPM URL. The version and
SHA-256 checksum are pinned by `zoom_version` and `zoom_checksum` in
`roles/apps/gui/defaults/main.yml`.

The role queries the installed Zoom RPM version with signature verification
disabled before doing any network work. If the installed Zoom version matches
`zoom_version`, both the download and installation tasks are skipped.

RPM 6 rejects Zoom's current package signature because the upstream key is not
marked as signing capable. Both the Ansible DNF and package_facts modules ask
RPM 6 to validate the rejected header, so the role invokes RPM directly with
signature and digest checks disabled for both version queries and installation.
It also bypasses RPM's incorrect Btrfs free-space result; DNF still resolves and
reports the package's requirements during troubleshooting. The pinned SHA-256
checksum prevents installation if the downloaded file differs from the reviewed
artifact.

To update Zoom, find the latest RPM version:

```sh
cd ~/Downloads
rm zoom_x86_64.rpm 2>/dev/null
wget https://zoom.us/client/latest/zoom_x86_64.rpm
rpm -qp --nosignature --nodigest ./zoom_x86_64.rpm
sha256sum ./zoom_x86_64.rpm
```

Use the RPM version without the release suffix as `zoom_version`, and update
`zoom_checksum` with the SHA-256 output. For example:

```yaml
zoom_version: 7.1.5.4332
zoom_checksum: sha256:92f82ac8f83c675bddfe5ea4a563c773b1d6bc95519c27f432c5557fec630b28
```

## JetBrains Toolbox

The playbook downloads and extracts the Toolbox installer into
`~/.local/share/JetBrains/Toolbox/Installer/` but does not launch it. After
running the playbook, start the app once manually to complete installation:

```sh
~/.local/share/JetBrains/Toolbox/Installer/jetbrains-toolbox-<version>/bin/jetbrains-toolbox
```

This creates the desktop entry and sets up `~/.local/share/JetBrains/Toolbox`.

## tldraw Offline Updates

tldraw offline is installed from its upstream x86_64 AppImage. The release
version and SHA-256 checksum are pinned in `roles/apps/gui/defaults/main.yml`.

To update it, obtain the version and checksum for
`tldraw-offline-linux-x86_64.AppImage` from the
[upstream release](https://github.com/tldraw/tldraw-offline/releases), then
update both `tldraw_offline_version` and `tldraw_offline_checksum`.

## Mouse Configuration

Logitech mice are configured with Solaar, which replaced Piper. Piper's libratbag backend cannot write a button binding that is only a modifier key, such as a held Alt or Ctrl, to a HID++ 2.0 onboard profile: it puts the modifier's HID usage in the key byte instead of the modifier byte, and the mouse sends nothing. Upstream tracks this in [libratbag#710](https://github.com/libratbag/libratbag/issues/710) and [libratbag#1906](https://github.com/libratbag/libratbag/issues/1906).

The `solaar` package pulls in `solaar-udev`, whose udev rule grants the logged-in user access to Logitech hidraw devices, so no step needs root. Replug the mouse after the first install so the rule applies. The package also installs an XDG autostart entry that would start Solaar in the system tray at login. The role hides it with a `Hidden=true` override in `~/.config/autostart/solaar.desktop`, because the mice keep their onboard profiles without Solaar running. Open Solaar from the application launcher to change a profile.

The onboard profiles for both G502 mice are kept in `dotfiles/solaar/g502-profiles.yaml`. To apply the file to a mouse, connect only that mouse and run:

```sh
solaar profiles G502 /opt/homelab-automation/dotfiles/solaar/g502-profiles.yaml
```

Solaar writes only the sectors that differ, so running it on a mouse that already matches writes nothing. After changing a mouse with the Solaar GUI, save its profiles back to the file, commit them, and apply them to the other mouse:

```sh
solaar profiles G502 > /opt/homelab-automation/dotfiles/solaar/g502-profiles.yaml
```

A button bound to only a modifier uses `type: 2` with the modifier bits in `modifiers` (1 Ctrl, 2 Shift, 4 Alt, 8 Meta) and `value: 0`, for example `!Button {behavior: 8, modifiers: 4, type: 2, value: 0}` for a held Left Alt.
