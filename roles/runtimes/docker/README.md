# Docker

Installs Docker CE packages from the Docker RPM repository and enables the Docker service.

The Docker RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-docker`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

## Signing Key Rotation

If Docker rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://download.docker.com/linux/fedora/gpg \
    -o roles/runtimes/docker/files/docker.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/runtimes/docker/files/docker.asc
```

Update the `fingerprint` value in `roles/runtimes/docker/tasks/main.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 060A 61C5 1B55 8A7F 742B 77AA C52F EB6B 621E 9F35
```
