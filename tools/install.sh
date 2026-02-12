#!/usr/bin/env bash
set -euo pipefail

# Skill Manager — Install an approved skill from GitHub
# Usage: install.sh <skill_name> [scope]
#
# Scope:
#   shared (default)  — installs to ~/.openclaw/skills/<name>/
#   agent:<name>      — installs to ~/.openclaw/workspaces/<agent>/skills/<name>/
#
# Resolves the GitHub repo URL from pending.json, or defaults to
# FutureHax/openclaw-skill-<name>.

SKILL_NAME="${1:?Usage: install.sh <skill_name> [scope]}"
SCOPE="${2:-shared}"

GITHUB_ORG="FutureHax"
REPO_NAME="openclaw-skill-${SKILL_NAME}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PENDING_FILE="$HOME/.openclaw/skill-manager/pending.json"

# --- Resolve target directory ---

case "$SCOPE" in
  shared)
    target_dir="$HOME/.openclaw/skills/${SKILL_NAME}"
    ;;
  agent:*)
    agent_name="${SCOPE#agent:}"
    target_dir="$HOME/.openclaw/workspaces/${agent_name}/skills/${SKILL_NAME}"
    ;;
  *)
    echo "{\"error\":\"Invalid scope: ${SCOPE}. Use 'shared' or 'agent:<name>'.\"}" >&2
    exit 1
    ;;
esac

# --- Check if already installed ---

if [[ -d "$target_dir" ]] && [[ -f "$target_dir/SKILL.md" ]]; then
  echo "{\"error\":\"Skill '${SKILL_NAME}' is already installed at ${target_dir}.\"}" >&2
  exit 1
fi

# --- Resolve repo URL from pending list or default ---

repo_slug=""
if [[ -f "$PENDING_FILE" ]]; then
  repo_slug=$(python3 -c "
import json
data = json.load(open('$PENDING_FILE'))
for s in data.get('pending', []):
    if s['name'] == '$SKILL_NAME':
        print(s['repo'])
        break
" 2>/dev/null || true)
fi

if [[ -z "$repo_slug" ]]; then
  repo_slug="${GITHUB_ORG}/${REPO_NAME}"
fi

repo_url="https://github.com/${repo_slug}.git"

# --- Clone and install ---

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

if ! git clone -q "$repo_url" "$work_dir/skill" 2>/dev/null; then
  echo "{\"error\":\"Failed to clone ${repo_url}. Check that the repo exists and is accessible.\"}" >&2
  exit 1
fi

# Create target parent directory
mkdir -p "$(dirname "$target_dir")"

# Copy skill files (exclude .git)
cp -r "$work_dir/skill" "$target_dir"
rm -rf "$target_dir/.git"

# --- Remove from pending ---

bash "$SCRIPT_DIR/pending.sh" remove "$SKILL_NAME" > /dev/null 2>&1 || true

# --- Output result ---

cat << EOF
{
  "status": "installed",
  "name": "${SKILL_NAME}",
  "path": "${target_dir}",
  "scope": "${SCOPE}",
  "repo": "${repo_slug}",
  "note": "Restart the gateway to activate: openclaw gateway restart"
}
EOF
