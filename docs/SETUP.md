# Setup Guide

Deploy OpenClaw to Railway in minutes.

## Prerequisites

- [Railway account](https://railway.app)
- API key from an LLM provider
- Bot token for your channel (Telegram, Discord, or Slack)
- Your user ID for that channel

## Step 1: Get Your Credentials

### LLM Provider

Get an API key from your preferred provider. See [PROVIDERS.md](PROVIDERS.md) for the list of supported providers.

### Telegram Bot

1. Message [@BotFather](https://t.me/botfather) on Telegram
2. Send `/newbot`
3. Follow prompts to name your bot
4. Copy the token

### Your Telegram User ID

1. Message [@userinfobot](https://t.me/userinfobot) on Telegram
2. It replies with your user ID (a number)

### Discord Bot (alternative)

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create New Application → Bot → Add Bot
3. Copy the token
4. Enable Message Content Intent under Privileged Gateway Intents
5. Your user ID: Enable Developer Mode in Discord settings, right-click yourself, Copy ID

### Slack Bot (alternative)

1. Go to [Slack API](https://api.slack.com/apps)
2. Create New App → From scratch
3. Add OAuth scopes under OAuth & Permissions
4. Install to workspace
5. Copy Bot Token (`xoxb-...`) and App Token (`xapp-...`)

## Step 2: Deploy to Railway

### Option A: One-Click Deploy

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/yBnBWA?referralCode=slayga&utm_medium=integration&utm_source=template&utm_campaign=generic)

### Option B: From GitHub

1. Fork this repository
2. In Railway: New Project → Deploy from GitHub
3. Select your fork

## Step 3: Set Environment Variables

In Railway Dashboard → Your Service → Variables:

**Required:**
```
YOUR_PROVIDER_API_KEY=...
TELEGRAM_BOT_TOKEN=...
TELEGRAM_OWNER_ID=...
```

Replace `YOUR_PROVIDER_API_KEY` with the appropriate variable for your provider (see [PROVIDERS.md](PROVIDERS.md)).

See [config/environment.md](../config/environment.md) for all options.

## Step 4: Deploy

Click Deploy. Wait for the build to complete.

Check the logs for:
```
[entrypoint] Building config from environment variables...
[entrypoint] Gateway started successfully
[openclaw] Health server on :8080
```

## Step 5: Message Your Bot

Open your channel (Telegram, Discord, Slack) and message your bot.

You should get a response immediately - no pairing needed because your owner ID is pre-approved.

## Done

Your bot is running. Start chatting.

---

## Troubleshooting

### Bot doesn't respond

1. Check Railway logs for errors
2. Verify bot token is correct
3. Verify owner ID is correct
4. Make sure you're messaging the bot directly (not in a group)

### "No LLM provider API key set"

Add a provider API key to environment variables.

### Gateway won't start

Gateway logs stream to stdout — check Railway deployment logs in the dashboard or via CLI:
```bash
railway logs
```

### Need to change config

Config is regenerated from environment variables on every deploy. To change settings:

1. Update environment variables in Railway Dashboard → Your Service → Variables
2. Redeploy: click **Redeploy** in the dashboard, or run `railway up`

For advanced config changes not exposed as env vars, SSH in at Tier 2+:
```bash
railway ssh
```

---

## Updating

Redeploy the container:

```bash
railway up
```

Do not run `openclaw update` inside the container.

---

## Adding Other Users

Your owner ID is pre-approved. For others:

1. They message your bot
2. They receive a pairing code
3. You approve via SSH:
   ```bash
   railway ssh
   openclaw pairing approve telegram <CODE>
   ```

---

## Next Steps

- [Security Tiers](TIERS.md) - Unlock more capabilities
- [Security Model](SECURITY.md) - Understand protections
- [Providers](PROVIDERS.md) - Provider configuration
