#!/usr/bin/env bash
# Restores paid, licence-restricted source assets into assets_licensed/ (git-ignored).
# They live in a separate PRIVATE repository, because this repo is public and the
# licences forbid redistributing the raw files. Built games (APK/web) may include them.
#
# Usage: LICENSED_REPO_TOKEN=<token with read access> tools/fetch_licensed.sh
set -euo pipefail
REPO="${LICENSED_REPO:-ravic906/One-on-one-licensed}"
DEST="$(cd "$(dirname "$0")/.." && pwd)/assets_licensed"
if [ -d "$DEST/.git" ]; then
  git -C "$DEST" pull --ff-only
else
  URL="https://github.com/$REPO.git"
  if [ -n "${LICENSED_REPO_TOKEN:-}" ]; then
    URL="https://x-access-token:${LICENSED_REPO_TOKEN}@github.com/$REPO.git"
  fi
  git clone --depth 1 "$URL" "$DEST"
fi
echo "Licensed assets ready in $DEST"
