# openclaw-skill-manager

An [OpenClaw](https://clawd.bot) agent skill that gives agents autonomous skill-management capabilities. When the agent identifies a capability gap, it can create a new skill, push it to GitHub, and install it after user approval.

## What it does

The skill-manager enables a self-improving workflow:

1. **Detect** — Agent identifies it needs a capability it doesn't have
2. **Create** — Agent generates a new skill (SKILL.md + tools), pushes to GitHub
3. **Track** — New skill is recorded as "pending" (not installed)
4. **Remind** — Next conversation, agent reminds the user and asks for permission
5. **Install** — After approval, agent installs the skill and activates it

All created skills are pushed to the [FutureHax](https://github.com/FutureHax) GitHub organization following the `openclaw-skill-<name>` naming convention.

## Installation

Copy the skill to the OpenClaw shared skills directory:

```bash
# Shared (all agents)
scp -r skill-manager your-vps:~/.openclaw/skills/skill-manager
```

Restart the gateway after installing:

```bash
openclaw gateway restart
```

### Verify installation

```bash
openclaw skills list | grep skill-manager
```

## Requirements

- **`GITHUB_TOKEN`** — GitHub PAT with read-only access (checks repo existence, clones public repos). This is the always-on token that keeps the skill in `ready` state.
- **`GITHUB_WRITE_TOKEN`** *(optional)* — GitHub PAT with `repo` scope for the FutureHax org. Only needed when `create.sh` runs to create repos and push. Can be short-lived or limited-scope. If not set, `create.sh` falls back to `GITHUB_TOKEN`.
- **`python3`** — Used for JSON manipulation in tracking scripts (standard on Ubuntu 24.04)
- **`git`** — For initializing and pushing skill repos
- **`curl`** — For GitHub REST API calls

Add the tokens to `~/.openclaw/.env`:

```bash
GITHUB_TOKEN=ghp_your_readonly_token
GITHUB_WRITE_TOKEN=ghp_your_write_token
```

## Skill contents

```
skill-manager/
├── SKILL.md           # Skill definition and agent behavioral instructions
├── README.md          # This file
└── tools/
    ├── create.sh      # Create GitHub repo, push skill, track as pending
    ├── pending.sh     # List/check/add/remove pending skills
    ├── install.sh     # Install approved skill from GitHub
    └── status.sh      # Check skill existence (installed, GitHub, pending)
```

## Tool usage

### Check skill status

```bash
bash tools/status.sh weather-api
```

Returns:
```json
{
  "name": "weather-api",
  "installed": false,
  "github": false,
  "pending": false,
  "paths": []
}
```

### Create a new skill

Stage files first, then run create:

```bash
# Stage the skill files
mkdir -p ~/.openclaw/skill-manager/staging/weather-api/tools
# ... write SKILL.md and tool scripts to staging dir ...

# Create repo and push
bash tools/create.sh weather-api "Query weather data for location-based recommendations"
```

Returns:
```json
{
  "status": "created",
  "name": "weather-api",
  "repo": "FutureHax/openclaw-skill-weather-api",
  "url": "https://github.com/FutureHax/openclaw-skill-weather-api",
  "pending": true
}
```

### Check for pending skills

```bash
bash tools/pending.sh check
```

Returns nothing if no pending skills, or a formatted list:
```
- **weather-api**: Query weather data for location-based recommendations
  Repo: https://github.com/FutureHax/openclaw-skill-weather-api
  Created: 2026-02-12T20:00:00Z
```

### Install an approved skill

```bash
# Shared (all agents)
bash tools/install.sh weather-api shared

# Single agent only
bash tools/install.sh weather-api agent:zordon
```

Returns:
```json
{
  "status": "installed",
  "name": "weather-api",
  "path": "/home/marvin/.openclaw/skills/weather-api",
  "scope": "shared",
  "repo": "FutureHax/openclaw-skill-weather-api",
  "note": "Restart the gateway to activate: openclaw gateway restart"
}
```

## How the agent uses this

The agent follows a strict workflow defined in SKILL.md:

1. **Conversation start**: Runs `pending.sh check` to see if any skills are awaiting approval
2. **Capability gap**: When the agent can't fulfill a request, it proposes creating a skill
3. **Creation**: Agent writes SKILL.md + tools to a staging directory, then runs `create.sh`
4. **No auto-install**: Created skills are never installed in the same conversation
5. **Next conversation**: Agent reminds the user about pending skills and asks permission
6. **Approval**: User approves, agent runs `install.sh`, suggests gateway restart

## License

MIT
