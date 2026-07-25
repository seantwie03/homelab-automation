# cli Role - Monitoring

## Locate Database Timer

```sh
systemctl status plocate-updatedb.timer --no-pager
systemctl list-timers plocate-updatedb.timer --all
systemctl show plocate-updatedb.service -p Result -p ExecMainStatus
journalctl -u plocate-updatedb.service --since '8 days ago' --no-pager
```

The timer should be enabled and active, and its latest service result should be
successful. The oneshot service is normally inactive between runs.

## Database And Exclusions

```sh
ls -lh /var/lib/plocate/plocate.db
grep -E '^(PRUNEFS|PRUNEPATHS)' /etc/updatedb.conf
command -v updatedb
sed -n '1,120p' /usr/local/bin/updatedb
systemctl cat plocate-updatedb.service
locate .git | grep '/\.git/'
```

The database should exist. The Fedora-managed configuration should exclude
`/proc`. `/usr/local/bin/updatedb` should be selected for interactive commands,
and both it and the service should apply the directory names listed in
`plocate_prunenames`, the application and container-storage paths listed in
`plocate_prunepaths`, and bind-mount pruning. The final command should return no
paths beneath a `.git` directory; the `.git` directory itself remains indexed
by design.

These exclusions prevent indexing VCS, IDE, dependency, build, test-cache, and
container-storage directories; unnecessary traversal of Btrfs snapshots; and
SELinux denials from procfs. `/etc/updatedb.conf` is deliberately left
unmodified so RPM updates do not create `updatedb.conf.rpmnew` files.
