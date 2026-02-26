# Farclaw

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/qvhYVc?referralCode=ZUrs1W&utm_medium=integration&utm_source=template&utm_campaign=generic)

Deploy link: https://railway.com/deploy/qvhYVc?referralCode=ZUrs1W&utm_medium=integration&utm_source=template&utm_campaign=generic

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

## Railway deploy (step-by-step)

1. Click the deploy button above (or use the direct link) and create a new Railway project.
2. Add a persistent volume and mount it at `/data`.
3. Confirm service port is `8080` and set:
   - `PORT=8080`
4. Fill required provider secrets:
   - `OPENROUTER_API_KEY` from OpenRouter Keys: https://openrouter.ai/keys
   - `TELEGRAM_BOT_TOKEN` from BotFather: https://t.me/BotFather
   - BotFather setup guide: https://core.telegram.org/bots#6-botfather
   - `NEYNAR_API_KEY` from Neynar dashboard: https://neynar.com/
   - `NEYNAR_SIGNER_UUID` (create signer + approve once): https://docs.neynar.com/docs/write-to-farcaster-with-signer
5. Set optional but recommended Farcaster identity fields:
   - `FARCASTER_HANDLE` (without `@`)
   - `FARCASTER_FID` (your numeric FID)
   - `FARCASTER_CHANNEL_ID` (default channel slug)
6. Set security/config variables:
   - `SETUP_PASSWORD=${secret(32)}`
   - `OPENCLAW_GATEWAY_TOKEN=${secret(64)}`
   - `TELEGRAM_ALLOWED_USER_ID=<your telegram numeric user id>` (recommended)
7. Add `RAILWAY_DOMAIN` to your generated Railway domain (no `https://`).
8. Deploy, then open logs and confirm boot finished without missing env errors.
9. Pair Telegram if prompted:

```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

10. Send a DM to your bot and test:
   - content planning
   - draft generation
   - publish approval flow

## Safety defaults

- Orchestrator is the only agent with write actions.
- Publishing should happen only after explicit approval.
- Tone history fetch is one-off bootstrap, not per-request.
