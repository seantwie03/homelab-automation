# nextdns role

Configures DNS-over-TLS to NextDNS via `systemd-resolved`. NetworkManager's own DNS management is disabled so it does not overwrite the resolved configuration.

Key effects:
- All DNS queries are routed exclusively to NextDNS (`Domains=~.`)
- Queries are encrypted over TLS on port 853 (`DNSOverTLS=yes`)
- The `odh3p.3246.win` search domain is set so bare hostnames like `SERVICE` resolve to `SERVICE.odh3p.3246.win`
- The DNS servers each network hands out use plain DNS (see [Per-Network DNS Servers](#per-network-dns-servers))

## Per-Network DNS Servers

`/etc/NetworkManager/conf.d/dns-over-tls.conf` sets `connection.dns-over-tls=0`, so the DNS servers that each network hands out over DHCP use plain DNS. The NextDNS servers in `nextdns.conf` still use DNS-over-TLS, because resolved applies only the global `DNSOverTLS=` setting to them.

Without this file, per-network servers inherit the global `DNSOverTLS=yes`. NetworkManager's connectivity check looks up its probe host through the checked network's own DNS servers, and most networks' servers, such as a phone hotspot's, refuse DNS-over-TLS. The check then fails on Wi-Fi. If the wired link is also up but its ISP is down, both links fail the check and get the same route-metric penalty, so the wired link keeps the default route and every NextDNS query leaves through the dead link.

Because of `Domains=~.`, per-network servers receive only lookups that a program ties to one interface, in practice the connectivity check, and names under a search domain the network hands out. Those lookups are unencrypted, so the network can read and forge them. Resolved sends each lookup to the most specific matching domain, so a hostile network that hands out a broad search domain such as `com` would receive every `.com` lookup in plain text.

## Captive Portals (Hotels, Coffee Shops, etc.)

This setup breaks captive portal authentication because:

1. The hotel firewall blocks port 853 until you authenticate, so `DNSOverTLS=yes` causes all DNS to fail immediately.
2. `Domains=~.` routes every query to NextDNS, ignoring the DHCP-provided hotel DNS entirely.
3. With DNS broken, even the captive portal login page is unreachable by hostname.

### Step 1 — Try HTTP to a bare IP first

Open a browser and navigate to `http://1.1.1.1`. Many captive portals intercept all outbound port 80 traffic regardless of destination and redirect to the login page. If the portal appears, authenticate and you're done.

### Step 2 — If that fails, use the toggle script

```bash
sudo dns_over_tls_toggle.sh
```

This moves the resolved override aside and restarts resolved, dropping it back to the DHCP-provided hotel DNS (NM still passes per-link DNS to resolved via DBus even with `dns=none`). Navigate to any HTTP site to trigger the portal redirect, then authenticate.

Run the script again to restore NextDNS:

```bash
sudo dns_over_tls_toggle.sh
```
