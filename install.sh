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

if [ ! -f prometheus/prometheus.yml.template ]; then
  echo "Missing prometheus/prometheus.yml.template"
  exit 1
fi

[ -f .env ] && set -a && source .env && set +a

PORT="${APP_SERVER_PORT:-8080}"
[ -z "${APP_SERVER_IP}" ] && APP_SERVER_IP="APP_SERVER_IP"
sed "s|APP_SERVER_IP|${APP_SERVER_IP}|g; s|APP_SERVER_PORT|${PORT}|g" prometheus/prometheus.yml.template > prometheus/prometheus.yml

if [ -n "${SCRAPE_TOKEN}" ]; then
  sed "s|SCRAPE_TOKEN|${SCRAPE_TOKEN}|g" prometheus/prometheus.yml > prometheus/prometheus.yml.tmp && mv prometheus/prometheus.yml.tmp prometheus/prometheus.yml
else
  sed '/bearer_token/d' prometheus/prometheus.yml > prometheus/prometheus.yml.tmp && mv prometheus/prometheus.yml.tmp prometheus/prometheus.yml
fi

echo "Starting stack (target: ${APP_SERVER_IP}:${PORT})..."
docker compose up -d
echo "Grafana http://localhost:${GRAFANA_PORT:-3000} | Prometheus ${PROMETHEUS_PORT:-9090} | Loki ${LOKI_PORT:-3100}"
