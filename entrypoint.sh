#!/bin/bash
# =============================================================================
# OpenClaw Railway Entrypoint
# Runs as root to fix volume permissions, then drops to openclaw user
# =============================================================================

set -e

echo "[entrypoint] Starting OpenClaw Railway..."

# Create data directories if they don't exist
mkdir -p /data/.openclaw /data/workspace /data/core

# Fix ownership - Railway mounts volumes as root
chown -R openclaw:openclaw /data

echo "[entrypoint] Data directories ready, owned by openclaw"
ls -la /data/

# Drop privileges and run the app as openclaw user
exec su openclaw -c "bun run src/server.js"
