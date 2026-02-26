#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage:
  web_scrape.sh <url> [--mode auto|direct|jina] [--output <file>]

Modes:
  auto   Try direct fetch first, fallback to jina.ai reader when blocked by JS
  direct Fetch URL directly with curl
  jina   Fetch via r.jina.ai reader endpoint (great for JS-heavy pages)

Examples:
  scripts/web_scrape.sh https://example.com
  scripts/web_scrape.sh https://farcaster.xyz/~/channel/dev --mode jina
  scripts/web_scrape.sh https://example.com --output /tmp/page.txt
EOF
}

is_blocked_page() {
  body="$1"
  case "$body" in
    *"enable JavaScript"*|*"You need to enable JavaScript"*|*"Please enable JavaScript"*|*"JavaScript must be enabled"*|*"Access denied"*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

to_jina_url() {
  input_url="$1"
  case "$input_url" in
    https://*)
      printf '%s' "https://r.jina.ai/http://${input_url#https://}"
      ;;
    http://*)
      printf '%s' "https://r.jina.ai/http://${input_url#http://}"
      ;;
    *)
      printf '%s' "https://r.jina.ai/http://$input_url"
      ;;
  esac
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

if [ "$#" -lt 1 ]; then
  usage
  exit 1
fi

URL="$1"
shift

MODE="auto"
OUTFILE=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --output)
      OUTFILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

case "$MODE" in
  auto|direct|jina)
    ;;
  *)
    printf 'Invalid mode: %s (use auto, direct, or jina)\n' "$MODE" >&2
    exit 1
    ;;
esac

fetch_direct() {
  curl -fsSL --max-time 30 -A "Mozilla/5.0 (compatible; ${PROJECT_NAME:-Farclaw}Bot/1.0)" "$URL"
}

fetch_jina() {
  jina_url="$(to_jina_url "$URL")"
  curl -fsSL --max-time 45 -A "Mozilla/5.0 (compatible; ${PROJECT_NAME:-Farclaw}Bot/1.0)" "$jina_url"
}

RESULT=""

if [ "$MODE" = "direct" ]; then
  RESULT="$(fetch_direct)"
elif [ "$MODE" = "jina" ]; then
  RESULT="$(fetch_jina)"
else
  DIRECT_RESULT="$(fetch_direct || true)"
  if [ -n "$DIRECT_RESULT" ] && ! is_blocked_page "$DIRECT_RESULT"; then
    RESULT="$DIRECT_RESULT"
  else
    RESULT="$(fetch_jina)"
  fi
fi

if [ -n "$OUTFILE" ]; then
  printf '%s\n' "$RESULT" > "$OUTFILE"
  printf 'Saved content to %s\n' "$OUTFILE"
else
  printf '%s\n' "$RESULT"
fi
