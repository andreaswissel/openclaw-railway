# =============================================================================
# HARDENED MOLTBOT RAILWAY TEMPLATE
# Multi-stage build with non-root user, pnpm, and Claude CLI
# =============================================================================

# -----------------------------------------------------------------------------
# Stage 1: Build Moltbot from source
# -----------------------------------------------------------------------------
FROM node:22-bookworm AS moltbot-build

# Build dependencies
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
    curl \
    python3 \
    make \
    g++ \
  && rm -rf /var/lib/apt/lists/*

# Install Bun (moltbot build uses it)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH="/root/.bun/bin:${PATH}"

RUN corepack enable

WORKDIR /moltbot

# Pin to a known ref (tag/branch). Fall back to main if not specified.
ARG MOLTBOT_GIT_REF=main
RUN git clone --depth 1 --branch "${MOLTBOT_GIT_REF}" https://github.com/moltbot/moltbot.git .

# Patch: relax version requirements for packages that may reference unpublished versions
RUN set -eux; \
  find ./extensions -name 'package.json' -type f | while read -r f; do \
    sed -i -E 's/"moltbot"[[:space:]]*:[[:space:]]*">=[^"]+"/"moltbot": "*"/g' "$f"; \
    sed -i -E 's/"moltbot"[[:space:]]*:[[:space:]]*"workspace:[^"]+"/"moltbot": "*"/g' "$f"; \
  done

RUN pnpm install --no-frozen-lockfile
RUN pnpm build
ENV MOLTBOT_PREFER_PNPM=1
RUN pnpm ui:install && pnpm ui:build


# -----------------------------------------------------------------------------
# Stage 2: Runtime image (hardened)
# -----------------------------------------------------------------------------
FROM oven/bun:1-debian AS runtime

ENV NODE_ENV=production

# Install runtime dependencies + tools for administration
RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    jq \
    vim-tiny \
    less \
    procps \
    htop \
  && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for moltbot CLI) and pnpm (required for moltbot update)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y nodejs \
  && corepack enable && corepack prepare pnpm@latest --activate \
  && rm -rf /var/lib/apt/lists/*

# Create non-root user with specific UID for security
# Using uid 1001 to avoid conflicts with common system users
RUN groupadd -g 1001 moltbot \
  && useradd -u 1001 -g moltbot -m -s /bin/bash moltbot

# Create data directory structure
RUN mkdir -p /data/.moltbot /data/workspace /data/core \
  && chown -R moltbot:moltbot /data

# Copy built moltbot from build stage
COPY --from=moltbot-build /moltbot /moltbot
RUN chown -R moltbot:moltbot /moltbot

# Create moltbot CLI wrapper (uses Node for moltbot itself)
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /moltbot/dist/entry.js "$@"' > /usr/local/bin/moltbot \
  && chmod +x /usr/local/bin/moltbot

# Install Claude Code CLI for setup-token (creates 1-year tokens)
RUN pnpm add -g @anthropic-ai/claude-code

# Set up wrapper application
WORKDIR /app

# Copy wrapper dependencies and install with bun
COPY package.json ./
RUN bun install --production

# Copy wrapper source
COPY src ./src
COPY config ./config

# Set ownership
RUN chown -R moltbot:moltbot /app

# Switch to non-root user
USER moltbot

# Environment defaults
ENV MOLTBOT_STATE_DIR=/data/.moltbot
ENV MOLTBOT_WORKSPACE_DIR=/data/workspace
ENV MOLTBOT_CORE_DIR=/data/core
ENV MOLTBOT_PUBLIC_PORT=8080
ENV PORT=8080
ENV INTERNAL_GATEWAY_PORT=18789

# Add moltbot user's local bin to PATH (for claude CLI)
ENV PATH="/home/moltbot/.local/bin:/usr/local/bin:${PATH}"

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -sf http://localhost:8080/setup/healthz || exit 1

EXPOSE 8080

# Start wrapper server with Bun
CMD ["bun", "run", "src/server.js"]
