#!/bin/sh
set -e

DOMAIN="$1"
EMAIL="$2"
WEBROOT="${WEBROOT:-$(pwd)/data/webroot}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <domain> <email>"
  echo "Example: $0 example.com admin@example.com"
  exit 1
fi

mkdir -p ./data/letsencrypt ./data/letsencrypt-lib "$WEBROOT"

docker run --rm -it \
  -v "$(pwd)/data/letsencrypt:/etc/letsencrypt" \
  -v "$(pwd)/data/letsencrypt-lib:/var/lib/letsencrypt" \
  -v "$WEBROOT:/var/www/certbot" \
  certbot/certbot certonly --webroot \
  --webroot-path /var/www/certbot \
  -d "$DOMAIN" \
  --email "$EMAIL" \
  --agree-tos --no-eff-email

echo "Certificate saved to ./data/letsencrypt/live/$DOMAIN/"
