# autologin

Configures agetty to automatically log in a user on tty1 at boot via a systemd drop-in on `getty@tty1.service`. No display manager required.

## Prerequisites

**The user must already exist** before this role runs. The role asserts this at the start and fails fast if the user is absent. This is the same implicit contract all roles in this repo share — `{{ user }}` is always assumed to be a pre-existing account with a home directory.

## Variables

| Variable | Default | Description |
|---|---|---|
| `user` | `sean` | User to auto-login on tty1. |
