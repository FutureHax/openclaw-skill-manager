#!/usr/bin/env bash
set -euo pipefail

# Skill Manager — Manage pending skills list
# Usage: pending.sh <action> [args...]
#
# Actions:
#   check                           — Brief summary if pending skills exist
#   list                            — Full JSON list of pending skills
#   add <name> <repo> <description> — Add a skill to the pending list
#   remove <name>                   — Remove a skill from the pending list

ACTION="${1:?Usage: pending.sh <check|list|add|remove> [args...]}"
shift

PENDING_DIR="$HOME/.openclaw/skill-manager"
PENDING_FILE="$PENDING_DIR/pending.json"

# Ensure the tracking directory and file exist
mkdir -p "$PENDING_DIR"
if [[ ! -f "$PENDING_FILE" ]]; then
  echo '{"pending":[]}' > "$PENDING_FILE"
fi

case "$ACTION" in

  check)
    # Return a human-readable summary if there are pending skills, or nothing
    count=$(python3 -c "
import json, sys
data = json.load(open('$PENDING_FILE'))
print(len(data.get('pending', [])))
" 2>/dev/null || echo "0")

    if [[ "$count" -gt 0 ]]; then
      python3 -c "
import json
data = json.load(open('$PENDING_FILE'))
for s in data.get('pending', []):
    print(f\"- **{s['name']}**: {s['description']}\")
    print(f\"  Repo: https://github.com/{s['repo']}\")
    print(f\"  Created: {s.get('created_at', 'unknown')}\")
"
    fi
    ;;

  list)
    cat "$PENDING_FILE"
    ;;

  add)
    name="${1:?Usage: pending.sh add <name> <repo> <description>}"
    repo="${2:?Usage: pending.sh add <name> <repo> <description>}"
    description="${3:?Usage: pending.sh add <name> <repo> <description>}"
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    python3 -c "
import json, sys
data = json.load(open('$PENDING_FILE'))
# Remove existing entry with same name if present
data['pending'] = [s for s in data.get('pending', []) if s['name'] != '$name']
data['pending'].append({
    'name': '$name',
    'description': '''$description''',
    'repo': '$repo',
    'created_at': '$timestamp'
})
json.dump(data, open('$PENDING_FILE', 'w'), indent=2)
print(json.dumps({'status': 'added', 'name': '$name'}))
"
    ;;

  remove)
    name="${1:?Usage: pending.sh remove <name>}"

    python3 -c "
import json
data = json.load(open('$PENDING_FILE'))
before = len(data.get('pending', []))
data['pending'] = [s for s in data.get('pending', []) if s['name'] != '$name']
after = len(data['pending'])
json.dump(data, open('$PENDING_FILE', 'w'), indent=2)
if before > after:
    print(json.dumps({'status': 'removed', 'name': '$name'}))
else:
    print(json.dumps({'status': 'not_found', 'name': '$name'}))
"
    ;;

  *)
    echo "{\"error\":\"Unknown action: ${ACTION}. Use check, list, add, or remove.\"}" >&2
    exit 1
    ;;
esac
