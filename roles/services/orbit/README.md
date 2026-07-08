# orbit

Runs Orbit as a `systemd --user` service for `sean` on `odroidh3plus`.

The role installs the vendored Orbit backend from `roles/services/orbit/files`,
renders the machine-local startup file at `~/.config/orbit/orbit-start.el`, and
enables `orbit.service` in the user's systemd manager. The service reads all
`.org` files under `/srv/tier1/docs/org`.

The API token lives in `~/.config/orbit/orbit.env`. The role creates this file
with a random token on first run and does not overwrite it afterward.

## Health Check

```sh
. ~/.config/orbit/orbit.env
curl -H "Authorization: Bearer $ORBIT_API_TOKEN" \
    http://127.0.0.1:8787/api/health
```

