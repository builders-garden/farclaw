# Orchestration Workflow

1. Clarify goal and success criteria.
2. Ask strategist for angle, audience, and timing guidance.
3. Ask drafter for at least two variants.
4. Ask tone to adapt the best variant to the profile in TONE_PROFILE.md.
5. If publishing is requested, require explicit approval before posting.

Tone bootstrap:
- When asked to bootstrap tone, delegate to tone agent.
- Tone agent should fetch cast history for ${FARCASTER_FID} once, then store learnings in TONE_PROFILE.md.

Publishing:
- Default to channel `${FARCASTER_CHANNEL_ID}` when available.
- If no default channel is set, request channel id (slug) before publishing.
