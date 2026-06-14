# homelab-starter

![License: MIT](https://img.shields.io/badge/license-MIT-blue)
![Docker Compose](https://img.shields.io/badge/docker-compose-2496ED?logo=docker&logoColor=white)
![Shell](https://img.shields.io/badge/installer-bash-4EAA25?logo=gnubash&logoColor=white)

A pick-and-choose collection of `docker compose` stacks for popular self-hosted
apps, plus an interactive installer so you can spin up exactly the services
you want with same defaults.

## 🤔 What is this?

If you've ever wanted to try self-hosting but felt overwhelmed by the number
of options (Jellyfin? Mealie? Vaultwarden? what's a reverse proxy?), this repo
is a starting point. Run one script, check the boxes for the services you
want, and they come up with working defaults - accessible immediately at
`http://<your-server-ip>:<port>`.

Optional reverse proxy + HTTPS (Traefik) and remote access without port
forwarding (Tailscale) are covered separately once you're ready for them.

## 🚀 Quick start

```bash
git clone https://github.com/<you>/homelab-starter.git
cd homelab-starter
./install.sh
```

The installer will:

1. Ask which services you want (grouped by category).
2. Create a shared Docker network and a top-level `.env` with your timezone,
   user/group IDs, etc.
3. Optionally configure Traefik for HTTPS + subdomains (skip this for now if
   you're new - direct ports work fine).
4. Bring up the selected services with `docker compose`.

## 📦 Included services

All ports below are the defaults when accessing a service directly
(`http://<server-ip>:<port>`). If you enable Traefik, each service is also
reachable at `https://<service>.<your-domain>` instead.

| Category | Service | Default port | Notes |
|---|---|---|---|
| Dashboard | Homarr | 7575 | Unified dashboard for all your services |
| Network | AdGuard Home | 3000 (UI), 53 (DNS) | Network-wide ad blocking + DNS |
| Productivity | Mealie | 9925 | Recipe manager and meal planner |
| Productivity | Vikunja | 3456 | Task/to-do manager |
| Productivity | Linkding | 9091 | Bookmark manager |
| Productivity | Memos | 5230 | Quick notes / micro-blog |
| Productivity | BookStack | 8082 | Wiki / documentation (includes its own MariaDB) |
| Productivity | Actual Budget | 5006 | Personal budgeting |
| Productivity | Vaultwarden | 8083 | Password manager (Bitwarden-compatible) |
| Media | Jellyfin | 8096 | Self-hosted media server (movies, TV, music) |
| Media | Jellyseerr | 5055 | Media request manager for Jellyfin |
| Media | Immich | 2283 | Google Photos alternative - heavier, runs its own DB + ML containers |
| Media | Navidrome | 4533 | Music streaming server |
| Media | Audiobookshelf | 8084 | Audiobook and podcast server |
| Media | Kavita | 5000 | Comics/manga/ebook reader |
| Media | Beets | - | CLI music tagger - run manually via `docker compose run`, not in the installer menu |
| Monitoring | Uptime Kuma | 3001 | Uptime monitoring with status pages |
| Monitoring | Grafana | 3030 | Dashboards for metrics and logs |
| Monitoring | Prometheus | 9090 | Metrics collection |
| Monitoring | Loki | 3100 | Log aggregation (pairs with Promtail) |
| Monitoring | Promtail | - | Ships logs to Loki, no web UI |
| Monitoring | cAdvisor | 8085 | Per-container resource metrics |
| Monitoring | node-exporter | 9100 | Host system metrics |
| Tools | Homebox | 7745 | Home inventory tracker |
| Tools | IT-Tools | 8086 | Handy web-based dev/IT utilities |
| Tools | Stirling PDF | 8087 | PDF editing/manipulation toolkit |
| Git | Gitea | 3002 (web), 222 (SSH) | Self-hosted Git server |
| Automation | n8n | 5678 | Workflow automation |
| AI | Ollama | 11434 | Local LLM runner - no web UI/auth, API only |
| AI | Open WebUI | 8080 | Chat UI for Ollama (and other LLM backends) |
| AI | SearXNG | 8888 | Self-hosted, privacy-respecting metasearch engine |

## 🔒 Reverse proxy & HTTPS (optional)

By default every service is reachable at `http://<server-ip>:<port>`. If you
want `https://service.yourdomain.com` URLs with automatic certificates, see
[docs/reverse-proxy-traefik.md](docs/reverse-proxy-traefik.md). You'll need a
domain name and a DNS provider with an API (Cloudflare is free and works
well).

## 🌐 Remote access without port forwarding

Most home internet connections are behind CGNAT, so you can't just open a
port and access your services from outside your house. The easiest fix is
[Tailscale](https://tailscale.com) - see
[docs/remote-access-tailscale.md](docs/remote-access-tailscale.md).

## 🖥️ What this runs on

Most of this catalog runs comfortably on a low-power Intel N100 mini PC with
16GB of RAM - less horsepower than most modern desktops or laptops, so if it
runs there, it'll run on whatever you've got.

The AI stack (`ai/ollama`, `ai/open-webui`, `ai/searxng`) is the exception -
that runs on a separate, higher-end gaming PC where it can take advantage of
a real GPU for inference.

## ✅ Requirements

- A Linux machine (or VM) with Docker and the Docker Compose plugin installed
- `whiptail` (preinstalled on Debian/Ubuntu; `apt install whiptail` if missing)

## 📄 License

MIT - see [LICENSE](LICENSE). Each service is its own upstream project under
its own license; this repo only contains compose files and configuration to
run them.
