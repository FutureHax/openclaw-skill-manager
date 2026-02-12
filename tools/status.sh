#!/usr/bin/env bash
set -euo pipefail

# Skill Manager — Check if a skill exists
# Usage: status.sh <skill_name>
#
# Checks three locations:
#   1. Installed locally (~/.openclaw/skills/ and workspace skill dirs)
#   2. Exists on GitHub (FutureHax/openclaw-skill-<name>)
#   3. In the pending installation list

SKILL_NAME="${1:?Usage: status.sh <skill_name>}"

GITHUB_ORG="FutureHax"
REPO_NAME="openclaw-skill-${SKILL_NAME}"
PENDING_FILE="$HOME/.openclaw/skill-manager/pending.json"

# --- Check installed locally ---

installed=false
paths=()

# Shared skills directory
if [[ -f "$HOME/.openclaw/skills/${SKILL_NAME}/SKILL.md" ]]; then
  installed=true
  paths+=("$HOME/.openclaw/skills/${SKILL_NAME}")
fi

# Workspace skill directories
for ws_dir in "$HOME/.openclaw/workspaces"/*/skills/"${SKILL_NAME}"; do
  if [[ -f "$ws_dir/SKILL.md" ]]; then
    installed=true
    paths+=("$ws_dir")
  fi
done

# --- Check GitHub ---

on_github=false
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_ORG}/${REPO_NAME}" 2>/dev/null || echo "000")
  if [[ "$http_code" == "200" ]]; then
    on_github=true
  fi
else
  # Try unauthenticated (works for public repos)
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_ORG}/${REPO_NAME}" 2>/dev/null || echo "000")
  if [[ "$http_code" == "200" ]]; then
    on_github=true
  fi
fi

# --- Check pending ---

pending=false
if [[ -f "$PENDING_FILE" ]]; then
  pending_check=$(python3 -c "
import json
data = json.load(open('$PENDING_FILE'))
for s in data.get('pending', []):
    if s['name'] == '$SKILL_NAME':
        print('true')
        break
else:
    print('false')
" 2>/dev/null || echo "false")
  pending=$pending_check
fi

# --- Build paths JSON array ---

paths_json="[]"
if [[ ${#paths[@]} -gt 0 ]]; then
  paths_json=$(printf '%s\n' "${paths[@]}" | python3 -c "
import json, sys
print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))
" 2>/dev/null || echo "[]")
fi

# --- Output ---

cat << EOF
{
  "name": "${SKILL_NAME}",
  "installed": ${installed},
  "github": ${on_github},
  "pending": ${pending},
  "paths": ${paths_json}
}
EOF
