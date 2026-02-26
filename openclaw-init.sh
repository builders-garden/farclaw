#!/bin/sh
set -eu

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
CONFIG_DIR="${STATE_DIR}"

PROJECT_NAME="${PROJECT_NAME:-Farclaw}"
PRIMARY_MODEL="${PRIMARY_MODEL:-openrouter/moonshotai/kimi-k2.5}"
FALLBACK_MODEL="${FALLBACK_MODEL:-openrouter/anthropic/claude-haiku-4.5}"

export PROJECT_NAME PRIMARY_MODEL FALLBACK_MODEL
export FARCASTER_HANDLE="${FARCASTER_HANDLE:-}"
export FARCASTER_FID="${FARCASTER_FID:-}"
export FARCASTER_CHANNEL_ID="${FARCASTER_CHANNEL_ID:-}"

# The upstream image expects AUTH_PASSWORD for nginx basic auth.
# Map SETUP_PASSWORD to AUTH_PASSWORD when AUTH_PASSWORD is not set.
if [ -z "${AUTH_PASSWORD:-}" ] && [ -n "${SETUP_PASSWORD:-}" ]; then
  export AUTH_PASSWORD="${SETUP_PASSWORD}"
fi

mkdir -p "${CONFIG_DIR}" "/data"

template_vars='${PROJECT_NAME} ${PRIMARY_MODEL} ${FALLBACK_MODEL} ${FARCASTER_HANDLE} ${FARCASTER_FID} ${FARCASTER_CHANNEL_ID}'

# Render the OpenClaw config from template only on first boot.
# Keep existing config to avoid resetting gateway auth/device pairing state.
if [ ! -s "${CONFIG_DIR}/openclaw.json" ]; then
  envsubst "$template_vars" < /opt/farclaw-config/openclaw.template.json > "${CONFIG_DIR}/openclaw.json"
fi

# Patch optional runtime config values.
OPENCLAW_CONFIG_PATH="${CONFIG_DIR}/openclaw.json" \
TELEGRAM_ALLOWED_USER_ID="${TELEGRAM_ALLOWED_USER_ID:-}" \
RAILWAY_DOMAIN="${RAILWAY_DOMAIN:-}" \
node <<'EOF'
const fs = require("fs");

const configPath = process.env.OPENCLAW_CONFIG_PATH;
if (!configPath || !fs.existsSync(configPath)) {
  process.exit(0);
}

const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

const userId = (process.env.TELEGRAM_ALLOWED_USER_ID || "").replace(/\s+/g, "").trim();
config.channels = config.channels || {};
config.channels.telegram = config.channels.telegram || {};
if (userId) {
  config.channels.telegram.dmPolicy = "allowlist";
  config.channels.telegram.allowFrom = [userId];
} else {
  config.channels.telegram.dmPolicy = "paired";
  config.channels.telegram.allowFrom = [];
}

