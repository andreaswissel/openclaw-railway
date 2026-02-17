#!/bin/bash
# =============================================================================
# OpenClaw Railway Entrypoint
# Builds config from env vars, starts gateway, then health server
# =============================================================================

set -e

echo "[entrypoint] Starting OpenClaw Railway..."

# -----------------------------------------------------------------------------
# 1. Create data directories with secure permissions
# -----------------------------------------------------------------------------
mkdir -p /data/.openclaw /data/workspace
chmod 700 /data/.openclaw
chown -R openclaw:openclaw /data

echo "[entrypoint] Data directories ready"

# -----------------------------------------------------------------------------
# 2. Copy workspace templates (only files that don't already exist)
# -----------------------------------------------------------------------------
if [ -d "/app/workspace-templates" ]; then
  for tmpl in /app/workspace-templates/*; do
    basename="$(basename "$tmpl")"
    if [ ! -e "/data/workspace/$basename" ]; then
      echo "[entrypoint] Copying template: $basename"
      cp -r "$tmpl" "/data/workspace/$basename"
      chown -R openclaw:openclaw "/data/workspace/$basename"
    fi
  done
fi

# Copy docs to workspace for agent discovery
if [ -d "/app/docs" ] && [ ! -d "/data/workspace/docs" ]; then
  echo "[entrypoint] Copying documentation to workspace..."
  cp -r /app/docs /data/workspace/
  chown -R openclaw:openclaw /data/workspace/docs
fi

# -----------------------------------------------------------------------------
# 2b. Lock behavioral template files (prevents persistent backdoor)
#     These files define the agent's safety instructions and personality.
#     A prompt injection that overwrites AGENTS.md can remove all safety
#     guardrails — and the change persists across restarts because the
#     entrypoint skips existing files. Locking them to root-owned read-only
#     means the agent can read its instructions but can't rewrite them.
#     Always overwrite from templates to undo any prior tampering.
# -----------------------------------------------------------------------------
PROTECTED_TEMPLATES="AGENTS.md TOOLS.md PROGRESSION.md PROJECTS.md"
for fname in $PROTECTED_TEMPLATES; do
  src="/app/workspace-templates/$fname"
  dst="/data/workspace/$fname"
  if [ -f "$src" ]; then
    cp "$src" "$dst"
    chown root:openclaw "$dst"
    chmod 440 "$dst"
  fi
done
# Docs directory: same treatment
if [ -d "/app/docs" ]; then
  cp -r /app/docs /data/workspace/
  chown -R root:openclaw /data/workspace/docs
  chmod -R u=rwX,g=rX,o= /data/workspace/docs
fi
echo "[entrypoint] Behavioral templates locked (root:openclaw 440)"

# -----------------------------------------------------------------------------
# 3. Deploy exec-approvals (tier-aware)
#    Tier 0: ls only, ask off
#    Tier 1: curated list (cat, grep, git, etc.), ask on-miss
#    Tier 2+: full exec, no allowlist needed
#    Note: exec-approvals.json lives at ~/.openclaw/ (user home), NOT $OPENCLAW_STATE_DIR
# -----------------------------------------------------------------------------
SECURITY_TIER="${SECURITY_TIER:-0}"
APPROVALS_HOME="/home/openclaw/.openclaw/exec-approvals.json"

mkdir -p /home/openclaw/.openclaw

case "$SECURITY_TIER" in
  0)
    APPROVALS_SRC="/app/config/exec-approvals-tier0.json"
    echo "[entrypoint] Deploying exec-approvals for Tier 0 (ls only)..."
    ;;
  1)
    APPROVALS_SRC="/app/config/exec-approvals-tier1.json"
    echo "[entrypoint] Deploying exec-approvals for Tier 1 (curated list)..."
    ;;
  *)
    APPROVALS_SRC=""
    echo "[entrypoint] Tier ${SECURITY_TIER}: full exec mode, no exec-approvals needed"
    # Remove stale approvals file if upgrading from a lower tier
    rm -f "$APPROVALS_HOME"
    ;;
esac

if [ -n "$APPROVALS_SRC" ] && [ -f "$APPROVALS_SRC" ]; then
  cp "$APPROVALS_SRC" "$APPROVALS_HOME"
  chmod 600 "$APPROVALS_HOME"
fi

chown -R openclaw:openclaw /home/openclaw/.openclaw

# -----------------------------------------------------------------------------
# 4. Build config from environment variables (always regenerate)
# -----------------------------------------------------------------------------
CONFIG_FILE="/data/.openclaw/openclaw.json"

# Always regenerate config from env vars to pick up changes
echo "[entrypoint] Building config from environment variables..."
node /app/src/build-config.js

# -----------------------------------------------------------------------------
# 4b. Harden config file permissions (pre-gateway)
#     Config starts at 640 root:openclaw so the gateway can read it at startup.
#     After the gateway loads it into memory, step 5 locks it to 600 root:root
#     so even exec cat can't read it.
# -----------------------------------------------------------------------------
if [ -f "$CONFIG_FILE" ]; then
  chown root:openclaw "$CONFIG_FILE"
  chmod 640 "$CONFIG_FILE"

  # Lock the .openclaw directory — openclaw can traverse and read, not create files
  chown root:openclaw /data/.openclaw
  chmod 750 /data/.openclaw

  echo "[entrypoint] Config set to 640 (gateway will read, then locked to 600)"
fi

# Exec-approvals: root owns it, but gateway needs read+write at runtime
# (exec tool updates lastUsedCommand metadata on each call).
# 660 = group rw, which means the agent's write tool could also modify it.
# Accepted tradeoff: even if the agent rewrites exec-approvals to expand
# the allowlist, the tool policy in openclaw.json (which IS locked) still
# governs which tools are available. The directory is 750 so the agent
# can't create new files.
if [ -f "$APPROVALS_HOME" ]; then
  chown root:openclaw "$APPROVALS_HOME"
  chmod 660 "$APPROVALS_HOME"
  chown root:openclaw "$(dirname "$APPROVALS_HOME")"
  chmod 750 "$(dirname "$APPROVALS_HOME")"
  echo "[entrypoint] Exec-approvals hardened (root:openclaw 660, dir 750)"
fi

# -----------------------------------------------------------------------------
# 4c. Env var notes
#     All secrets are now inlined in openclaw.json (which is locked after
#     gateway loads it). The gateway starts with env -i so /proc/self/environ
#     is empty. No env var scrubbing needed — they never reach the gateway.
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# 5. Start OpenClaw gateway (if configured)
# -----------------------------------------------------------------------------
start_gateway() {
  echo "[entrypoint] Starting gateway..."

  # Start gateway with empty environment (env -i). All secrets are in the
  # config file — the gateway reads them at startup, not from process.env.
  # This means /proc/self/environ for the gateway process contains nothing
  # sensitive, closing the exec-based exfiltration vector at all tiers.
  env -i \
    HOME=/home/openclaw \
    PATH=/usr/local/bin:/usr/bin:/bin \
    OPENCLAW_STATE_DIR=/data/.openclaw \
    NODE_ENV=production \
    su openclaw -c "cd /data/workspace && openclaw gateway run --port 18789 2>&1 | while read line; do echo \"[gateway] \$line\"; done" &
  GATEWAY_PID=$!

  sleep 3

  if kill -0 $GATEWAY_PID 2>/dev/null; then
    echo "[entrypoint] Gateway running (PID: $GATEWAY_PID)"

    # Lock config to root-only now that gateway has loaded it into memory.
    # The gateway doesn't re-read the file after startup, so this is safe.
    # This blocks exec-based reads (cat /data/.openclaw/openclaw.json) at
    # all tiers — the openclaw user gets Permission denied.
    chmod 600 "$CONFIG_FILE"
    chown root:root "$CONFIG_FILE"
    echo "[entrypoint] Config locked to root-only (600) after gateway loaded"
  else
    echo "[entrypoint] ERROR: Gateway exited immediately"
    exit 1
  fi
}

if [ -f "$CONFIG_FILE" ]; then
  start_gateway
else
  echo "[entrypoint] No config generated (missing required env vars)"
  echo "[entrypoint] Set LLM provider key + channel token, then redeploy"
  echo "[entrypoint] Or SSH in and run: openclaw onboard"

  # Start config watcher as fallback for manual onboard
  nohup /app/config-watcher.sh > /dev/null 2>&1 &
  disown
fi

# -----------------------------------------------------------------------------
# 6. Start health check server (drops to openclaw user, scrubbed env)
#    Health server only needs PORT — strip everything else to minimize
#    what's visible in /proc/self/environ for this process tree.
# -----------------------------------------------------------------------------
echo "[entrypoint] Starting health server..."
exec env -i HOME=/home/openclaw PATH=/usr/local/bin:/usr/bin:/bin PORT="${PORT:-8080}" \
  su openclaw -c "cd /app && node src/server.js"
