# Neynar Skill - Orchestrator

This agent has read and write Farcaster access.

Available commands:
- `user <username|fid>`
- `feed --user <fid> [limit]`
- `feed --channel <channelId> [limit]`
- `search <query> [channelId]`
- `cast <hash>`
- `post <text> [channelId]`
- `reply <parentHashOrUrl> <text> [channelId] [parentAuthorFid]`
- `like <hash>`
- `recast <hash>`

Policy:
- Ask for explicit approval before `post` or `reply`.
- Use `${FARCASTER_CHANNEL_ID}` only as a default when present.
