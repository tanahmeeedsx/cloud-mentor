#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-ubuntu}"
APP_DIR="${APP_DIR:-/opt/cloudmentor}"
NODE_MAJOR="${NODE_MAJOR:-22}"

echo "==> Updating packages"
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl unzip git rsync nginx python3 python3-pip

echo "==> Installing Node.js $NODE_MAJOR.x"
if ! command -v node >/dev/null 2>&1 || ! node -v | grep -q "^v$NODE_MAJOR"; then
  curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | sudo -E bash -
  sudo apt-get install -y nodejs
fi

echo "==> Installing Docker"
if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get install -y docker.io
  sudo systemctl enable --now docker
fi
sudo usermod -aG docker "$APP_USER" || true

echo "==> Installing AWS CLI v2 if missing"
if ! command -v aws >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$tmpdir/awscliv2.zip"
  unzip -q "$tmpdir/awscliv2.zip" -d "$tmpdir"
  sudo "$tmpdir/aws/install"
  rm -rf "$tmpdir"
fi

echo "==> Installing AWS SAM CLI if missing"
if ! command -v sam >/dev/null 2>&1; then
  tmpdir="$(mktemp -d)"
  curl -fsSL "https://github.com/aws/aws-sam-cli/releases/latest/download/aws-sam-cli-linux-x86_64.zip" -o "$tmpdir/aws-sam-cli.zip"
  unzip -q "$tmpdir/aws-sam-cli.zip" -d "$tmpdir/sam-installation"
  sudo "$tmpdir/sam-installation/install"
  rm -rf "$tmpdir"
fi

echo "==> Preparing app directory and Nginx"
sudo mkdir -p "$APP_DIR" /var/www/cloudmentor
sudo chown -R "$APP_USER:$APP_USER" "$APP_DIR"
sudo chown -R "$APP_USER:$APP_USER" /var/www/cloudmentor
sudo systemctl enable --now nginx

echo "==> Installed versions"
node -v
npm -v
aws --version
sam --version
docker --version

echo "\nBootstrap complete. Log out and SSH back in so Docker group membership is refreshed."
echo "Then run: cd $APP_DIR && ./scripts/ec2-deploy.sh"
