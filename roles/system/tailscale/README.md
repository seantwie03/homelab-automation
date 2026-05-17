# Tailscale

Install [Tailscale](tailscale.com).

The Tailscale RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-tailscale`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

## Signing Key Rotation

If Tailscale rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://pkgs.tailscale.com/stable/fedora/repo.gpg \
    -o roles/system/tailscale/files/tailscale.gpg
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/system/tailscale/files/tailscale.gpg
```

Update the `fingerprint` value in `roles/system/tailscale/tasks/main.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 2596a99eaab33821893c0a79458ca832957f5868
```
