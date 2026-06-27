# Podman

Installs Podman and enables the system `podman-auto-update.timer`.

This role provides the container runtime used by Podman-managed services and
keeps labeled containers updated through Podman's native auto-update mechanism.
The auto-update service is a systemd oneshot and is normally inactive between
timer runs.

See `MONITORING.md` for timer, container, and dry-run checks.

