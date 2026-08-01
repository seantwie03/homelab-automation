# Node.js

Install [Node.js](https://nodejs.org/en), [npm](https://www.npmjs.com/),
[pnpm](https://pnpm.io/), and [Bun](https://bun.sh/).

## Role Variables

`node_version`: The Node.js release series to install from NodeSource. Example
`24.x`

`bun_version`: The exact Bun version to install. Example `1.3.14`

The role removes an installed Node.js 22.x package before installing Node.js
from the configured NodeSource release series. It does not upgrade an existing
24.x installation; regular system package updates manage subsequent releases.

The NodeSource RPM signing key is checked into this role and deployed to `/etc/pki/rpm-gpg/RPM-GPG-KEY-nodesource`.
The DNF repository uses that local key file instead of the upstream key URL so unattended updates cannot automatically trust a rotated remote key.

## Signing Key Rotation

If NodeSource rotates its RPM signing key, package updates may fail until this role is updated.
This is intentional: the playbook pins the trusted key fingerprint, and DNF is configured to use only the local key file managed by this repo.

To update the trusted key:

```sh
curl -fsSL \
    https://rpm.nodesource.com/gpgkey/ns-operations-public.key \
    -o roles/runtimes/nodejs/files/nodesource.asc
```

Inspect the new fingerprint:

```sh
gpg --show-keys --with-fingerprint roles/runtimes/nodejs/files/nodesource.asc
```

Update the `fingerprint` value in `roles/runtimes/nodejs/tasks/main.yml` to match the new key.
Use the full fingerprint with no spaces, for example:

```yaml
fingerprint: 242b813831af09562b6c46f76b88da4e3af28a14
```
