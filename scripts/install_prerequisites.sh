
#!/bin/bash
# One-time setup on EC2 (Ubuntu): install Docker + Docker Compose plugin.
# Run with: bash install_prerequisites.sh
# After running: logout and login again so docker group applies.

set -e

echo "🔹 Updating system"
sudo apt update -y
sudo apt upgrade -y

echo "🔹 Installing basic utilities"
sudo apt install -y ca-certificates curl gnupg lsb-release

echo "🔹 Installing Docker"
curl -fsSL https://get.docker.com | sudo bash

echo "🔹 Enabling Docker"
sudo systemctl start docker
sudo systemctl enable docker

echo "🔹 Adding user to docker group"
sudo usermod -aG docker "$USER"

echo "🔹 Installing Docker Compose (plugin)"
COMPOSE_VERSION="v2.25.0"
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  COMPOSE_ARCH="x86_64" ;;
  aarch64|arm64) COMPOSE_ARCH="aarch64" ;;
  *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-linux-${COMPOSE_ARCH}" \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

echo "✅ Installation complete"
echo "⚠️  Logout and login again for docker permissions to apply (then run deploy.sh or docker compose from your app directory)"
