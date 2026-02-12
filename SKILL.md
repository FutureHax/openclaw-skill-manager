---
name: skill-manager
description: Create, track, and install OpenClaw skills autonomously. Detects capability gaps, pushes new skills to GitHub, and installs them after user approval.
metadata: {"openclaw":{"requires":{"env":["GITHUB_TOKEN"]}}}
---

# Skill Manager

You can create, track, and install new OpenClaw skills. Use this when you identify a capability gap — something you should be able to do but lack the tooling for. Instead of telling the user you can't do something, propose and create a skill for it.

## Conversation-start check

**Every time a new conversation begins**, run the pending check before responding to the user's query:

```bash
bash {baseDir}/tools/pending.sh check
```

If the output is non-empty, there are skills waiting for approval. **Before addressing the user's query**, inform them:

> I have a pending skill that was created but not yet installed:
> **{skill name}** — {description}
> Repo: {repo URL}
>
> Would you like me to install it so I can start using it?

Wait for explicit approval before installing. If the user declines or defers, proceed with their query normally.

## When to create a new skill

Create a skill when **all** of the following are true:

1. The user's request requires a capability you don't currently have
2. The capability is concrete and tool-oriented (API integration, data processing, automation)
3. You've checked that no existing skill covers it (run `status.sh` first)
4. The capability would be reusable across future conversations

**Do NOT create skills for** one-off questions, general knowledge, or things you can already do with existing tools.

## Skill creation workflow

### Step 1 — Check if the skill already exists

```bash
bash {baseDir}/tools/status.sh <skill-name>
```

If it's already installed or on GitHub, inform the user and offer to install it (if not installed).

### Step 2 — Design the skill

Before writing any files, plan:

- **Name**: lowercase, hyphenated (e.g., `weather-api`, `jira-tickets`)
- **Description**: one-sentence summary of what the skill does
- **Tools needed**: what shell scripts go in `tools/`
- **Environment variables**: any API keys or config the skill needs
- **When to use**: clear triggers for when the agent should use this skill

### Step 3 — Stage the skill files

Create the skill directory structure in the staging area:

```bash
mkdir -p ~/.openclaw/skill-manager/staging/<skill-name>/tools
```

Write the SKILL.md file (follow the template below):

```bash
cat > ~/.openclaw/skill-manager/staging/<skill-name>/SKILL.md << 'SKILLEOF'
---
name: <skill-name>
description: <one-sentence description>
metadata: {"openclaw":{"requires":{"env":["ENV_VAR_1","ENV_VAR_2"]}}}
---

# <Skill Title>

<What the skill does and when to use it.>

## How to use

<Tool usage instructions with {baseDir}/tools/ paths and examples.>

## When to use this skill

<Clear triggers and scenarios.>

## Guidelines

<Formatting, output conventions, error handling.>
SKILLEOF
```

Write any tool scripts:

```bash
cat > ~/.openclaw/skill-manager/staging/<skill-name>/tools/<tool>.sh << 'TOOLEOF'
#!/usr/bin/env bash
set -euo pipefail

# <Tool description>
# Usage: <tool>.sh <args>

<implementation>
TOOLEOF
chmod +x ~/.openclaw/skill-manager/staging/<skill-name>/tools/<tool>.sh
```

### Step 4 — Create the GitHub repo and push

```bash
bash {baseDir}/tools/create.sh <skill-name> "<description>"
```

This creates the repo `FutureHax/openclaw-skill-<name>`, pushes all staged files, and adds the skill to the pending list.

### Step 5 — Inform the user

After creation, tell the user:

> I've created a new skill: **<name>**
> - Repository: https://github.com/FutureHax/openclaw-skill-<name>
> - Status: Created but **not installed**
>
> Next time we talk, I'll remind you and ask for permission to install it.

**Do NOT install the skill in the same conversation it was created.** The user must approve installation in a subsequent conversation.

## Installing an approved skill

When the user approves a pending skill:

```bash
bash {baseDir}/tools/install.sh <skill-name> shared
```

Scope options:
- `shared` (default) — installs to `~/.openclaw/skills/<name>/` (available to all agents)
- `agent:<name>` — installs to `~/.openclaw/workspaces/<agent>/skills/<name>/` (single agent only)

After installation, remind the user to restart the gateway:

```
openclaw gateway restart
```

## Tools reference

### `status.sh` — Check skill existence

```bash
bash {baseDir}/tools/status.sh <skill-name>
```

Returns JSON with `installed`, `github`, and `pending` booleans.

### `create.sh` — Create and push a new skill

```bash
bash {baseDir}/tools/create.sh <skill-name> "<description>"
```

Reads from `~/.openclaw/skill-manager/staging/<skill-name>/`, creates the GitHub repo, pushes, and tracks as pending.

### `pending.sh` — Manage pending skills

```bash
# Check for pending skills (use at conversation start)
bash {baseDir}/tools/pending.sh check

# List all pending skills as JSON
bash {baseDir}/tools/pending.sh list

# Manually add a pending skill
bash {baseDir}/tools/pending.sh add <name> <repo> "<description>"

# Remove a skill from pending (done automatically by install.sh)
bash {baseDir}/tools/pending.sh remove <name>
```

### `install.sh` — Install an approved skill

```bash
bash {baseDir}/tools/install.sh <skill-name> [scope]
```

Clones from GitHub, deploys to the skill directory, removes from pending.

## Skill template reference

### SKILL.md format

Every OpenClaw skill needs a `SKILL.md` with YAML frontmatter:

```yaml
---
name: my-skill
description: Short description of what the skill does.
metadata: {"openclaw":{"requires":{"env":["API_KEY"]}}}
---
```

The `metadata.openclaw.requires.env` array lists required environment variables. Omit `metadata` if none are needed.

### Tool script conventions

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`
- Use UPPERCASE for constants, lowercase for locals
- Return JSON on stdout for structured data
- Return errors as `{"error": "message"}` on stderr
- Use `{baseDir}` in SKILL.md paths — OpenClaw replaces this at runtime
- Make scripts executable (`chmod +x`)

### Naming conventions

| Item | Convention | Example |
|------|-----------|--------|
| Local skill directory | lowercase-hyphenated | `weather-api` |
| GitHub repo | `openclaw-skill-<name>` | `openclaw-skill-weather-api` |
| GitHub org | `FutureHax` | `FutureHax/openclaw-skill-weather-api` |
| Tool scripts | lowercase, `.sh` extension | `query.sh`, `convert.sh` |

### Directory structure

```
<skill-name>/
├── SKILL.md           # Required: skill definition + agent instructions
├── README.md          # Optional: human-facing documentation
└── tools/             # Optional: implementation scripts
    └── <tool>.sh
```
