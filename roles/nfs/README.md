# NFS Ansible Role

This role configures NFSv4 shares by managing the `/etc/exports` file via a template. It handles installing the necessary NFS utilities, managing the services, and configuring the necessary firewall rules.

Access control is managed via a combination of client IP addresses/subnets in the `/etc/exports` file and standard Unix file permissions on the filesystem.

## 1. Share Configuration

This role configures shares based on the `nfs_exports` variable defined in `defaults/main.yml`.

*   **IP-Based Access:** Client access is restricted to the hosts and subnets defined for each export (e.g., `192.168.0.0/16`).
*   **Permission Model:** Unlike Samba, NFS relies directly on Unix file permissions. This role creates the `network_share_group` and adds the `user` to it, but it **does not** manage the permissions of the exported directories themselves. The administrator is responsible for setting the ownership and permissions on the directories (e.g., `chown -R root:networkshare /srv/tier1` and `chmod -R 770 /srv/tier1`) to enforce group-based access.

## 2. How to Inspect the NFS Service

To ensure the NFS service is running correctly, you can use the following commands on the server.

### Check Service Status

Verify that the `nfs-server` and `rpcbind` services are active and running.

```bash
sudo systemctl status nfs-server.service rpcbind.service
```

### Review Service Logs

To see the detailed output from the NFS daemon, including any errors related to parsing `/etc/exports`, check its journal.

```bash
sudo journalctl -u nfs-server.service
```

### Verify Active Exports

The most important command is `exportfs`, which shows what the NFS server is actually exporting to which clients. This is the kernel's "source of truth".

```bash
# Show actively exported filesystems and their options
sudo exportfs -v
```

You can also view the raw configuration file that this role manages:
```bash
cat /etc/exports
```

### Check Firewall Rules

Ensure that the `nfs`, `rpc-bind`, and `mountd` services are allowed through the firewall.

```bash
sudo firewall-cmd --list-services
```
(Look for `nfs`, `rpc-bind`, and `mountd` in the output).

### Check Exports from a Client

From a client machine on the same network, you can use the `showmount` command to see what shares the server is advertising.

```bash
showmount -e <server_ip_or_hostname>
```