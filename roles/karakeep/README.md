# Karakeep Ansible Role

This role deploys the [Karakeep](https://github.com/karakeep-app/karakeep) bookmarking application using Docker Compose.

## Dependencies

This role requires the `docker` role to be run first, as it depends on a working installation of Docker and the Docker Compose plugin. This dependency is handled automatically via the `meta/main.yml` file.

## Configuration

The role's behavior is configured through variables defined in `defaults/main.yml`.

### Secrets Management

This role requires a separate file containing sensitive environment variables. By default, it expects this file at `/root/karakeep/.env`. This path can be overridden with the `karakeep_secrets_file` variable.

The secrets file must contain the following variables:

```ini
MEILI_MASTER_KEY="a_very_strong_random_string"
NEXTAUTH_SECRET="another_very_strong_random_string"
# OPENAI_API_KEY="sk-..." # Optional
```

The role will fail if this file is not present.

### Infrastructure Configuration

-   `karakeep_install_dir`: The directory on the host where the `docker-compose.yml` file will be deployed. Defaults to `/opt/karakeep`.
-   `karakeep_data_root`: The base directory on the host where persistent application data will be stored. Defaults to `/srv/tier1/app_data/karakeep`.
-   `karakeep_port`: The external port on which the Karakeep web UI will be accessible.

## Verification

The application runs as a standard Docker Compose stack. To verify its operation, you can check the container logs.

1.  Navigate to the installation directory:
    ```sh
    cd /opt/karakeep
    ```

2.  View the logs for the main web application:
    ```sh
    docker compose logs -f web
    ```

A successful startup will show output from the Next.js server. If you encounter errors, the logs here will provide details on database migration issues or misconfigured environment variables.

## Backup

This role uses Docker **bind mounts** to store all persistent data in a predictable location on the host filesystem, making backups straightforward.

The following two directories contain all the data required to restore the application:

1.  **Karakeep Application Data:** Located at the path specified by `{{ karakeep_data_root }}/karakeep_data`. This contains the main SQLite database.
2.  **MeiliSearch Index:** Located at the path specified by `{{ karakeep_data_root }}/meilisearch_data`.

To perform a complete backup, simply archive these two directories. Restoring involves placing the directories back in the same location and re-running this Ansible role.
