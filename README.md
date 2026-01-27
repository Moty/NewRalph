# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code, Codex, GitHub Copilot, or Gemini) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Quick Start

### Option 1: Global Installation (Recommended)

**Linux/macOS:**

```bash
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install globally (requires sudo)
./install.sh

# Now use from anywhere
cd /path/to/your/project
ralph-setup .
```

This creates a global `ralph-setup` command in `/usr/local/bin/` that points to your Ralph installation.

**Windows:**

```powershell
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install globally (requires WSL or Git Bash)
.\install.ps1

# Now use from anywhere
cd C:\path\to\your\project
ralph-setup .
```

This creates a global `ralph-setup` command in `%LOCALAPPDATA%\Ralph` and adds it to your PATH. Requires WSL (recommended) or Git Bash to be installed.

### Option 2: Direct Installation

Run setup from the Ralph repository:

```bash
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install Ralph into your project
./setup-ralph.sh /path/to/your/project

# Follow the interactive prompts to configure your preferred agent
```

Both methods will:
- ✓ Check for required dependencies (jq, yq, claude/codex)
- ✓ Copy all necessary files to your project
- ✓ Configure your preferred agent (Claude Code, Codex, GitHub Copilot, or Gemini)
- ✓ Detect and cache available models automatically
- ✓ Create template files (prd.json, progress.txt, AGENTS.md)
- ✓ Update .gitignore appropriately

## Prerequisites

### For Windows Users

