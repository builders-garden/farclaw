# Farclaw

Open-source OpenClaw template for running a 5-agent Farcaster content team with Telegram control.

## What you get

- Opinionated multi-agent setup:
  - `orchestrator` (routes work, publishes after approval)
  - `strategist` (content planning)
  - `drafter` (draft variants)
  - `tone` (tone bootstrap and adaptation)
  - `engager` (reply opportunity scouting)
- Telegram inbound routing to orchestrator
- Neynar skill for Farcaster read/write workflows
- Web scraping skill with JS fallback
- Docker + Railway-friendly deployment

## Quick start (local)

1. Copy env file:

```bash
cp .env.example .env
```

2. Fill required env vars:
- `OPENROUTER_API_KEY`
- `TELEGRAM_BOT_TOKEN`
- `NEYNAR_API_KEY`
- `NEYNAR_SIGNER_UUID`

3. Optional but recommended:
- `PROJECT_NAME`
- `FARCASTER_HANDLE`
- `FARCASTER_FID`
- `FARCASTER_CHANNEL_ID` (optional default channel slug)
- `TELEGRAM_ALLOWED_USER_ID` (restrict who can DM the bot)

4. Start:

```bash
docker compose up --build
```

5. Pair your Telegram user (if needed):

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

## Environment variables

See `.env.example` for full list. Key customization points:

- `PROJECT_NAME`: shown in agent naming and scraper user-agent
- `FARCASTER_FID`: source account used for one-off tone bootstrap
- `FARCASTER_CHANNEL_ID`: default channel slug used for publish/reply when set
- `PRIMARY_MODEL` / `FALLBACK_MODEL`: OpenRouter model selection
- `RAILWAY_DOMAIN`: optional control UI CORS origin (without scheme)

## Customizing project knowledge

Edit `workspaces/orchestrator/KNOWLEDGE.md` with your domain facts and messaging.

At startup, this file is synced to all agent workspaces so every agent shares the same context.

## Tone profile bootstrap

Ask the orchestrator:

"Bootstrap tone profile from my cast history (FID <your fid>)."

The tone agent should fetch historical casts once and write guidance to `TONE_PROFILE.md`.

## Railway deploy

1. Create a Railway project from this repo.
2. Add a volume mounted at `/data`.
3. Set `PORT=8080` and required env vars.
4. Expose HTTP on port `8080`.

## Safety defaults

- Orchestrator is the only agent with write actions.
- Publishing should happen only after explicit approval.
- Tone history fetch is one-off bootstrap, not per-request.
