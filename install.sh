#!/usr/bin/env bash
# Interactive installer for homelab-starter.
# Lets you pick which services to run, optionally configures a Traefik
# reverse proxy with HTTPS, and brings everything up with docker compose.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$ROOT_DIR/services"

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}
require docker
require whiptail
require openssl
docker compose version >/dev/null 2>&1 || { echo "docker compose plugin not found" >&2; exit 1; }

# Catalog of selectable services: "category/dir|Display Name|Description"
CATALOG=(
  "dashboard/homarr|Homarr|Unified dashboard for all your services"
  "network/adguard|AdGuard Home|Network-wide ad blocking + DNS"
  "productivity/mealie|Mealie|Recipe manager and meal planner"
  "productivity/vikunja|Vikunja|Task/to-do manager"
  "productivity/linkding|Linkding|Bookmark manager"
  "productivity/memos|Memos|Quick notes / micro-blog"
  "productivity/bookstack|BookStack|Wiki / documentation"
  "productivity/actual|Actual Budget|Personal budgeting"
  "productivity/vaultwarden|Vaultwarden|Password manager (Bitwarden-compatible)"
  "media/jellyfin|Jellyfin|Self-hosted media server (movies, TV, music)"
  "media/jellyseerr|Jellyseerr|Media request manager for Jellyfin"
  "media/immich|Immich|Google Photos alternative (heavier - has its own DB + ML)"
  "media/navidrome|Navidrome|Music streaming server"
  "media/audiobookshelf|Audiobookshelf|Audiobook and podcast server"
  "media/kavita|Kavita|Comics/manga/ebook reader"
  "monitoring/uptime-kuma|Uptime Kuma|Uptime monitoring with status pages"
  "monitoring/grafana|Grafana|Dashboards for metrics and logs"
  "monitoring/prometheus|Prometheus|Metrics collection"
  "monitoring/loki|Loki|Log aggregation (pairs with Promtail)"
  "monitoring/promtail|Promtail|Ships logs to Loki"
  "monitoring/cadvisor|cAdvisor|Per-container resource metrics"
  "monitoring/node-exporter|node-exporter|Host system metrics"
  "tools/homebox|Homebox|Home inventory tracker"
  "tools/it-tools|IT-Tools|Handy web-based dev/IT utilities"
  "tools/stirling-pdf|Stirling PDF|PDF editing/manipulation toolkit"
  "git/gitea|Gitea|Self-hosted Git server"
  "automation/n8n|n8n|Workflow automation"
)

CHECKLIST_ARGS=()
for entry in "${CATALOG[@]}"; do
  IFS='|' read -r path name desc <<< "$entry"
  CHECKLIST_ARGS+=("$path" "$name - $desc" OFF)
done

CHOICES_RAW=$(whiptail --title "homelab-starter" --checklist \
  "Choose services to install (space to toggle, enter to confirm, arrows/PgUp/PgDn to scroll)" \
  24 78 14 \
  "${CHECKLIST_ARGS[@]}" 3>&1 1>&2 2>&3) || { echo "Cancelled."; exit 0; }

if [ -z "$CHOICES_RAW" ]; then
  echo "Nothing selected, exiting."
  exit 0
fi

# whiptail outputs space-separated, double-quoted tags - safe to eval here
# since the value comes straight from whiptail's own output.
eval "SELECTED=($CHOICES_RAW)"

# --- Reverse proxy opt-in ---
USE_TRAEFIK=0
if whiptail --title "Reverse proxy" --yesno \
"Enable Traefik reverse proxy with automatic HTTPS?

Requires a domain name and a Cloudflare API token (DNS edit permission).
If you're not sure, choose No - every service below will still be reachable\
 at http://<server-ip>:<port>. You can re-run this script later to enable it." \
  14 72; then
  USE_TRAEFIK=1
fi

# --- Top-level .env ---
ENV_FILE="$ROOT_DIR/.env"
[ -f "$ENV_FILE" ] || cp "$ROOT_DIR/.env.example" "$ENV_FILE"

