# Network Storage

Mount network storage.

A credentials file must be located in `/root/.smbcreds`. The file should have contents similar to the following:

```
username=usera
password=userapassword
```

The `ansible.posix` collection must be available.


## Role Variables

`uid`: The id of the user who will have write permissions to the shares

`gid`: The id of the group who will have write permissions to the shares

`samba_mounts`: A list of dictionaries containing the keys: `server` and `share`

- `server`: The hostname or ip address of the server.
- `share`: The path of the share to mount.

## Example Playbook

```yml
---
- name: Mount network storage
  hosts: desktop
  become: true
  roles:
    - role: mount_network_storage
      vars:
        samba_mounts:
          - server: odroidh3plus
            share: data
          - server: odroidh4
            share: backups
```

