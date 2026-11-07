# Tailscale

Configures Tailscale: enables `tailscaled.service`, and sets route acceptance,
exit-node advertising, and optional subnet routing, with IP forwarding when
the host advertises routes.

The `tailscale` package comes from the image, which installs it from the
Fedora repositories.

## First use

Authenticate the host once:

```sh
sudo tailscale up
```

## Role Variables

| Variable | Default | Meaning |
| --- | --- | --- |
| `tailscale_accept_routes` | `true` | Use subnet routes other nodes advertise. |
| `tailscale_advertise_exit_node` | `false` | Offer this host as an exit node. |
| `tailscale_subnet_routes` | `[]` | Subnets this host advertises; any enables IP forwarding. |

Advertised routes and exit nodes must also be approved in the Tailscale admin
console.
