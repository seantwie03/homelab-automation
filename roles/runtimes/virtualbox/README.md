# VirtualBox

Install [VirtualBox](https://www.virtualbox.org/wiki/Linux_Downloads) from Oracle. Add user specified in {{ user }} variable to vboxusers group.

The VirtualBox RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-virtualbox`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

## Signing Key Rotation

If Oracle rotates the VirtualBox RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://www.virtualbox.org/download/oracle_vbox_2016.asc \
    -o roles/runtimes/virtualbox/files/oracle_vbox_2016.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/runtimes/virtualbox/files/oracle_vbox_2016.asc
```

Update the `fingerprint` value in `roles/runtimes/virtualbox/tasks/main.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: B9F8 D658 297A F3EF C18D  5CDF A2F6 83C5 2980 AECF
```
