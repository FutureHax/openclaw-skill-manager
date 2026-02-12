#!/usr/bin/env bash
set -euo pipefail

# Skill Manager — Create and push a new skill to GitHub
# Usage: create.sh <skill_name> <description>
#
# Reads staged files from ~/.openclaw/skill-manager/staging/<skill_name>/
# Creates a GitHub repo in the FutureHax org, pushes all files, and tracks
# the skill as pending installation.
#
# Requires: GITHUB_WRITE_TOKEN environment variable with repo scope for FutureHax org.
# Falls back to GITHUB_TOKEN if GITHUB_WRITE_TOKEN is not set, but GITHUB_TOKEN
# is typically read-only and will fail on create/push operations.

SKILL_NAME="${1:?Usage: create.sh <skill_name> <description>}"
DESCRIPTION="${2:?Usage: create.sh <skill_name> <description>}"

GITHUB_ORG="FutureHax"
REPO_NAME="openclaw-skill-${SKILL_NAME}"
STAGING_DIR="$HOME/.openclaw/skill-manager/staging/${SKILL_NAME}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Resolve write token (prefer GITHUB_WRITE_TOKEN, fall back to GITHUB_TOKEN) ---

GH_WRITE_TOKEN="${GITHUB_WRITE_TOKEN:-${GITHUB_TOKEN:-}}"

if [[ -z "$GH_WRITE_TOKEN" ]]; then
  echo '{"error":"No GitHub write token available. Set GITHUB_WRITE_TOKEN (preferred) or GITHUB_TOKEN with repo scope."}' >&2
  exit 1
fi

if [[ ! -d "$STAGING_DIR" ]]; then
  echo "{\"error\":\"Staging directory not found: ${STAGING_DIR}. Stage skill files before running create.sh.\"}" >&2
  exit 1
fi

if [[ ! -f "$STAGING_DIR/SKILL.md" ]]; then
  echo '{"error":"SKILL.md not found in staging directory. Every skill requires a SKILL.md."}' >&2
  exit 1
fi

# --- Generate README.md if not staged ---

if [[ ! -f "$STAGING_DIR/README.md" ]]; then
  skill_title=$(echo "$SKILL_NAME" | sed 's/-/ /g' | sed 's/\b\(.\)/\u\1/g')
  cat > "$STAGING_DIR/README.md" << EOF
# openclaw-skill-${SKILL_NAME}

An [OpenClaw](https://clawd.bot) agent skill: ${DESCRIPTION}

## Installation

Copy the skill to the OpenClaw skills directory:

\`\`\`bash
# Shared (all agents)
scp -r ${SKILL_NAME} your-vps:~/.openclaw/skills/${SKILL_NAME}

# Per-agent
scp -r ${SKILL_NAME} your-vps:~/.openclaw/workspaces/<agent>/skills/${SKILL_NAME}
\`\`\`

Restart the gateway after installing:

\`\`\`bash
openclaw gateway restart
\`\`\`

## Skill contents

\`\`\`
${SKILL_NAME}/
├── SKILL.md           # Skill definition and agent instructions
├── README.md          # This file
└── tools/             # Implementation scripts
\`\`\`

## License

MIT
EOF
fi

# --- Create GitHub repository ---

http_code=$(curl -s -o /tmp/gh-create-response.json -w "%{http_code}" \
  -X POST \
  -H "Authorization: token ${GH_WRITE_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/orgs/${GITHUB_ORG}/repos" \
  -d "{
    \"name\": \"${REPO_NAME}\",
    \"description\": \"OpenClaw Agent Skill: ${DESCRIPTION}\",
    \"private\": false,
    \"auto_init\": false
  }")

if [[ "$http_code" == "422" ]]; then
  # Repo might already exist — check
  exists_code=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token ${GH_WRITE_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${GITHUB_ORG}/${REPO_NAME}")
  if [[ "$exists_code" == "200" ]]; then
    echo "{\"error\":\"Repository ${GITHUB_ORG}/${REPO_NAME} already exists.\"}" >&2
    exit 1
  fi
  echo "{\"error\":\"Failed to create repository. HTTP ${http_code}: $(cat /tmp/gh-create-response.json)\"}" >&2
  exit 1
elif [[ "$http_code" != "201" ]]; then
  echo "{\"error\":\"Failed to create repository. HTTP ${http_code}: $(cat /tmp/gh-create-response.json)\"}" >&2
  exit 1
fi

repo_url="https://github.com/${GITHUB_ORG}/${REPO_NAME}.git"

# --- Initialize git and push ---

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT

cp -r "$STAGING_DIR/." "$work_dir/"

cd "$work_dir"
git init -q
git checkout -q -b main
git add -A
git commit -q -m "Initial commit: ${SKILL_NAME} skill

${DESCRIPTION}"

git remote add origin "https://x-access-token:${GH_WRITE_TOKEN}@github.com/${GITHUB_ORG}/${REPO_NAME}.git"
git push -q -u origin main

# --- Track as pending ---

bash "$SCRIPT_DIR/pending.sh" add "$SKILL_NAME" "${GITHUB_ORG}/${REPO_NAME}" "$DESCRIPTION"

# --- Clean up staging ---

rm -rf "$STAGING_DIR"

# --- Output result ---

cat << EOF
{
  "status": "created",
  "name": "${SKILL_NAME}",
  "repo": "${GITHUB_ORG}/${REPO_NAME}",
  "url": "https://github.com/${GITHUB_ORG}/${REPO_NAME}",
  "pending": true
}
EOF
