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

Zoom is installed from a versioned remote RPM URL and pinned by `zoom_version`
in `roles/apps/gui/defaults/main.yml`. The role checks the installed RPM version
before installing, so the remote package is only downloaded when Zoom is missing
or the installed version differs from `zoom_version`.

To update Zoom, find the latest RPM version:

```sh
cd ~/Downloads
rm zoom_x86_64.rpm 2>/dev/null
wget https://zoom.us/client/latest/zoom_x86_64.rpm
rpm -qp ./zoom_x86_64.rpm
```

Use the RPM version without the release suffix as `zoom_version`. For example,
if `rpm -qp` returns `zoom-6.7.5.6891-1.x86_64`, use:

```yaml
zoom_version: 6.7.5.6891
```

## JetBrains Toolbox

The playbook downloads and extracts the Toolbox installer into
`~/.local/share/JetBrains/Toolbox/Installer/` but does not launch it. After
running the playbook, start the app once manually to complete installation:

```sh
~/.local/share/JetBrains/Toolbox/Installer/jetbrains-toolbox-<version>/bin/jetbrains-toolbox
```

This creates the desktop entry and sets up `~/.local/share/JetBrains/Toolbox`.
