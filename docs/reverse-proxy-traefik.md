# Reverse proxy & HTTPS with Traefik

By default every service in this repo is reachable at
`http://<server-ip>:<port>`. That's fine to get started, but it means:

- No HTTPS (browsers will warn you, and some apps/PWAs require HTTPS)
- You have to remember a different port for every service

Traefik fixes both: each service gets a friendly subdomain
(`https://mealie.yourdomain.com`) with a real, auto-renewing certificate from
Let's Encrypt.

## What you need

1. **A domain name** - any registrar works (Cloudflare, Porkbun, Namecheap...).
2. **Cloudflare as your DNS provider** for that domain (free). Traefik proves
   you own the domain by creating a temporary DNS TXT record via the
   Cloudflare API - this is the "DNS-01 challenge", and it works even if your
   server has no public IP (great when combined with
   [Tailscale](remote-access-tailscale.md)).
3. **A Cloudflare API token** with `Zone:DNS:Edit` permission for your
   domain: https://dash.cloudflare.com/profile/api-tokens -> "Create Token" ->
   "Edit zone DNS" template, scoped to your zone.
4. In Cloudflare DNS, add a wildcard `A` record `*.yourdomain.com` pointing at
   your server's IP (or your Tailscale IP, if you're keeping things private -
   see below). The record can be "DNS only" (grey cloud) - Traefik handles
   TLS itself.

## How it works here

`install.sh` asks for your domain, email, and Cloudflare token, then:

- Writes `services/network/traefik/traefik.yml` from a template with your
  domain/email filled in.
- Writes `services/network/traefik/.env` with your Cloudflare token.
- Creates the `traefik_proxy` and `socket_proxy` Docker networks.
- Brings up Traefik (+ a locked-down `socket-proxy` that mediates Docker API
  access, so Traefik never touches `/var/run/docker.sock` directly).
- For each service you select, also applies its `compose.traefik.yml`
  overlay, which adds the Traefik routing labels and a
  `<service>.yourdomain.com` hostname.

## Keeping it private (recommended)

If you don't want these services reachable from the public internet at all,
combine this with [Tailscale](remote-access-tailscale.md):

- Point your wildcard DNS record at your **Tailscale IP** instead of a public
  IP, and/or
- Set `TRAEFIK_BIND_ADDRESS=100.x.x.x` (your Tailscale IP) in
  `services/network/traefik/.env` so Traefik's ports 80/443 only listen on
  the Tailscale interface.

You still get real, valid HTTPS certificates (DNS-01 doesn't require Traefik
to be publicly reachable), but the services are only accessible to devices on
your tailnet.

## Dashboard & extra middlewares

The Traefik dashboard is disabled by default. `services/network/traefik/dynamic.yml`
has commented-out examples for:

- **dashboard-auth** - basic-auth protected Traefik dashboard
- **tailscale-only** - an IP allowlist middleware restricting any router to
  Tailscale clients only
- **secure-headers** - a ready-to-use security headers middleware

Uncomment and adjust as needed, then add the middleware name to a service's
`traefik.http.routers.<name>.middlewares` label.

## Troubleshooting

- `docker compose logs traefik` (from `services/network/traefik/`) is your
  first stop - cert issuance failures show up there.
- Start with the Let's Encrypt **staging** server (uncomment `caServer` in
  `traefik.yml.template` before running `install.sh`) - production rate-limits
  to 5 duplicate certs/week, easy to hit while debugging.
