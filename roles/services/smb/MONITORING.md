# smb Role - Monitoring

## Services And Configuration

```sh
systemctl is-active smb.service nmb.service
testparm -s
```

Both services should be active and `testparm` should parse the deployed
configuration without errors. Compare the listed shares with `smb_shares` in
the role configuration.

## Shares And Users

```sh
smbclient -L localhost -N
sudo pdbedit -L
```

Share listing may require credentials when guest access is disabled. Confirm
that required Samba users exist; this role intentionally does not manage their
passwords.

## Firewall And SELinux

```sh
sudo firewall-cmd --list-services
ls -ldZ /srv/tier1 /srv/tier2
```

Use the configured share paths. The firewall should allow `samba`, and shared
directories should have the `samba_share_t` SELinux type.

```sh
journalctl -u smb.service -u nmb.service -b -p warning --no-pager
```

Investigate authentication, Unix permission, SELinux denial, path, and
configuration errors separately.

