#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/opt/cloudmentor}"
WEB_DIR="/var/www/cloudmentor"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "This bootstrap script expects Ubuntu/Debian on EC2."
  exit 1
fi

sudo apt-get update -y
sudo apt-get install -y nginx rsync curl unzip ca-certificates
sudo systemctl enable nginx
sudo systemctl start nginx

sudo mkdir -p "$APP_DIR" "$WEB_DIR"
sudo chown -R "$USER:$USER" "$APP_DIR"
sudo chown -R www-data:www-data "$WEB_DIR"

sudo tee /etc/nginx/sites-available/cloudmentor >/dev/null <<'NGINX'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/cloudmentor;
    index index.html;

    access_log /var/log/nginx/cloudmentor-access.log;
    error_log /var/log/nginx/cloudmentor-error.log;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /healthz {
        return 200 'cloudmentor-ec2-ok';
        add_header Content-Type text/plain;
    }
}
NGINX

sudo rm -f /etc/nginx/sites-enabled/default
sudo ln -sfn /etc/nginx/sites-available/cloudmentor /etc/nginx/sites-enabled/cloudmentor
sudo nginx -t
sudo systemctl reload nginx

echo "EC2 bootstrap completed. App dir: $APP_DIR, web dir: $WEB_DIR"
