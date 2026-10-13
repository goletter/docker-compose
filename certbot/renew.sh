#!/bin/sh
set -e

WEBROOT="${WEBROOT:-$(pwd)/data/webroot}"
NGINX_CERT_DIR="${NGINX_CERT_DIR:-/etc/nginx/cert}"
RELOAD_NGINX="${RELOAD_NGINX:-1}"
# set FORCE_RENEW=1 to renew even if not near expiry (for testing)
EXTRA_ARGS=""
if [ "${FORCE_RENEW:-0}" = "1" ]; then
  EXTRA_ARGS="--force-renewal"
fi

cd "$(dirname "$0")"

if [ ! -d ./data/letsencrypt/live ]; then
  echo "ERROR: no certificates found under ./data/letsencrypt/live"
  echo "Issue a cert first with: ./cert.sh <domain> <email>"
  exit 1
fi

mkdir -p "$WEBROOT" ./data/letsencrypt ./data/letsencrypt-lib

echo "Renewing certificates (webroot: $WEBROOT) ..."
docker run --rm \
  -v "$(pwd)/data/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/data/letsencrypt-lib:/var/lib/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  certbot/certbot renew \
  --webroot \
  --webroot-path /var/www/certbot \
  $EXTRA_ARGS

sync_domain() {
  domain="$1"
  live_dir="./data/letsencrypt/live/$domain"
  site_dir="$NGINX_CERT_DIR/$domain"

  if [ ! -f "$live_dir/fullchain.pem" ] || [ ! -f "$live_dir/privkey.pem" ]; then
    echo "SKIP: $domain (missing pem files)"
    return 0
  fi

  mkdir -p "$site_dir"
  cp -L "$live_dir/fullchain.pem" "$site_dir/$domain.pem"
  cp -L "$live_dir/privkey.pem"   "$site_dir/$domain.key"
  chmod 644 "$site_dir/$domain.pem"
  chmod 600 "$site_dir/$domain.key"
  echo "Synced: $site_dir/$domain.pem"
  echo "        $site_dir/$domain.key"
}

echo "Syncing to $NGINX_CERT_DIR/<domain>/ ..."
for d in ./data/letsencrypt/live/*; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  # skip README and similar non-domain entries
  case "$name" in
    README) continue ;;
  esac
  sync_domain "$name"
done

if [ "$RELOAD_NGINX" = "1" ]; then
  if command -v nginx >/dev/null 2>&1; then
    nginx -t && nginx -s reload && echo "nginx reloaded"
  elif command -v docker >/dev/null 2>&1 && docker ps --format '{{.Names}}' | grep -qx nginx; then
    docker exec nginx nginx -t && docker exec nginx nginx -s reload && echo "nginx container reloaded"
  else
    echo "WARN: nginx not found; reload manually after renew"
  fi
fi

echo "Renew done."
