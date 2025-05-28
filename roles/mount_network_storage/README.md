Role Name
=========

Mount network storage.

Requirements
------------

DNF, Become

A credentials file must be located in `/root/.smbcreds`. The file should have contents similar to the following:

```
username=usera
password=userapassword
```

`ansible.posix.mount` must be available.


Role Variables
--------------

`user_id`: The id of the user who will have write permissions to the shares

`group_id`: The id of the group who will have write permissions to the shares

`samba_mounts`: A list of dictionaries containing the keys: `server` and `share`

- `server`: The hostname or ip address of the server.
- `share`: The path of the share to mount.

```yml
user_id: 1000
group_id: 1000
samba_mounts:
  - server: odroidh3plus
    share: data
  - server: odroidh4
    share: backups
```

Dependencies
------------

None.

Example Playbook
----------------

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

License
-------

MIT

