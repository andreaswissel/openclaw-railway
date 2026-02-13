# LLM Providers

Configure your preferred LLM provider via environment variables.

## Recommended: OpenRouter

**Start here.** One API key gives you access to models from every major provider — OpenAI, Anthropic, Google, MiniMax, DeepSeek, Meta, Mistral, and more. No custom config, no surprises.

```
OPENROUTER_API_KEY=sk-or-...
LLM_PRIMARY_MODEL=openrouter/minimax/MiniMax-M2.5
```

Get a key at https://openrouter.ai/keys — browse models at https://openrouter.ai/models

## All Supported Providers

These work at Tier 0 with just an environment variable — no SSH or custom config needed.

| Provider | Environment Variable | Example Model Format | Voice | Tier 0 |
|----------|---------------------|---------------------|-------|--------|
| OpenRouter | `OPENROUTER_API_KEY` | `openrouter/provider/model` | No | Yes |
| OpenAI | `OPENAI_API_KEY` | `openai/model-name` | Yes | Yes |
| Anthropic | `ANTHROPIC_API_KEY` | `anthropic/model-name` | No | Yes |
| Google AI | `GOOGLE_AI_API_KEY` | `google/model-name` | No | Yes |
| Groq | `GROQ_API_KEY` | `groq/model-name` | Yes | Yes |
| DeepSeek | `DEEPSEEK_API_KEY` | `deepseek/model-name` | No | Yes |
| Together AI | `TOGETHER_API_KEY` | `together/org/model` | No | Yes |
| Mistral | `MISTRAL_API_KEY` | `mistral/model-name` | No | Yes |
| xAI | `XAI_API_KEY` | `xai/model-name` | No | Yes |
| Venice AI | `VENICE_API_KEY` | `venice/model-name` | No | Yes |
| Cloudflare | `CLOUDFLARE_API_KEY` | `cloudflare/model-name` | No | Yes |

> **Voice column:** Indicates whether the provider supports automatic voice message transcription (e.g., Telegram voice notes). If your primary provider doesn't support voice, add an OpenAI or Groq key alongside it — OpenClaw will use it for transcription automatically. Deepgram (`DEEPGRAM_API_KEY`) also supports voice but is a dedicated transcription service, not a general LLM provider.

## Providers That Need Custom Config (Tier 2+)

Some providers use non-standard endpoints or OAuth flows that can't be configured via environment variables alone. These require SSH access to set up `models.providers` in the config.

| Provider | Issue | Workaround at Tier 0 |
|----------|-------|---------------------|
| MiniMax (coding plan) | Uses Anthropic-compatible endpoint at `api.minimax.io/anthropic` | Use via OpenRouter instead |
| Google Vertex AI | Requires `gcloud` OAuth | Use `GOOGLE_AI_API_KEY` (AI Studio) instead |
| Google Gemini CLI | Requires device-code OAuth | Use `GOOGLE_AI_API_KEY` (AI Studio) instead |
| Qwen Portal | Requires device-code OAuth | Use via OpenRouter instead |
| GitHub Copilot | Requires token auth flow | Use via OpenRouter instead |

At Tier 2+, SSH in and configure these via `models.providers`. See [Model Providers](https://docs.openclaw.ai/concepts/model-providers).

## Model Configuration

### Primary Model

Set via environment variable:
```
LLM_PRIMARY_MODEL=provider/model-name
```

### Task-Specific Models (Tier 2+)

Use different models for different tasks to optimize cost/performance:

```
LLM_PRIMARY_MODEL=provider/smart-model
LLM_HEARTBEAT_MODEL=provider/cheap-model
LLM_SUBAGENT_MODEL=provider/balanced-model
```

### Fallback Models

Comma-separated list of fallbacks if primary fails:

```
LLM_FALLBACK_MODELS=provider1/model1,provider2/model2
```

## Changing Models

There are three ways to change your model, depending on what you need:

### 1. `/model` in chat (temporary)

Type `/model` in Telegram/Discord/Slack to see available models and switch. This is great for experimenting, but **only lasts for the current session** — it resets when the conversation ends.

### 2. Railway environment variable (permanent, requires redeploy)

Change `LLM_PRIMARY_MODEL` in Railway Dashboard → Variables, then redeploy. This is the simplest way to make a permanent change at Tier 0.

### 3. `openclaw models set` via SSH (permanent, no redeploy — Tier 2+)

```bash
railway ssh
openclaw models set provider/model-name
```

This writes to a separate models config file and takes effect immediately without restarting. Requires SSH access (Tier 2+).

## Multiple Providers

You can set multiple provider API keys. The agent will use whichever provider matches the model you specify.

## OAuth Providers

Some providers require OAuth or interactive login instead of API keys — see the "Providers That Need Custom Config" table above. These require SSH access (Tier 2+). All API-key providers work at Tier 0.

## Cost Considerations

Costs vary significantly by provider, model, and how much you use the agent. There's no universal answer to "how much will this cost?"

**What you should do:**
- Check your provider's pricing page before choosing a model
- Set spending limits or alerts in your provider's dashboard — most providers support this
- Monitor your usage for the first few days to establish a baseline

**Cost optimization:**
- Use a cheaper/faster model for `LLM_HEARTBEAT_MODEL` (periodic check-ins don't need your smartest model)
- Use a balanced model for `LLM_SUBAGENT_MODEL` (Tier 3) — subagents do focused tasks, not open-ended conversation
- Aggregators like OpenRouter let you compare pricing across providers for the same model family

## Troubleshooting

### "API key not found"
Ensure the environment variable is set in Railway Dashboard.

### "Model not found" / "Unknown model"
Check the model name format matches your provider's expectations. OpenClaw validates models against an internal registry — very new models may not be recognized until OpenClaw updates. At Tier 2+, you can define custom models via `models.providers` in the config. See [OpenClaw Model Providers](https://docs.openclaw.ai/concepts/model-providers) for details.

### Switching providers
Update the environment variable and redeploy, or SSH in and update the config.

## Further Reading

- [OpenClaw Providers Docs](https://docs.openclaw.ai/providers)
- [OpenClaw Configuration](https://docs.openclaw.ai/gateway/configuration)
