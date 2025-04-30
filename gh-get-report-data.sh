#!/usr/bin/env bash
set -euo pipefail

CONFIG="gh-report-config.json"
BUILD_DIR="build"

HOSTNAME=$(jq -r '.hostname' "$CONFIG")
ORGS=( $(jq -r '.organizations | map(keys[]) | .[]' "$CONFIG") )

if ! gh auth status --hostname "$HOSTNAME" &>/dev/null; then
  echo "🔑 GitHub CLI authentication required for $HOSTNAME."
  gh auth login
fi

mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

#############################################
# Functions that run on every repo found
#############################################
fetch_codeowners() {
  local org="$1"
  local repo="$2"
  local output_file="$3"

  gh api repos/"$org"/"$REPONAME"/contents/.github/CODEOWNERS \
    --jq '.' \
    > "$output_file" \
    || echo '{}' > "$output_file"
}
#############################################

for ORG in "${ORGS[@]}"; do
  echo "▶️ Fetching repo list for $ORG…"
  gh repo list "$ORG" \
    --limit 1000 \
    --json name,url,description \
    > "$BUILD_DIR/${ORG}_repolist.json"

  jq -r '.[].name' "$BUILD_DIR/${ORG}_repolist.json" | while read -r REPONAME; do
    echo "   ↳ $ORG/$REPONAME → CODEOWNERS"
    fetch_codeowners "$ORG" "$REPONAME" "$BUILD_DIR/${ORG}_${REPONAME}_codeowners.json"
  done
done

echo "✅ All data fetched under '$BUILD_DIR/'"
