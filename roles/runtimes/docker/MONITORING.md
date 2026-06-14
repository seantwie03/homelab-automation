# docker Role - Monitoring

## Daemon

```sh
systemctl is-enabled docker.service
systemctl is-active docker.service
docker info
```

The service should be enabled and active. `docker info` should connect without
errors for a user in the `docker` group.

## Containers

```sh
docker ps --all
docker ps --filter status=exited
docker ps --filter health=unhealthy
```

Investigate unexpected exited, restarting, dead, or unhealthy containers.
Containers intentionally stopped by the administrator are not daemon failures.

## Storage And Logs

```sh
docker system df
journalctl -u docker.service -b -p warning --no-pager
```

Large image, build-cache, volume, or log usage should be reported before
cleanup. Do not prune Docker data without explicit approval.

If the daemon fails after a kernel, firewall, or package update, inspect the
full service status and journal before changing Docker configuration.

