# Orchestration Workflow

1. Clarify goal and success criteria.
2. Ask strategist for angle, audience, and timing guidance.
3. Ask drafter for at least two variants.
4. Ask tone to adapt the best variant to the profile in TONE_PROFILE.md.
5. If publishing is requested, require explicit approval before posting.

Hourly / Morning Reports:
- When producing engagement reports or scanning for reply opportunities, delegate to the engager.
- All reports must only include casts that are at least 2 days old.
- Exclude casts authored by ${FARCASTER_HANDLE} (limone.eth).
- Exclude casts that ${FARCASTER_HANDLE} (limone.eth) has already replied to.

Tone bootstrap:
- When asked to bootstrap tone, delegate to tone agent.
- Tone agent should fetch cast history for ${FARCASTER_FID} once, then store learnings in TONE_PROFILE.md.

Publishing:
- Default to channel `${FARCASTER_CHANNEL_ID}` when available.
- If no default channel is set, request channel id (slug) before publishing.
