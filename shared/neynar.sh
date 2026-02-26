#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.clawdbot/skills/neynar/config.json"
API_BASE="https://api.neynar.com/v2/farcaster"
DEFAULT_CHANNEL_ID="${FARCASTER_CHANNEL_ID:-}"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: Config not found at $CONFIG_FILE" >&2
  exit 1
fi

API_KEY=$(jq -r '.apiKey // empty' "$CONFIG_FILE")
SIGNER_UUID=$(jq -r '.signerUuid // empty' "$CONFIG_FILE")

if [[ -z "$API_KEY" ]]; then
  echo "Error: apiKey not set in config" >&2
  exit 1
fi

api_get() {
  local endpoint="$1"
  curl -sf -H "x-api-key: $API_KEY" -H "Content-Type: application/json" "${API_BASE}${endpoint}"
}

api_post() {
  local endpoint="$1"
  local data="$2"
  curl -sf -X POST -H "x-api-key: $API_KEY" -H "Content-Type: application/json" --data-binary @- "${API_BASE}${endpoint}" <<< "$data"
}

require_signer() {
  if [[ -z "$SIGNER_UUID" ]]; then
    echo "Error: This command requires signerUuid in config" >&2
    exit 1
  fi
}

cmd_user() {
  local identifier="${1:-}"
  [[ -z "$identifier" ]] && { echo "Usage: neynar.sh user <username|fid>" >&2; exit 1; }
  if [[ "$identifier" =~ ^[0-9]+$ ]]; then
    api_get "/user/bulk?fids=$identifier" | jq '.users[0]'
  else
    api_get "/user/by_username?username=$identifier" | jq '.user'
  fi
}

cmd_feed() {
  local mode="${1:-}"; shift || true
  case "$mode" in
    --user)
      api_get "/feed/user/casts?fid=${1:?missing fid}&limit=${2:-20}" | jq '.casts'
      ;;
    --channel)
      api_get "/feed/channels?channel_ids=${1:?missing channel}&limit=${2:-20}" | jq '.casts'
      ;;
    --trending)
      api_get "/feed/trending?limit=${1:-20}" | jq '.casts'
      ;;
    *)
      echo "Usage: neynar.sh feed --user <fid> [limit] | --channel <channelId> [limit] | --trending [limit]" >&2
      exit 1
      ;;
  esac
}

cmd_search() {
  local query="${1:-}"
  [[ -z "$query" ]] && { echo "Usage: neynar.sh search <query> [channelId]" >&2; exit 1; }
  local channel="${2:-}"
  local endpoint="/cast/search?q=$(echo "$query" | jq -Rr @uri)&limit=20"
  if [[ -n "$channel" ]]; then
    endpoint="${endpoint}&channel_id=${channel}"
  fi
  api_get "$endpoint" | jq '.result.casts'
}

cmd_cast() {
  local hash="${1:-}"
  [[ -z "$hash" ]] && { echo "Usage: neynar.sh cast <hash>" >&2; exit 1; }
  api_get "/cast?type=hash&identifier=$hash" | jq '.cast'
}

cmd_post() {
  require_signer
  local text="${1:-}"
  local channel_id="${2:-$DEFAULT_CHANNEL_ID}"
  [[ -z "$text" ]] && { echo "Usage: neynar.sh post <text> [channelId]" >&2; exit 1; }
  local data
  data=$(jq -n \
    --arg signer "$SIGNER_UUID" \
    --arg text "$text" \
    --arg channel "$channel_id" \
    '{signer_uuid:$signer,text:$text}
      + (if $channel == "" then {} else {channel_id:$channel} end)')
  api_post "/cast" "$data" | jq
}

cmd_reply() {
  require_signer
  local parent="${1:-}"
  local text="${2:-}"
  local channel_id="${3:-$DEFAULT_CHANNEL_ID}"
  local parent_author_fid="${4:-}"

  [[ -z "$parent" || -z "$text" ]] && {
    echo "Usage: neynar.sh reply <parentHashOrUrl> <text> [channelId] [parentAuthorFid]" >&2
    exit 1
  }

  local data
  data=$(jq -n \
    --arg signer "$SIGNER_UUID" \
    --arg text "$text" \
    --arg channel "$channel_id" \
    --arg parent "$parent" \
    --arg paf "$parent_author_fid" \
    '{signer_uuid:$signer,text:$text,parent:$parent}
      + (if $channel == "" then {} else {channel_id:$channel} end)
      + (if $paf == "" then {} else {parent_author_fid: ($paf | tonumber)} end)')

  api_post "/cast" "$data" | jq
}

cmd_like() {
  require_signer
  local hash="${1:-}"
  [[ -z "$hash" ]] && { echo "Usage: neynar.sh like <hash>" >&2; exit 1; }
  local data
  data=$(jq -n --arg signer "$SIGNER_UUID" --arg target "$hash" '{signer_uuid:$signer,reaction_type:"like",target:$target}')
  api_post "/reaction" "$data" | jq
}

cmd_recast() {
  require_signer
  local hash="${1:-}"
  [[ -z "$hash" ]] && { echo "Usage: neynar.sh recast <hash>" >&2; exit 1; }
  local data
  data=$(jq -n --arg signer "$SIGNER_UUID" --arg target "$hash" '{signer_uuid:$signer,reaction_type:"recast",target:$target}')
  api_post "/reaction" "$data" | jq
}

case "${1:-}" in
  user) shift; cmd_user "$@" ;;
  feed) shift; cmd_feed "$@" ;;
  search) shift; cmd_search "$@" ;;
  cast) shift; cmd_cast "$@" ;;
  post) shift; cmd_post "$@" ;;
  reply) shift; cmd_reply "$@" ;;
  like) shift; cmd_like "$@" ;;
  recast) shift; cmd_recast "$@" ;;
  *)
    echo "Usage: neynar.sh {user|feed|search|cast|post|reply|like|recast} ..." >&2
    exit 1
    ;;
esac
