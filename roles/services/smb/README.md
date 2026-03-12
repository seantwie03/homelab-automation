# SMB Ansible Role

This role configures Samba (SMB) to provide secure, multi-user file shares. It handles installing the server, managing the services, setting up shares, and configuring the necessary firewall and SELinux rules.

The configuration is built around a standard user/group permission model rather than guest access.

## 1. Share Configuration

This role configures shares based on the `smb_shares` variable defined in `defaults/main.yml`. The security model is designed for collaboration among a trusted group of users.

*   **Group-Based Access:** Access is restricted to members of the `network_share_group` (`networkshare` by default) via the `valid users` parameter.
*   **Collaborative Permissions:** To prevent file permission issues between users, new files and directories have their group ownership forced to the `network_share_group` (`force group`), and permissions are standardized with `create mask` (0660) and `directory mask` (0770).
*   **Vetoed Directories:** The `veto files` parameter is used to hide specified directories from clients. This is configured with the `veto_dirs` list in a share's definition.
*   **SELinux:** The role automatically applies the `samba_share_t` context to the share paths, which is required for Samba to access them when SELinux is enforcing.

## 2. How to Inspect the Samba Service

To ensure the Samba service is running correctly, you can use the following commands.

### Check Service Status

Verify that the `smb` (main daemon) and `nmb` (NetBIOS name server) services are active and running.

```bash
sudo systemctl status smb.service nmb.service
```

### Review Service Logs

To see the detailed output from the Samba daemons, including connection attempts and errors, check their journals.

```bash
# Check the main SMB daemon logs
sudo journalctl -u smb.service

# Check the NetBIOS daemon logs
sudo journalctl -u nmb.service
```

### Validate Parsed Configuration

The `testparm` utility is the best way to verify that Samba is parsing the `/etc/samba/smb.conf` file correctly and to see a summary of the active settings.

```bash
# Validate the configuration file and print a summary
testparm -s
```

### Check Firewall Rules

Ensure that the `samba` service is allowed through the firewall.

```bash
sudo firewall-cmd --list-services
```
(Look for `samba` in the output).

### Check SELinux Contexts

Verify that the shared directories have the correct `samba_share_t` context, which is required for the `smbd` process to read and write to them.

```bash
# Check the contexts of the share directories themselves
ls -ldZ /srv/tier1 /srv/tier2

# Check the contexts of the files within a share
ls -lZ /srv/tier1
```

### List Samba Users

For a user to log in, they must have a password set in the Samba password database. This is a separate password from their Unix login password. You can list the users that have been added to Samba with this command.

```bash
sudo pdbedit -L
```

**Note:** This role does not manage Samba passwords. A user must be added manually with `sudo smbpasswd -a <username>`.