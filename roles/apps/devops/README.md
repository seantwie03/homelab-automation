# DevOps

Install DevOps tools

- Terraform
- Vagrant
- AWS CLI

## Signing Key Rotation

The HashiCorp RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-hashicorp`. The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

If HashiCorp rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://rpm.releases.hashicorp.com/gpg \
    -o roles/apps/devops/files/hashicorp.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/apps/devops/files/hashicorp.asc
```

Update the `fingerprint` value in `roles/apps/devops/tasks/hashicorp.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 798aec654e5c15428c8e42eeaa16fcbca621e701
```
