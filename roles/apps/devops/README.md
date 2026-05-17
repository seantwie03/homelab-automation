# DevOps

Install DevOps tools

- Terraform
- Vagrant
- AWS CLI

## AWS CLI Updates

AWS CLI v2 is installed with AWS's command-line installer and pinned by
`awscli_version` in `roles/apps/devops/defaults/main.yml`. To update AWS CLI,
change that version, run the role, and verify the installed version:

```sh
aws --version
```

The AWS CLI installer archive is downloaded from the versioned AWS x86_64 URL
and verified with the checked-in AWS CLI PGP key before installation. AWS
publishes available versions in the AWS CLI v2 changelog:

```text
https://github.com/aws/aws-cli/blob/v2/CHANGELOG.rst
```

If AWS rotates the AWS CLI PGP key, update `roles/apps/devops/files/aws-cli.asc`
from the key published in the AWS CLI install docs:

```text
https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/apps/devops/files/aws-cli.asc
```

Update the pinned fingerprint in `roles/apps/devops/tasks/awscli.yml`.

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