**Ralph requires a bash environment on Windows:**
- **WSL (Recommended)** - Run `wsl --install` in PowerShell as Administrator
- **Git Bash** - Comes with [Git for Windows](https://git-scm.com/download/win)

Once installed, Ralph provides `.cmd` wrappers so you can run commands directly from PowerShell or cmd:
```powershell
ralph.cmd          # Instead of ./ralph.sh
create-prd.cmd     # Instead of ./create-prd.sh
ralph-models.cmd   # Instead of ./ralph-models.sh
```

### Required Tools
- **jq** - JSON processor
  ```bash
  brew install jq
  ```
- **yq** - YAML processor
  ```bash
  brew install yq
  ```
- **gh** (GitHub CLI) - Required for PR creation (optional, only needed if using `pr.enabled: true`)
  ```bash
  brew install gh
  gh auth login
  ```

### At Least One AI Agent CLI
- **Claude Code CLI**
  - Install from: https://docs.anthropic.com/claude/docs/cli
  - Verify: `claude --version`

- **Codex CLI** (OpenAI)
  - Install from: https://github.com/openai/codex-cli
  - Verify: `codex --version`

- **GitHub Copilot CLI**
  - Install: `npm install -g @github/copilot`
  - Authenticate: Run `copilot` and use `/login`
  - Verify: `copilot --version`

- **Gemini CLI** (Google)
  - Install: `npm install -g @anthropic/gemini-cli` or via pip
  - Verify: `gemini --version`

Ralph works with any of these agents and can use multiple with automatic fallback.

## Uninstallation

If you installed Ralph globally:

**Linux/macOS:**
```bash
sudo rm /usr/local/bin/ralph-setup
```

**Windows:**
```powershell
Remove-Item -Recurse "$env:LOCALAPPDATA\Ralph"
# Then manually remove from PATH in System Environment Variables
```

To remove Ralph from a project, delete the installed files:

```bash
rm ralph.sh agent.yaml prd.json progress.txt AGENTS.md .last-branch
rm -rf system_instructions/ skills/ archive/
```

## Setup

### Automated Setup (Use this!)

The `setup-ralph.sh` script handles everything:

```bash
# Fresh install
./setup-ralph.sh /path/to/your/project

# Update existing installation (preserves your config)
./setup-ralph.sh --update /path/to/your/project

# Check Ralph version
./setup-ralph.sh --version
```

**Options:**
- `--update` - Update existing installation while preserving `agent.yaml` settings
- `--force` - Force overwrite all files including configuration
- `--version` - Show Ralph version
- `-h, --help` - Show help

**Update mode features:**
- Updates core scripts (`ralph.sh`, `create-prd.sh`, `lib/`, `skills/`)
- Preserves your `agent.yaml` configuration (merges new options)
- Preserves `prd.json`, `progress.txt`, `AGENTS.md`
- Creates timestamped backups in `.ralph-backup/`
- Writes version to `.ralph-version` for tracking

### Self-Update from Projects

Projects can update themselves without needing direct access to the Ralph repo:

```bash
# Check if updates are available
./ralph.sh --check-update

# Update to latest version
./ralph.sh --update
```

This works by:
1. Reading the source repo path from `.ralph-version`
2. Comparing versions with the source
3. Running `setup-ralph.sh --update` automatically

**Tip:** Keep your Ralph source repo up to date with `git pull`, then use `./ralph.sh --update` in each project.

### Bulk Update All Projects

For projects with older Ralph versions (pre-1.1.0), use the bulk updater from the Ralph source repo:

```bash
# Update all Ralph installations found in default paths
cd /path/to/ralph
./ralph-update-all.sh

# Or specify custom search paths
./ralph-update-all.sh ~/work ~/projects /Volumes/ExternalDrive/projects
```

This will:
- Search for all `ralph.sh` files in the specified directories
- Show found installations with their versions
- Update them all after confirmation
- Enable self-update (`./ralph.sh --update`) for future updates

**Default search paths:** `~/Projects` and `/Volumes/MMMACSSD/Projects`

This will copy all necessary files and guide you through configuration.

### Manual Setup

If you prefer manual installation:

#### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.sh scripts/ralph/
cp -r /path/to/ralph/system_instructions scripts/ralph/
cp /path/to/ralph/agent.yaml scripts/ralph/
cp /path/to/ralph/prd.json.example scripts/ralph/prd.json
chmod +x scripts/ralph/ralph.sh
```

#### Option 2: Install skills globally

Copy the skills to your preferred agent's config directory for use across all projects.

## Configuration

### agent.yaml

The setup script automatically configures this based on installed CLIs, but you can customize:

Edit `agent.yaml` to configure agents and models:

```yaml
agent:
  primary: claude-code   # Options: claude-code, codex, github-copilot, gemini
  fallback: codex        # Optional fallback if primary fails

# Claude Code settings
claude-code:
  model: claude-sonnet-4-5-20250929  # or: claude-3-5-sonnet, claude-3-opus, etc.
  # flags: "--verbose"  # Uncomment for debugging

# Codex settings
codex:
  model: codex-5.2       # latest Codex; use o1/gpt-4o if unavailable
  approval-mode: full-auto
  # flags: "--quiet"  # Uncomment for silent runs

# GitHub Copilot CLI settings
github-copilot:
  model: auto            # Options: claude-opus-4.5, claude-sonnet-4.5, gpt-5.2-codex, auto
  tool-approval: allow-all  # allow-all grants all tool permissions automatically
  # deny-tools:             # Optional: specific tools to deny
  #   - "shell (rm)"
  #   - "fetch"
  # flags: ""

# Gemini settings (Google AI)
gemini:
  model: gemini-2.5-pro  # Options: gemini-2.5-pro, gemini-2.5-flash, gemini-2.0-flash
  # flags: ""

# Git workflow settings (optional, disabled by default)
git:
  auto-checkout-branch: true    # Ralph checkouts feature branch before spawning agent
  base-branch: main             # Branch to create feature branches from
  push:
    enabled: false              # Enable automatic push (disabled by default)
    timing: iteration           # "iteration" (after each story) or "end" (after RALPH_COMPLETE)
  pr:
    enabled: false              # Enable PR creation (disabled by default)
    draft: false                # Create as draft PR
```

**Model Selection:**
- `claude-sonnet-4-5-20250929` - Latest Claude Sonnet 4.5 (recommended for Claude Code)
- `claude-opus-4-5-20251101` - Latest Claude Opus 4.5 (powerful, for complex tasks)
- `claude-opus-4.5` - Best quality for complex tasks (available in Copilot CLI)
- `claude-sonnet-4.5` - Balanced quality/speed (available in Copilot CLI)
- `codex-5.2` - Latest Codex (recommended)
- `gpt-4o` / `o1` - Alternatives if `codex-5.2` unavailable

**Approval Modes:**
- **Codex**: `full-auto`, `review`, `manual`
  - `full-auto` - No human confirmation needed (recommended for Ralph)
  - `review` - Review before executing
  - `manual` - Approve each step
- **GitHub Copilot**: `allow-all`, `selective`
  - `allow-all` - Automatically approve all tools (recommended for Ralph)
  - `selective` - Prompt for each tool (not recommended for automation)
  - Optional `deny-tools` list to block specific tools even with `allow-all`

**Note:** CLI tool versions are determined by what's installed on your system. Run `claude --version`, `codex --version`, or `copilot --version` to check. The `agent.yaml` controls which **model** each CLI uses.

### Checking Available Models

Ralph automatically detects and caches available models during setup. Use the helper script to view models and current configuration:

```bash
./ralph-models.sh              # Show all models and cache info
./ralph-models.sh --refresh    # Force refresh available models
./ralph-models.sh claude       # Claude models only
./ralph-models.sh codex        # Codex models only
./ralph-models.sh config       # Current configuration
./ralph-models.sh --help       # Show help
```

**Model Caching:**
- Models are automatically detected during `setup-ralph.sh`
- Cached in `.ralph-models-cache.json` (refreshed every 24 hours)
- Use `--refresh` flag to force immediate update
- Falls back to curated defaults if detection fails

### Customize CLI commands (if needed)

The CLI commands in `ralph.sh` may need adjustment based on your installed agent versions. Edit the `run_agent()` function to match your CLI:

```bash
# For Claude Code - check your installed version's flags
claude --print --dangerously-skip-permissions --model "model-name" --system-prompt "..." "prompt"

# For Codex - check your installed version's flags  
codex --quiet --approval-mode full-auto --model "model-name" "prompt"
```

## Workflow

### 1. Create a PRD

**Recommended: Use the automated script**

The `create-prd.sh` script automates the entire PRD creation process:

```bash
./create-prd.sh "A simple task management API with CRUD operations using Node.js and Express"
```

This script will:
1. **Auto-detect project type** (greenfield vs brownfield)
2. Load the appropriate PRD skill and ask clarifying questions
3. Generate a structured PRD saved to `tasks/prd-draft.md`
4. Automatically convert it to `prd.json` in Ralph's format
5. Ensure stories are appropriately sized for single iterations
6. For brownfield projects: gather existing codebase context automatically

**Options:**
```bash
./create-prd.sh --help                     # Show help and usage information
./create-prd.sh --draft-only "description" # Generate PRD markdown only (skip JSON conversion)
./create-prd.sh --greenfield "description" # Force greenfield mode (new project from scratch)
./create-prd.sh --brownfield "description" # Force brownfield mode (adding to existing codebase)
./create-prd.sh --model claude-opus "desc" # Specify AI model for PRD generation
```

**Model Selection for PRD Generation:**

| Model | Best For |
|-------|----------|
| `claude-opus` | Technical PRDs with detailed code specs (Claude Opus 4.5) |
| `claude-sonnet` | Balanced quality/cost for most PRDs (Claude Sonnet 4.5) |
| `gemini-pro` | Large codebase analysis with 1M token context |
| `gpt-codex` | OpenAI Codex models |

The script automatically recommends the best model based on project type:
- **Greenfield** → `claude-sonnet` (best balance for new architecture)
- **Small brownfield** → `claude-opus` (best technical accuracy)
- **Large brownfield** → `gemini-pro` (1M token context for full codebase)

**Alternative: Manual step-by-step approach**

If you prefer more control, you can run each step manually:

**Step 1: Generate the PRD**
```
Load the prd skill and create a PRD for [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

**Step 2: Convert PRD to Ralph format**
```
Load the ralph skill and convert tasks/prd-[feature-name].md to prd.json
```

This creates `prd.json` with user stories structured for autonomous execution.

**Alternative: Manual JSON creation**

For simple projects, create `prd.json` manually using `prd.json.example` as a template:

```bash
cp prd.json.example prd.json
# Edit prd.json with your user stories
```

### 3. Run Ralph

```bash
./ralph.sh [max_iterations] [options]
./ralph.sh <subcommand> [args] [options]
```

Default is 10 iterations. Run `./ralph.sh --help` for full usage details.

**Subcommands:**
- `status` - Show project status, story progress, and rotation state
- `review` - Run code review, produce `fixes.json`
- `filebug "description"` - File a bug as a fix story in `fixes.json`
- `change "description"` - Apply a mid-build change to `prd.json`

**Core Options:**
- `max_iterations` - Maximum number of iterations (default: 10)
- `-h, --help` - Show help message with all options
- `-v, --verbose` - Enable debug logging
- `--no-sleep-prevent` - Disable automatic sleep prevention
- `--timeout SECONDS` - Set timeout per iteration (default: 7200s/2 hours)
- `--no-timeout` - Disable iteration timeout
- `--fixes` - Build from `fixes.json` instead of `prd.json`
- `--file FILE` - Specify a file reference (used with `filebug`)
- `--check-update` - Check if Ralph updates are available
- `--update` - Self-update from source repository

**Git Workflow Options:**
- `--push` - Enable automatic push after each story (overrides config)
- `--no-push` - Disable automatic push (overrides config)
- `--create-pr` - Enable PR creation when all stories complete (overrides config)
- `--no-pr` - Disable PR creation (overrides config)
- `--auto-merge` - Enable auto-merge of PR into base branch (overrides config)
- `--no-auto-merge` - Disable auto-merge (overrides config)

**Rotation Options:**
- `--rotation` - Enable model/agent rotation (overrides config)
- `--no-rotation` - Disable rotation (overrides config)

**Examples:**
```bash
./ralph.sh 20 --verbose              # Run 20 iterations with debug logging
./ralph.sh --push --create-pr        # Enable push and PR for this run
./ralph.sh --timeout 3600            # Set 1-hour timeout per iteration
./ralph.sh --fixes                   # Build from fixes.json
./ralph.sh review                    # Run code review
./ralph.sh filebug "Login broken"    # File a bug
./ralph.sh change "Add pagination"   # Apply mid-build change
./ralph.sh status                    # Show project status
```

**Features:**
- ☕ **Sleep Prevention**: Automatically uses `caffeinate` (macOS) or `systemd-inhibit` (Linux) to prevent system sleep during long runs
- 📊 **Progress Display**: Shows current story, completion progress, and elapsed time
- ⚠️ **Rate Limit Detection**: Automatically stops if API rate limits are hit
- 🔄 **Fallback Support**: Tries the fallback agent if the primary agent fails
- 🌳 **Git Workflow**: Automated branch management, merging, pushing, and PR creation (configurable)

Ralph will:
1. Ensure feature branch is checked out (from PRD `branchName`)
2. Pull latest changes from remote
3. Pick the highest priority story where `passes: false`
4. Agent verifies it's on the feature branch and implements story
5. Run quality checks (typecheck, tests)
6. Commit directly to the feature branch
7. Push to remote (if enabled)
8. Update `prd.json` to mark story as `passes: true`
9. Append learnings to `progress.txt`
10. Repeat until all stories pass or max iterations reached
11. Create PR (if enabled and all stories complete)

## Git Workflow

Ralph uses a linear commit workflow on the feature branch:

```
main (stable)
  └── ralph/feature-name (feature branch)
        ├── commit: feat: US-001 - Story Title
        ├── commit: feat: US-002 - Story Title
        └── PR → main (when all stories complete)
```

### How It Works

1. **Setup** (`setup-ralph.sh`)
   - Creates the feature branch specified in `prd.json` (`branchName`)
   - Pushes to GitHub with upstream tracking: `git push -u origin ralph/feature-name`

2. **Before Each Iteration** (`ralph.sh`)
   - Ensures you're on the feature branch
   - Pulls latest changes: `git pull origin ralph/feature-name`

3. **Agent Execution**
   - Agent verifies it's on the feature branch (checks out if not)
   - Implements the story and commits directly: `git commit -m "feat: US-XXX - Story Title"`

4. **After Story Completes** (`ralph.sh`)
   - Verifies we're still on the feature branch (recovers if agent switched)
   - Pushes to remote (if `push.enabled: true` and `timing: iteration`)

5. **After All Stories Complete** (`ralph.sh`)
   - Final push (if `push.enabled: true` and `timing: end`)
   - Creates PR using GitHub CLI: `gh pr create --base main --head ralph/feature-name`

### Configuration

Configure git workflow in `agent.yaml`:

```yaml
git:
  # Automatically checkout the feature branch before spawning agent
  auto-checkout-branch: true

  # Base branch to create feature branches from (usually main or master)
  base-branch: main

  # Push settings
  push:
    # Enable automatic push after each story (disabled by default for backward compatibility)
    enabled: false
    # When to push: "iteration" (after each story) or "end" (after RALPH_COMPLETE)
    timing: iteration

  # Pull Request settings
  pr:
    # Enable automatic PR creation when all stories complete (disabled by default)
    enabled: false
    # Create as draft PR
    draft: false
```

### Enabling Git Workflow

**Option 1: Edit agent.yaml**

```yaml
git:
  push:
    enabled: true
    timing: iteration  # Push after each story
  pr:
    enabled: true      # Create PR when done
```

**Option 2: Use CLI flags**

```bash
./ralph.sh --push --create-pr
```

CLI flags override the `agent.yaml` configuration for a single run.

### Requirements

- **GitHub CLI** (`gh`) must be installed and authenticated for PR creation
  ```bash
  brew install gh
  gh auth login
  ```

- **Git remote** must be configured (automatically set up if using GitHub)
  ```bash
  git remote -v  # Check if origin exists
  ```

### Benefits

- **No Merge Conflicts**: Direct commits eliminate sub-branch merge issues
- **Clear History**: Each story gets a `feat: US-XXX` commit for easy identification
- **Review Ready**: PRs are created automatically with summary and test plan
- **Collaboration**: Push after each story allows team to follow progress
- **Rollback**: Easy to revert individual stories via commit

### Backward Compatibility

Git workflow features are **disabled by default** to maintain backward compatibility with existing Ralph installations. Projects that don't need automated push/PR can run Ralph exactly as before.

## Model/Agent Rotation

Ralph supports intelligent rotation between agents and models on failures or rate limits. When one agent fails repeatedly or hits a rate limit, Ralph automatically switches to the next available agent or model.

### Configuration

Enable rotation in `agent.yaml`:

```yaml
rotation:
  enabled: true
  failure-threshold: 2        # consecutive failures before rotating
  rate-limit-cooldown: 300    # seconds before retrying rate-limited agent
  strategy: sequential        # "sequential" or "priority"

agent-rotation:              # ordered list of agents to rotate through
  - github-copilot
  - claude-code
  - gemini
  - codex

# Per-agent model lists (rotates through on failure)
claude-code:
  model: claude-sonnet-4-5-20250929
  models:
    - claude-sonnet-4-5-20250929
    - claude-opus-4-5-20251101
    - claude-sonnet-4-20250514
    - claude-3-5-haiku-20241022
```

### Rotation Behavior

- **On failure**: Increments failure counter. After `failure-threshold` consecutive failures with the same agent/model, rotates to the next model (then the next agent if all models are exhausted).
- **On rate limit**: Records cooldown timestamp, immediately rotates to next agent, waits for cooldown before retrying.
- **On success**: Resets failure counter for that story.
- **On new PRD**: Rotation state is deleted when starting a new PRD (branch name changes), so the new run starts fresh with the primary agent.

State persists in `.ralph/rotation-state.json`.

### CLI Overrides

```bash
./ralph.sh --rotation      # Enable rotation for this run
./ralph.sh --no-rotation   # Disable rotation for this run
```

## Review Command

Run a code review on changes made since branching from main:

```bash
./ralph.sh review
```

The review agent examines changed files, identifies high-impact issues, and produces structured fix stories saved to `fixes.json`. Then build the fixes:

```bash
./ralph.sh --fixes         # Run the standard build loop using fixes.json
```

Fix stories in `fixes.json` use the same format as `prd.json` and have `source: "review"` to indicate their origin.

## Filebug Command

Quick path from "I found a bug" to a fix story:

```bash
./ralph.sh filebug "The login button doesn't redirect after auth"
./ralph.sh filebug --file src/auth.ts "Login redirect broken"
```

The agent analyzes the bug description (and optional file reference), produces a fix story, and appends it to `fixes.json`. Fix stories have `source: "filebug"` and priority 1-3 (security/crash, wrong behavior, cosmetic). Then run `./ralph.sh --fixes` to build the fixes.

## Change Command

Safely apply mid-build changes to `prd.json`:

```bash
./ralph.sh change "Add pagination to the user list endpoint"
./ralph.sh change "Remove the export feature, we don't need it anymore"
./ralph.sh change "Update US-003 to also handle edge case where user has no email"
```

The change agent modifies `prd.json` directly — adding, modifying, removing, or reworking stories. A backup is created in `.ralph-backup/` before any changes. If the result is invalid JSON, it restores from backup automatically.

**Safety rules:** Completed stories (`passes: true`) are never modified, stories are never deleted (only marked `status: "removed"`), and `branchName`/`project` fields are immutable. Changes are tracked via `changeRequests` entries in `prd.json`.

## Files Installed by Setup

When you run `setup-ralph.sh`, these files are added to your project:

```
your-project/
├─ ralph.sh                     # Main execution loop
├─ create-prd.sh                # Automated PRD generation script
├─ ralph-models.sh              # Model listing and cache management
├─ agent.yaml                   # Agent configuration
├─ prd.json                     # Your project requirements
├─ prd.json.example             # Example PRD format
├─ progress.txt                 # Iteration log (auto-generated)
├─ AGENTS.md                    # Pattern documentation
├─ .last-branch                 # Branch tracking (auto-generated)
├─ .ralph/                      # Runtime state (auto-generated)
│  └─ rotation-state.json       # Rotation state tracking
├─ lib/                         # Core library functions
│  ├─ common.sh                 # Logging, validation, utilities
│  ├─ git.sh                    # Git workflow operations
│  ├─ context.sh                # Task state management
│  ├─ context-builder.sh        # Builds context for agent prompts
│  ├─ compaction.sh             # Memory compaction
│  ├─ rotation.sh               # Model/agent rotation
│  └─ model-refresh.sh          # Model detection
├─ system_instructions/         # Agent prompts
│  ├─ system_instructions.md           # Claude Code
│  ├─ system_instructions_codex.md     # Codex
│  ├─ system_instructions_copilot.md   # GitHub Copilot CLI
│  ├─ system_instructions_review.md    # Review agent
│  ├─ system_instructions_filebug.md   # Filebug agent
│  └─ system_instructions_change.md    # Change agent
├─ skills/                      # Optional skills library
│  ├─ prd/
│  └─ ralph/
└─ archive/                     # Previous run backups
```

**Git Tracking:**
- ✓ Commit: `ralph.sh`, `create-prd.sh`, `ralph-models.sh`, `agent.yaml`, `prd.json`, `prd.json.example`, `AGENTS.md`, `lib/`, `system_instructions/`, `skills/`
- ✗ Ignore: `progress.txt`, `.last-branch`, `.ralph-version`, `.ralph-backup/`, `archive/`, `.ralph-models-cache.json`, `ralph.log` (automatically added to .gitignore)

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh agent instances |
| `create-prd.sh` | Automated two-step PRD generation and conversion script |
| `ralph-models.sh` | Model listing and cache management utility |
| `agent.yaml` | Configuration for primary/fallback agent selection, rotation, and git workflow |
| `lib/common.sh` | Core utilities: logging, validation, dependency checking |
| `lib/git.sh` | Git workflow: branch management, merge, push, PR creation |
| `lib/context.sh` | Task state management with dependency awareness |
| `lib/context-builder.sh` | Builds context for agent prompts |
| `lib/compaction.sh` | Memory compaction for long-running sessions |
| `lib/rotation.sh` | Intelligent model/agent rotation and rate limit handling |
| `lib/model-refresh.sh` | Model detection and caching |
| `system_instructions/` | Agent-specific instruction files |
| `system_instructions/system_instructions.md` | Instructions for Claude Code |
| `system_instructions/system_instructions_codex.md` | Instructions for Codex |
| `system_instructions/system_instructions_copilot.md` | Instructions for GitHub Copilot CLI |
| `system_instructions/system_instructions_review.md` | Instructions for review agent |
| `system_instructions/system_instructions_filebug.md` | Instructions for filebug agent |
| `system_instructions/system_instructions_change.md` | Instructions for change agent |
| `prd.json` | User stories with `passes` status (the task list) |
| `fixes.json` | Fix stories from review/filebug commands |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `.ralph/rotation-state.json` | Rotation state, rate limit cooldowns, usage metrics |
| `skills/prd/SKILL.md` | General-purpose PRD skill |
| `skills/prd/GREENFIELD.md` | PRD skill for new projects (architecture, tech selection) |
| `skills/prd/BROWNFIELD.md` | PRD skill for existing codebases (integration, patterns) |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `specs/INDEX.md` | The Pin - Discovery index of existing functionality |
| `scripts/generate-pin.sh` | Auto-generate The Pin from codebase analysis |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations and understand how Ralph works visually.

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new agent instance** (Claude Code, Codex, GitHub Copilot, or Gemini) with clean context. The only memory between iterations is:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and context)
- `prd.json` (which stories are done)

### Small Tasks

Each PRD item should be small enough to complete in one context window. If a task is too big, the LLM runs out of context before finishing and produces poor code.

Right-sized stories:
- Add a database column and migration
- Add a UI component to an existing page
- Update a server action with new logic
- Add a filter dropdown to a list

Too big (split these):
- "Build the entire dashboard"
- "Add authentication"
- "Refactor the API"

### Story Dependencies with blockedBy

User stories can declare dependencies on other stories using the `blockedBy` field:

```json
{
  "id": "US-002",
  "title": "Display priority indicator",
  "blockedBy": ["US-001"],
  "passes": false
}
```

**How it works:**
- Stories in `blockedBy` must complete (`passes: true`) before the story can start
- Ralph automatically skips blocked stories and picks the next ready one
- The `create-prd.sh` script generates `blockedBy` based on detected dependencies

**Common dependency patterns:**
| Story Type | Typically Blocked By |
|------------|---------------------|
| Database schema | Nothing (foundational) |
| Backend API | Schema stories it reads/writes |
| UI component | Backend APIs it calls |
| Integration tests | All component stories |

**Validation:**
- Every ID in `blockedBy` must exist in the PRD
- Circular dependencies are detected and warned about (A blocks B, B blocks A)

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because the agent automatically reads these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

### The Pin (Discovery Index)

The Pin (`specs/INDEX.md`) is a searchable index of existing functionality. It prevents duplicate implementations by helping agents discover existing code before writing new features.

**Maintaining The Pin:**

```bash
# Auto-generate from codebase structure
./scripts/generate-pin.sh

# Manually refine keywords for better discoverability
# Edit specs/INDEX.md to add domain-specific terms
```

Agents automatically consult The Pin before implementing new features using the Discovery Protocol defined in system instructions.

### Feedback Loops

Ralph only works if there are feedback loops:
- Typecheck catches type errors
- Tests verify behavior
- CI must stay green (broken code compounds across iterations)

### Browser Verification for UI Stories

Frontend stories must include "Verify in browser using dev-browser skill" in acceptance criteria. Ralph will use the dev-browser skill to navigate to the page, interact with the UI, and confirm changes work.

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Debugging

Check current state:

```bash
# See which stories are done
cat prd.json | jq '.userStories[] | {id, title, passes}'

# See learnings from previous iterations
cat progress.txt

# Check git history
git log --oneline -10
```

## Customizing System Instructions

Edit the files in `system_instructions/` to customize agent behavior for your project:
- `system_instructions.md` - Instructions for Claude Code
- `system_instructions_codex.md` - Instructions for Codex
- `system_instructions_copilot.md` - Instructions for GitHub Copilot CLI
- `system_instructions_review.md` - Instructions for the review agent
- `system_instructions_filebug.md` - Instructions for the filebug agent
- `system_instructions_change.md` - Instructions for the change agent

You can add:
- Project-specific quality check commands
- Codebase conventions
- Common gotchas for your stack

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `archive/YYYY-MM-DD-feature-name/`.

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code)
- [OpenAI Codex documentation](https://github.com/openai/codex)
