# Network Storage

This role mounts remote NFS shares and configures local bind mounts on a client machine.
All mounts use `x-systemd.automount` and `nofail` so that an unreachable server never blocks boot.

The `ansible.posix` collection must be available.

## Role Variables

`user`: The username of the local user who will own the files in the mounted shares.

`network_share_group` / `network_share_gid`: Group name and GID created on the client to match server-side share permissions. The `user` is added to this group automatically.

`nfs_mounts`: List of NFS shares to automount. Each entry requires:
- `server`: Hostname or IP of the NFS server.
- `path`: Absolute path of the export on the server (also used as the local mount point).

`bind_mounts`: List of local bind mounts to automount. Each entry requires:
- `src`: Source directory to expose at a second path.
- `path`: Local mount point.

`samba_mounts` *(disabled)*: List of CIFS shares. Currently commented out. Each entry requires `server` and `share`.

## Example Playbook

```yml
---
- name: Mount network storage
  hosts: desktops
  become: true

  vars:
    user: sean
    uid: 1000

  roles:
    - role: network_storage
      vars:
        nfs_mounts:
          - server: odroidh3plus
            path: /srv/tier1
          - server: odroidh3plus
            path: /srv/tier2
          - server: odroidh3plus
            path: /source
        bind_mounts:
          - src: /srv/tier1/docs
            path: /home/sean/u
```
