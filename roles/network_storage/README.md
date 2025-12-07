# Network Storage

This role mounts network SMB/CIFS shares on a client machine. It is designed to work with shares secured by user-level permissions.

It ensures the local user and group configuration matches the server-side permissions for seamless access.

A credentials file must be located in `/root/.smbcreds`. The file should have contents similar to the following:

```
username=usera
password=userapassword
```
This user should be a member of the `networkshare` group on the server.

The `ansible.posix` collection must be available.


## Role Variables

`user`: The username of the local user who will own the files in the mounted shares. This should match the user defined in the playbook.

`uid`: The user ID of the local user.

`samba_mounts`: A list of dictionaries containing the keys: `server` and `share`.

- `server`: The hostname or ip address of the server.
- `share`: The path of the share to mount.

**Group Management Note:** This role automatically creates a `networkshare` group with a fixed GID (`5567`) and adds the `user` to it. The `gid` for the mount is handled by the `network_share_gid` variable from the role's defaults and does not need to be passed as a variable.

## Example Playbook

```yml
---
- name: Mount network storage
  hosts: desktop
  become: true

  vars:
    user: sean
    uid: 1000

  roles:
    - role: network_storage
      vars:
        samba_mounts:
          - server: odroidh3plus
            share: tier1
          - server: odroidh3plus
            share: tier2
```