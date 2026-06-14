# tailscale Role - Monitoring

## Service And Peer State

```sh
systemctl is-active tailscaled.service
tailscale status
tailscale ip
```

Expected:

- `tailscaled.service` is active.
- The local host is authenticated and appears in `tailscale status`.
- At least currently available peers have a plausible direct or relay path.

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

```sh
resolvectl status tailscale0
tailscale ping odroidh3plus
journalctl -u tailscaled.service -b -p warning --no-pager
```

Use a peer expected to be online for `tailscale ping`. Confirm that Tailscale
split-DNS domains are attached to `tailscale0` without replacing the host's
default NextDNS route.

