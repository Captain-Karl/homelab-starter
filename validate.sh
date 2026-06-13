#!/usr/bin/env bash
# Validates every service's compose.yml (and compose.traefik.yml overlay, if
# present) with `docker compose config -q`. Does NOT start any containers.
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="$ROOT_DIR/services"

# Root .env with DOMAIN set so traefik overlays (which reference ${DOMAIN})
# validate cleanly.
ROOT_ENV="/tmp/homelab-validate-root.env"
cat > "$ROOT_ENV" <<EOF
TZ=America/New_York
PUID=1000
PGID=1000
DOMAIN=example.com
EOF

FAIL=0

for svc_dir in "$SERVICES_DIR"/*/*/; do
  svc_dir="${svc_dir%/}"
  [ -f "$svc_dir/compose.yml" ] || continue
  rel="${svc_dir#"$SERVICES_DIR"/}"

  # Build a temp .env from .env.example (if any) with blanks filled so
  # config validation doesn't choke on empty required values.
  env_args=(--env-file "$ROOT_ENV")
  if [ -f "$svc_dir/.env.example" ]; then
    tmp_env="/tmp/homelab-validate-$(echo "$rel" | tr '/' '-').env"
    # Leave TRAEFIK_BIND_ADDRESS empty - compose's ${VAR:-0.0.0.0} default
    # only kicks in for unset/empty values, not "placeholder".
    sed -E '/^TRAEFIK_BIND_ADDRESS=$/!s/^([A-Za-z0-9_]+)=$/\1=placeholder/' "$svc_dir/.env.example" > "$tmp_env"
    env_args+=(--env-file "$tmp_env")
  fi

  # If compose references `env_file: .env` directly (e.g. traefik), create a
  # temp .env there for validation and remove it afterwards.
  local_env_created=0
  if grep -q "env_file" "$svc_dir/compose.yml" 2>/dev/null && [ ! -f "$svc_dir/.env" ] && [ -f "$svc_dir/.env.example" ]; then
    cp "$tmp_env" "$svc_dir/.env"
    local_env_created=1
  fi

  # Base compose
  if out=$(cd "$svc_dir" && docker compose "${env_args[@]}" -f compose.yml config -q 2>&1); then
    echo "OK   $rel"
  else
    echo "FAIL $rel (base)"
    echo "$out" | sed 's/^/     /'
    FAIL=1
  fi

  # Traefik overlay
  if [ -f "$svc_dir/compose.traefik.yml" ]; then
    if out=$(cd "$svc_dir" && docker compose "${env_args[@]}" -f compose.yml -f compose.traefik.yml config -q 2>&1); then
      echo "OK   $rel (+traefik)"
    else
      echo "FAIL $rel (+traefik)"
      echo "$out" | sed 's/^/     /'
      FAIL=1
    fi
  fi

  [ "$local_env_created" -eq 1 ] && rm -f "$svc_dir/.env"
done

exit $FAIL
