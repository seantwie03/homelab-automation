# 1Password (OnePassword)

Installs [1Password CLI](https://developer.1password.com/docs/cli/get-started/).

Installs [1Password GUI](https://support.1password.com/install-linux/#fedora-or-red-hat-enterprise-linux) when ran on graphical systems.

Autostarts 1Password GUI when user specified in `user` variable logs in.

The 1Password RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-1password`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

## Signing Key Rotation

If 1Password rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://downloads.1password.com/linux/keys/1password.asc \
    -o roles/apps/onepassword/files/1password.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/apps/onepassword/files/1password.asc
```

Update the `fingerprint` value in `roles/apps/onepassword/tasks/main.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 3fef9748469adbe15da7ca80ac2d62742012ea22
```
