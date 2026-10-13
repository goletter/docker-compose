#!/bin/sh
set -e

DOMAIN="$1"
EMAIL="$2"
WEBROOT="${WEBROOT:-$(pwd)/data/webroot}"
NGINX_CERT_DIR="${NGINX_CERT_DIR:-/etc/nginx/cert}"

if [ -z "$DOMAIN" ] || [ -z "$EMAIL" ]; then
  echo "Usage: $0 <domain> <email>"
  echo "Example: $0 example.com admin@example.com"
  echo ""
  echo "Env:"
  echo "  WEBROOT=/var/www/<domain>   # must match nginx acme root (default: ./data/webroot)"
  echo "  NGINX_CERT_DIR=/etc/nginx/cert  # per-site cert output (default)"
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

LIVE_DIR="$(pwd)/data/letsencrypt/live/$DOMAIN"
SITE_CERT_DIR="$NGINX_CERT_DIR/$DOMAIN"

if [ ! -f "$LIVE_DIR/fullchain.pem" ] || [ ! -f "$LIVE_DIR/privkey.pem" ]; then
  echo "ERROR: certificate files not found under $LIVE_DIR"
  exit 1
fi

mkdir -p "$SITE_CERT_DIR"
# -L: dereference Let's Encrypt symlinks so nginx gets real files
cp -L "$LIVE_DIR/fullchain.pem" "$SITE_CERT_DIR/$DOMAIN.pem"
cp -L "$LIVE_DIR/privkey.pem"   "$SITE_CERT_DIR/$DOMAIN.key"
chmod 644 "$SITE_CERT_DIR/$DOMAIN.pem"
chmod 600 "$SITE_CERT_DIR/$DOMAIN.key"

echo "Certificate issued for $DOMAIN"
echo "  Let's Encrypt: $LIVE_DIR/"
echo "  Nginx certs:   $SITE_CERT_DIR/$DOMAIN.pem"
echo "                 $SITE_CERT_DIR/$DOMAIN.key"
echo ""
echo "nginx example:"
echo "  ssl_certificate     $SITE_CERT_DIR/$DOMAIN.pem;"
echo "  ssl_certificate_key $SITE_CERT_DIR/$DOMAIN.key;"
