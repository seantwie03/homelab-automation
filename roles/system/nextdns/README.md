# nextdns role

Configures DNS-over-TLS to NextDNS via `systemd-resolved`. NetworkManager's own DNS management is disabled so it does not overwrite the resolved configuration.

Key effects:
- All DNS queries are routed exclusively to NextDNS (`Domains=~.`)
- Queries are encrypted over TLS on port 853 (`DNSOverTLS=yes`)
- The `odh3p.3246.win` search domain is set so bare hostnames like `SERVICE` resolve to `SERVICE.odh3p.3246.win`

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
