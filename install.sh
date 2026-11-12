#!/bin/bash
set -e

# 1. Docker
if ! command -v docker &> /dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  rm -f get-docker.sh
  echo "Done. Run: newgrp docker && ./install.sh"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

[ -f .env ] && set -a && source .env && set +a

echo "Starting stack..."
docker compose up -d
echo "Grafana http://localhost:${GRAFANA_PORT:-3000} | Prometheus ${PROMETHEUS_PORT:-9090} | Loki ${LOKI_PORT:-3100}"
