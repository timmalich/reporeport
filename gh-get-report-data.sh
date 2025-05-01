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
  local output_file="$BUILD_DIR/${ORG}_${REPONAME}_codeowners.json"
  gh api --hostname "$HOSTNAME" repos/"$ORG"/"$REPONAME"/contents/.github/CODEOWNERS \
    --jq '.' \
    > "$output_file" \
    || echo '{}' > "$output_file"
}

fetch_commits() {
  local output_file="$BUILD_DIR/${ORG}_${REPONAME}_latest_commit.json"
  gh api --hostname "$HOSTNAME" repos/"$ORG"/"$REPONAME"/commits \
    --jq '.[0]' \
    > $output_file \
    || echo '{}' > "$output_file"
}

fetch_languages() {
  local output_file="$BUILD_DIR/${ORG}_${REPONAME}_languages.json"
  gh api --hostname "$HOSTNAME" repos/"$ORG"/"$REPONAME"/languages \
    --jq '.' \
    > $output_file\
    || echo '{}' > "$output_file"
}

fetch_contributors() {
  local output_file="$BUILD_DIR/${ORG}_${REPONAME}_contributors.json"
  # sorted by contributions desc
  gh api --hostname "$HOSTNAME" repos/"$ORG"/"$REPONAME"/contributors \
    > $output_file\
    || echo '[]' > "$output_file"
}
#############################################

for ORG in "${ORGS[@]}"; do
  echo "▶️ Fetching repo list for $ORG…"
  GH_HOST=$HOSTNAME gh repo list "$ORG" \
    --limit 1000 \
    --json name,url,description \
    > "$BUILD_DIR/${ORG}_repolist.json"

  jq -r '.[].name' "$BUILD_DIR/${ORG}_repolist.json" | while read -r REPONAME; do
    echo "   ↳ $ORG/$REPONAME → CODEOWNERS"
    fetch_codeowners
    fetch_commits
    fetch_languages
    fetch_contributors
  done
done

echo "✅ All data fetched under '$BUILD_DIR/'"