if [ "$USE_TRAEFIK" -eq 1 ]; then
  DOMAIN=$(whiptail --inputbox "Domain name (e.g. example.com)\nServices will be reachable at <service>.<domain>" 11 70 3>&1 1>&2 2>&3) || exit 1
  ACME_EMAIL=$(whiptail --inputbox "Email address for Let's Encrypt expiry notices" 10 70 3>&1 1>&2 2>&3) || exit 1
  CF_TOKEN=$(whiptail --passwordbox "Cloudflare API token (Zone:DNS:Edit for $DOMAIN)" 10 70 3>&1 1>&2 2>&3) || exit 1

  sed -i "s/^DOMAIN=.*/DOMAIN=${DOMAIN}/" "$ENV_FILE"

  TRAEFIK_DIR="$SERVICES_DIR/network/traefik"
  sed -e "s/__DOMAIN__/${DOMAIN}/g" -e "s/__ACME_EMAIL__/${ACME_EMAIL}/g" \
    "$TRAEFIK_DIR/traefik.yml.template" > "$TRAEFIK_DIR/traefik.yml"

  TRAEFIK_ENV="$TRAEFIK_DIR/.env"
  [ -f "$TRAEFIK_ENV" ] || cp "$TRAEFIK_DIR/.env.example" "$TRAEFIK_ENV"
  sed -i "s/^CF_DNS_API_TOKEN=.*/CF_DNS_API_TOKEN=${CF_TOKEN}/" "$TRAEFIK_ENV"
  sed -i "s/^ACME_EMAIL=.*/ACME_EMAIL=${ACME_EMAIL}/" "$TRAEFIK_ENV"
fi

# --- Shared docker networks ---
docker network inspect homelab >/dev/null 2>&1 || docker network create homelab
if [ "$USE_TRAEFIK" -eq 1 ]; then
  docker network inspect traefik_proxy >/dev/null 2>&1 || docker network create traefik_proxy
  docker network inspect socket_proxy >/dev/null 2>&1 || docker network create --internal socket_proxy
fi

# Collects "service KEY=value" lines for secrets we auto-generated, so they
# can be shown to the user once everything is up.
GENERATED_CREDS=()

# Prompt for any unset/placeholder values in a service's .env, writing the
# result to <service>/.env. Secret/key/token/password vars left blank are
# auto-generated (and recorded in GENERATED_CREDS); everything else is
# prompted with its current value as the default.
prompt_for_env() {
  local svc_dir="$1" svc_name="$2"
  local example="$svc_dir/.env.example"
  local env_file="$svc_dir/.env"
  [ -f "$example" ] || return 0
  [ -f "$env_file" ] || cp "$example" "$env_file"

  while IFS='=' read -r key val; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    if [ -z "$val" ] && [[ "$key" =~ (SECRET|KEY|TOKEN|PASSWORD) ]]; then
      local generated
      generated=$(openssl rand -hex 32)
      sed -i "s|^${key}=.*|${key}=${generated}|" "$env_file"
      GENERATED_CREDS+=("$svc_name: $key=$generated")
    else
      local input
      input=$(whiptail --inputbox "$svc_name: $key" 10 70 "$val" 3>&1 1>&2 2>&3) || exit 1
      sed -i "s|^${key}=.*|${key}=${input}|" "$env_file"
    fi
  done < "$example"
}

# --- Bring up Traefik first, if enabled ---
if [ "$USE_TRAEFIK" -eq 1 ]; then
  ( cd "$SERVICES_DIR/network/traefik" && docker compose --env-file "$ENV_FILE" --env-file .env up -d )
fi

# --- Bring up selected services ---
for path in "${SELECTED[@]}"; do
  svc_dir="$SERVICES_DIR/$path"
  svc_name="${path##*/}"
  prompt_for_env "$svc_dir" "$svc_name"

  compose_args=(-f "$svc_dir/compose.yml")
  if [ "$USE_TRAEFIK" -eq 1 ] && [ -f "$svc_dir/compose.traefik.yml" ]; then
    compose_args+=(-f "$svc_dir/compose.traefik.yml")
  fi

  env_args=(--env-file "$ENV_FILE")
  [ -f "$svc_dir/.env" ] && env_args+=(--env-file "$svc_dir/.env")

  echo "==> Starting $svc_name"
  ( cd "$svc_dir" && docker compose "${env_args[@]}" "${compose_args[@]}" up -d )
done

echo
echo "Done! Services are starting up."
if [ "$USE_TRAEFIK" -eq 1 ]; then
  echo "Once DNS + certificates settle, they'll be available at https://<service>.${DOMAIN:-yourdomain}"
else
  echo "Each service is available at http://<this-server-ip>:<port> (see each service's compose.yml for its port)."
fi

# --- Generated credentials summary ---
if [ "${#GENERATED_CREDS[@]}" -gt 0 ]; then
  CREDS_FILE="$ROOT_DIR/CREDENTIALS.txt"
  {
    echo "Generated credentials ($(date))"
    echo "These are also saved in each service's .env file."
    echo
    for line in "${GENERATED_CREDS[@]}"; do
      echo "$line"
    done
  } > "$CREDS_FILE"
  chmod 600 "$CREDS_FILE"

  echo
  echo "Generated credentials for the following services (saved to $CREDS_FILE, keep it safe):"
  for line in "${GENERATED_CREDS[@]}"; do
    echo "  - $line"
  done
fi
