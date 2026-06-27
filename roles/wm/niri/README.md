# Niri

## Wayscriber Signing Key Rotation

The Wayscriber RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-wayscriber`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

If Wayscriber rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://wayscriber.com/rpm/RPM-GPG-KEY-wayscriber.asc \
    -o roles/wm/niri/files/wayscriber.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/wm/niri/files/wayscriber.asc
```

Update the `fingerprint` value in `roles/wm/niri/tasks/wayscriber.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 4489BCBB3CB130533709175F027B1C752E38957A
```

