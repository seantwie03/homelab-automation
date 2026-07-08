# orbit Role - Monitoring

Orbit runs as the `sean` user through `systemd --user`.

```sh
systemctl --user status orbit.service
journalctl --user -u orbit.service -f
```

The service should listen on port `8787` and return a healthy API response when
called with the token from `~/.config/orbit/orbit.env`:

```sh
. ~/.config/orbit/orbit.env
curl -H "Authorization: Bearer $ORBIT_API_TOKEN" \
    http://127.0.0.1:8787/api/health
```