const rawDomain = (process.env.RAILWAY_DOMAIN || "").trim();
const domain = rawDomain.replace(/^https?:\/\//, "").replace(/\/$/, "");
config.gateway = config.gateway || {};
config.gateway.controlUi = config.gateway.controlUi || {};
config.gateway.controlUi.allowedOrigins = domain ? [`https://${domain}`] : [];

fs.writeFileSync(configPath, `${JSON.stringify(config, null, 2)}\n`, "utf8");
EOF

copy_workspace_if_missing() {
  src="$1"
  dst="$2"
  if [ ! -d "$dst" ]; then
    mkdir -p "$dst"
    cp -R "$src"/* "$dst"/
  fi
}

render_markdown_templates() {
  ws_dir="$1"
  for file in "$ws_dir"/*.md "$ws_dir"/skills/*/SKILL.md; do
    if [ -f "$file" ] && grep -q '\${' "$file"; then
      tmp_file="${file}.tmp"
      envsubst "$template_vars" < "$file" > "$tmp_file"
      mv "$tmp_file" "$file"
    fi
  done
}

# Railway single-container deploy does not provide a separate "browser" sidecar.
# Patch generated nginx config as a runtime safety net.
patch_nginx_browser_refs() {
  conf="/etc/nginx/conf.d/openclaw.conf"
  if [ ! -f "$conf" ]; then
    return 0
  fi

  tmp_file="${conf}.tmp"

  awk '
    BEGIN {
      in_upstream_browser = 0
      in_browser_location = 0
      depth = 0
    }
    {
      line = $0

      if (in_upstream_browser == 0 && in_browser_location == 0 && line ~ /^[[:space:]]*upstream[[:space:]]+browser[[:space:]]*\{/) {
        in_upstream_browser = 1
        depth = 1
        next
      }

      if (in_upstream_browser == 0 && in_browser_location == 0 && line ~ /^[[:space:]]*location[[:space:]]+\/browser\/[[:space:]]*\{/) {
        in_browser_location = 1
        depth = 1
        next
      }

      if (in_upstream_browser == 1 || in_browser_location == 1) {
        opens = gsub(/\{/, "{", line)
        closes = gsub(/\}/, "}", line)
        depth += (opens - closes)
        if (depth <= 0) {
          in_upstream_browser = 0
          in_browser_location = 0
          depth = 0
        }
        next
      }

      if (line ~ /proxy_pass[[:space:]]+http:\/\/browser/) {
        next
      }

      print line
    }
  ' "$conf" > "$tmp_file" && mv "$tmp_file" "$conf"
}

copy_workspace_if_missing /opt/farclaw-workspaces/orchestrator /data/workspace-orchestrator
copy_workspace_if_missing /opt/farclaw-workspaces/strategist /data/workspace-strategist
copy_workspace_if_missing /opt/farclaw-workspaces/drafter /data/workspace-drafter
copy_workspace_if_missing /opt/farclaw-workspaces/tone /data/workspace-tone
copy_workspace_if_missing /opt/farclaw-workspaces/engager /data/workspace-engager

render_markdown_templates /data/workspace-orchestrator
render_markdown_templates /data/workspace-strategist
render_markdown_templates /data/workspace-drafter
render_markdown_templates /data/workspace-tone
render_markdown_templates /data/workspace-engager

# Keep the project knowledge shared across all workspaces.
if [ -f /data/workspace-orchestrator/KNOWLEDGE.md ]; then
  cp /data/workspace-orchestrator/KNOWLEDGE.md /data/workspace-strategist/KNOWLEDGE.md
  cp /data/workspace-orchestrator/KNOWLEDGE.md /data/workspace-drafter/KNOWLEDGE.md
  cp /data/workspace-orchestrator/KNOWLEDGE.md /data/workspace-tone/KNOWLEDGE.md
  cp /data/workspace-orchestrator/KNOWLEDGE.md /data/workspace-engager/KNOWLEDGE.md
fi

# Share canonical tone artifacts across writing agents without overwriting source files.
ln -sfn /data/workspace-orchestrator/TONE_PROFILE.md /data/workspace-tone/TONE_PROFILE.md
ln -sfn /data/workspace-orchestrator/TONE_PROFILE.md /data/workspace-drafter/TONE_PROFILE.md
ln -sfn /data/workspace-orchestrator/TONE_PROFILE.md /data/workspace-engager/TONE_PROFILE.md

ln -sfn /data/workspace-orchestrator/STYLE_GUIDE.md /data/workspace-tone/STYLE_GUIDE.md
ln -sfn /data/workspace-orchestrator/STYLE_GUIDE.md /data/workspace-drafter/STYLE_GUIDE.md
ln -sfn /data/workspace-orchestrator/STYLE_GUIDE.md /data/workspace-engager/STYLE_GUIDE.md

for ws in orchestrator strategist tone engager; do
  mkdir -p "/data/workspace-${ws}/skills/neynar/scripts"
  cp /opt/farclaw-shared/neynar.sh "/data/workspace-${ws}/skills/neynar/scripts/neynar.sh"
  chmod +x "/data/workspace-${ws}/skills/neynar/scripts/neynar.sh"
done

for ws in orchestrator strategist drafter tone engager; do
  mkdir -p "/data/workspace-${ws}/skills/web/scripts"
  cp /opt/farclaw-shared/web_scrape.sh "/data/workspace-${ws}/skills/web/scripts/web_scrape.sh"
  chmod +x "/data/workspace-${ws}/skills/web/scripts/web_scrape.sh"
done

mkdir -p /root/.clawdbot/skills/neynar
cat > /root/.clawdbot/skills/neynar/config.json <<EOF
{
  "apiKey": "${NEYNAR_API_KEY:-}",
  "signerUuid": "${NEYNAR_SIGNER_UUID:-}"
}
EOF

mkdir -p /home/node/.clawdbot/skills/neynar || true
cat > /home/node/.clawdbot/skills/neynar/config.json <<EOF
{
  "apiKey": "${NEYNAR_API_KEY:-}",
  "signerUuid": "${NEYNAR_SIGNER_UUID:-}"
}
EOF

mkdir -p /data/.clawdbot/skills/neynar
cat > /data/.clawdbot/skills/neynar/config.json <<EOF
{
  "apiKey": "${NEYNAR_API_KEY:-}",
  "signerUuid": "${NEYNAR_SIGNER_UUID:-}"
}
EOF

patch_nginx_browser_refs

exec /app/scripts/entrypoint.sh
