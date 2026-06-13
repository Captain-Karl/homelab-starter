# Remote access with Tailscale

Most home internet connections are behind CGNAT, which means you don't have
a public IP address to forward ports to - even `Port forwarding` in your
router's settings won't help. [Tailscale](https://tailscale.com) creates a
private mesh network (a VPN) between your devices, so your phone or laptop
can reach your home server as if it were on the same LAN, from anywhere.

It's free for personal use (up to 100 devices) and doesn't require any router
configuration.

## Setup

1. **Install Tailscale on your server**

   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```

   This prints a login URL - open it in a browser and sign in (GitHub/Google/
   etc. all work).

2. **Install Tailscale on your phone/laptop**

   Get the app from your platform's app store, sign in with the same
   account.

3. **Find your server's Tailscale IP**

   ```bash
   tailscale ip -4
   ```

   It'll look like `100.x.x.x`. From any device on your tailnet, you can now
   reach your services at `http://100.x.x.x:<port>` - e.g.
   `http://100.x.x.x:7575` for Homarr.

## Optional: MagicDNS

Enable **MagicDNS** in the [Tailscale admin console](https://login.tailscale.com/admin/dns)
and your server gets a stable name like `myserver.tailnet-name.ts.net` -
no need to remember the IP.

## Combining with Traefik

If you've also set up the [Traefik reverse proxy](reverse-proxy-traefik.md),
you can bind Traefik's ports to your Tailscale IP only
(`TRAEFIK_BIND_ADDRESS=100.x.x.x` in `services/network/traefik/.env`) so your
`https://service.yourdomain.com` URLs work over Tailscale but aren't exposed
to the public internet at all - you get real certificates without opening any
ports on your router.
