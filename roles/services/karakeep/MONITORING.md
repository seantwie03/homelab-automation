# karakeep Role - Monitoring

## Compose Stack

Read the role defaults and host variables for the install directory, port, URL,
and data paths.

```sh
docker compose -f /opt/karakeep/docker-compose.yml ps
docker compose -f /opt/karakeep/docker-compose.yml config --quiet
```

Expected:

- `web`, `meilisearch`, and `chrome` are running.
- No container is repeatedly restarting.
- The Compose configuration parses successfully.

## Application

```sh
curl --fail --silent --show-error http://localhost:8910/ >/dev/null
docker compose -f /opt/karakeep/docker-compose.yml logs \
    --since 24h --tail 200
```

Use `karakeep_port` when it differs from the default. Investigate HTTP errors,
database migration failures, authentication errors, Meilisearch failures, and
browser connection failures.

## Persistent Data

```sh
du -sh /srv/tier1/app_data/karakeep/*
df -h /srv/tier1/app_data/karakeep
```

Use `karakeep_data_root` when overridden. Both `karakeep_data` and
`meilisearch_data` should exist on persistent storage. Unexpected growth,
missing directories, or low free space requires follow-up.

Do not display or copy the secrets file contents during routine monitoring.

