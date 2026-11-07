# tailscale Role - Monitoring

## Service And Peer State

Tailscale is on-demand. Most hosts do not run it all the time; the user turns
it on and off as needed. A host with Tailscale off is normal. Do not report it
as a finding or follow-up, and do not recommend `tailscale up`. No action is
required when it is off.

```sh
systemctl is-active tailscaled.service
tailscale status
tailscale ip
```

Expected:

- `tailscaled.service` is active. The daemon keeps running while the node is
  off.
- `tailscale status` reports either `Tailscale is stopped.` (off) or lists the
  host and its peers (on). The off state matches `WantRunning: false` in
  `tailscale debug prefs`.
- When on, the local host is authenticated and appears in `tailscale status`,
  and at least currently available peers have a plausible direct or relay path.

An offline peer is not a local failure by itself.

## Configured Routing

Read the role variables in the host playbook, then inspect the effective state:

```sh
tailscale debug prefs
```

Confirm that route acceptance, advertised subnet routes, and exit-node
advertising match:

- `tailscale_accept_routes`
- `tailscale_subnet_routes`
- `tailscale_advertise_exit_node`

Advertised routes and exit nodes must also be approved in the Tailscale admin
console. A locally advertised but unapproved route is not usable.

When subnet routes are configured, verify forwarding:

```sh
sysctl net.ipv4.ip_forward
sysctl net.ipv6.conf.all.forwarding
```

Both values should be `1`.

## DNS And Connectivity

Run these checks only while Tailscale is on. Skip them when `tailscale status`
reports `Tailscale is stopped.`

```sh
resolvectl status tailscale0
tailscale ping odroidh3plus
journalctl -u tailscaled.service -b -p warning --no-pager
```

Use a peer expected to be online for `tailscale ping`. Confirm that Tailscale
split-DNS domains are attached to `tailscale0` without replacing the host's
default NextDNS route.

