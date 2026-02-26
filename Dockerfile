FROM coollabsio/openclaw:latest

RUN apt-get update && apt-get install -y --no-install-recommends curl jq gettext-base && rm -rf /var/lib/apt/lists/*

# Railway runs a single container and does not provide the compose "browser" sidecar.
# Patch upstream entrypoint so generated nginx config never references browser.
RUN <<'EOF'
set -eu
cat > /tmp/remove-browser.awk <<'AWK'
BEGIN { skip = 0; depth = 0 }
{
  line = $0

  if (skip == 0 && line ~ /^[[:space:]]*upstream[[:space:]]+browser[[:space:]]*\{[[:space:]]*$/) {
    skip = 1
    depth = 1
    next
  }

  if (skip == 0 && line ~ /^[[:space:]]*location[[:space:]]+\/browser\/[[:space:]]*\{[[:space:]]*$/) {
    skip = 1
    depth = 1
    next
  }

  if (skip == 1) {
    opens = gsub(/\{/, "{", line)
    closes = gsub(/\}/, "}", line)
    depth += (opens - closes)
    if (depth <= 0) {
      skip = 0
      depth = 0
    }
    next
  }

  if (line ~ /proxy_pass[[:space:]]+http:\/\/browser([:][0-9]+)?\//) {
    next
  }

  if (line ~ /proxy_pass[[:space:]]+http:\/\/browser([[:space:]]*;|[[:space:]])/) {
    next
  }

  print $0
}
AWK
awk -f /tmp/remove-browser.awk /app/scripts/entrypoint.sh > /tmp/entrypoint.sh
mv /tmp/entrypoint.sh /app/scripts/entrypoint.sh
rm -f /tmp/remove-browser.awk
chmod +x /app/scripts/entrypoint.sh
EOF

COPY config/ /opt/farclaw-config/
COPY workspaces/ /opt/farclaw-workspaces/
COPY shared/ /opt/farclaw-shared/
COPY openclaw-init.sh /opt/openclaw-init.sh

RUN chmod +x /opt/openclaw-init.sh

ENTRYPOINT ["/bin/sh", "/opt/openclaw-init.sh"]
