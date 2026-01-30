# Moltbot Railway - Hardened Template

Security-first Moltbot deployment for Railway with hardened defaults, non-root container, and proper auth handling.

## Features

- **Non-root container** - Runs as uid 1001 for security
- **Token injection fix** - Control UI works without manual token entry
- **Command execution disabled** - Secure by default
- **Rate limiting** - Protects setup endpoint from brute force
- **1-year auth tokens** - Via `claude setup-token`
- **Bun runtime** - Fast wrapper server

## Quick Deploy

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/moltbot-hardened)

Or manually:

1. Fork this repository
2. Create new Railway project from GitHub repo
3. Set `SETUP_PASSWORD` environment variable (min 16 characters)
4. Deploy

## Setup

### 1. Access Setup Wizard

After deployment, visit:
```
https://your-app.railway.app/setup
```

Enter your `SETUP_PASSWORD` when prompted.

### 2. Configure Auth Provider

Recommended: **Anthropic token via Claude Code CLI**

1. SSH into container: `railway shell`
2. Run: `claude setup-token`
3. Complete browser auth flow
4. Token automatically syncs to Moltbot

Alternative: Paste API key directly in setup wizard.

### 3. Add Channels (Optional)

In the setup wizard, add:
- **Telegram**: Get token from @BotFather
- **Discord**: Get token from Discord Developer Portal (enable MESSAGE CONTENT INTENT)
- **Slack**: Get bot token and app token

### 4. Complete Onboarding

Click "Run setup" - this configures Moltbot with hardened defaults:
- Command execution: **disabled**
- Gateway auth: **token required**
- DM policy: **pairing required**

### 5. Approve Pairing

Message your bot on Telegram/Discord. You'll receive a pairing code.

Use the "Approve pairing" button in the setup wizard, or SSH in and run:
```bash
moltbot pairing approve telegram ABCD1234
```

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `SETUP_PASSWORD` | Password for /setup UI (min 16 chars) |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `MOLTBOT_GATEWAY_TOKEN` | (auto-generated) | Gateway auth token |
| `MOLTBOT_STATE_DIR` | `/data/.moltbot` | State directory |
| `MOLTBOT_WORKSPACE_DIR` | `/data/workspace` | Workspace directory |

## Security Model

### Trust Ladder

1. **Setup Password** - Access to /setup configuration
2. **Gateway Token** - Access to Control UI and API
3. **Channel Pairing** - Per-user approval for messaging
4. **Command Execution** - Disabled by default

### Hardened Defaults

| Setting | Value | Purpose |
|---------|-------|---------|
| `nodes.run.enabled` | `false` | No arbitrary commands |
| `gateway.auth.mode` | `token` | Require authentication |
| `gateway.bind` | `loopback` | Internal only |
| `dmPolicy` | `pairing` | Require approval |

## CLI Reference

SSH into container: `railway shell`

```bash
# Status
moltbot status
moltbot health

# Auth (recommended)
claude setup-token  # Creates 1-year token

# Config
moltbot config get nodes.run.enabled
moltbot config set nodes.run.enabled true  # Enable if needed

# Channels
moltbot pairing approve telegram CODE
moltbot channels list

# Update
moltbot update
```

## Backup & Restore

### Export

Download backup from:
```
https://your-app.railway.app/setup/export
```

### Restore

Extract to `/data` volume and restart.

## Updating Moltbot

SSH in and run:
```bash
moltbot update
```

Or redeploy with updated `MOLTBOT_GIT_REF` build arg.

## Troubleshooting

### "Gateway not ready"

1. Check logs: `railway logs`
2. SSH in and run: `moltbot doctor --fix`
3. Restart service in Railway dashboard

### "Token invalid"

1. SSH in and run: `claude setup-token`
2. Complete browser auth
3. Restart gateway

### Bot not responding

1. Check channel is enabled: `moltbot channels list`
2. Check pairing approved: `moltbot pairing list`
3. Check logs for errors

## License

MIT

## Credits

Based on patterns from [vignesh07/clawdbot-railway-template](https://github.com/vignesh07/clawdbot-railway-template) with security hardening.
