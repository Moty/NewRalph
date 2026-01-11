# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code, Codex, GitHub Copilot, or Gemini) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Cross-Platform Support

Ralph is now written in **Node.js** for seamless cross-platform support on:
- **macOS**
- **Windows** (PowerShell, CMD, Git Bash, WSL)
- **Linux**

## Quick Start

### Option 1: npm Installation (Recommended)

Install Ralph globally using npm:

```bash
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install dependencies
npm install

# Link globally (makes commands available everywhere)
npm link

# Now use from anywhere
cd /path/to/your/project
ralph-setup .
```

This creates global commands: `ralph`, `ralph-setup`, `ralph-models`, `create-prd`.

### Option 2: Global Script Installation

Install Ralph globally using the install script:

```bash
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install dependencies
npm install

# Install globally (requires sudo on macOS/Linux)
node install.js

# Now use from anywhere
cd /path/to/your/project
ralph-setup .
```

### Option 3: Direct Installation

Run setup from the Ralph repository:

```bash
# Clone Ralph repository
git clone https://github.com/snarktank/ralph.git
cd ralph

# Install dependencies
npm install

# Install Ralph into your project
node setup-ralph.js /path/to/your/project

# Follow the interactive prompts to configure your preferred agent
```

Both methods will:
- ✓ Check for required dependencies (jq, yq, claude/codex)
- ✓ Copy all necessary files to your project
- ✓ Configure your preferred agent (Claude Code or Codex)
- ✓ Detect and cache available models automatically
- ✓ Create template files (prd.json, progress.txt, AGENTS.md)
- ✓ Update .gitignore appropriately

## Prerequisites

### Required Runtime
- **Node.js** >= 18.0.0
  ```bash
  # macOS (Homebrew)
  brew install node

  # Windows (Chocolatey)
  choco install nodejs

  # Linux (apt)
  curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
  sudo apt-get install -y nodejs
  ```

### Required Tools
- **jq** - JSON processor
  ```bash
  # macOS
  brew install jq

  # Windows
  choco install jq

  # Linux
  sudo apt-get install jq
  ```
- **yq** - YAML processor
  ```bash
  # macOS
  brew install yq

  # Windows
  choco install yq

  # Linux
  sudo snap install yq
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

If you installed Ralph via npm link:

```bash
npm unlink ralph
```

If you installed Ralph globally via install.js:

```bash
# macOS/Linux
sudo rm /usr/local/bin/ralph-setup

# Windows
# Delete the script from your npm bin folder
```

To remove Ralph from a project, delete the installed files:

```bash
rm ralph.js setup-ralph.js create-prd.js ralph-models.js install.js package.json
rm agent.yaml prd.json progress.txt AGENTS.md .last-branch
rm -rf system_instructions/ skills/ archive/ lib/ node_modules/
```

## Setup

### Automated Setup (Use this!)

The `setup-ralph.js` script handles everything:

```bash
# From the Ralph repository
node setup-ralph.js /path/to/your/project
```

This will copy all necessary files and guide you through configuration.

### Manual Setup

If you prefer manual installation:

#### Option 1: Copy to your project

Copy the ralph files into your project:

```bash
# From your project root
mkdir -p scripts/ralph
cp /path/to/ralph/ralph.js scripts/ralph/
cp /path/to/ralph/package.json scripts/ralph/
cp -r /path/to/ralph/lib scripts/ralph/
cp -r /path/to/ralph/system_instructions scripts/ralph/
cp /path/to/ralph/agent.yaml scripts/ralph/
cp /path/to/ralph/prd.json.example scripts/ralph/prd.json
cd scripts/ralph && npm install
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
  model: claude-sonnet-4-20250514  # or: claude-3-5-sonnet, claude-3-opus, etc.
  # flags: "--verbose"  # Uncomment for debugging

# Codex settings
codex:
  model: codex-5.2       # latest Codex; use o1/gpt-4o if unavailable
  approval-mode: full-auto
  # flags: "--quiet"  # Uncomment for silent runs

# GitHub Copilot CLI settings
github-copilot:
  tool-approval: allow-all  # allow-all grants all tool permissions automatically
  # deny-tools:             # Optional: specific tools to deny
  #   - "shell (rm)"
  #   - "fetch"
  # flags: ""

# Gemini settings (Google AI)
gemini:
  model: gemini-2.5-pro  # Options: gemini-2.5-pro, gemini-2.5-flash, gemini-2.0-flash
  # flags: ""
```

**Model Selection:**
- `claude-sonnet-4-20250514` - Latest Claude Sonnet (recommended)
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
node ralph-models.js              # Show all models and cache info
node ralph-models.js --refresh    # Force refresh available models
node ralph-models.js claude       # Claude models only
node ralph-models.js codex        # Codex models only
node ralph-models.js config       # Current configuration
node ralph-models.js --help       # Show help
```

**Model Caching:**
- Models are automatically detected during `node setup-ralph.js`
- Cached in `.ralph-models-cache.json` (refreshed every 24 hours)
- Use `--refresh` flag to force immediate update
- Falls back to curated defaults if detection fails

### Customize CLI commands (if needed)

The CLI commands in `ralph.js` may need adjustment based on your installed agent versions. Edit the `runAgent()` function to match your CLI:

```javascript
// For Claude Code - check your installed version's flags
claude --print --dangerously-skip-permissions --model "model-name" --system-prompt "..." "prompt"

// For Codex - check your installed version's flags
codex --quiet --approval-mode full-auto --model "model-name" "prompt"
```

## Workflow

### 1. Create a PRD

**Recommended: Use the automated script**

The `create-prd.js` script automates the entire PRD creation process:

```bash
node create-prd.js "A simple task management API with CRUD operations using Node.js and Express"
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
node create-prd.js --help                     # Show help and usage information
node create-prd.js --draft-only "description" # Generate PRD markdown only (skip JSON conversion)
node create-prd.js --greenfield "description" # Force greenfield mode (new project from scratch)
node create-prd.js --brownfield "description" # Force brownfield mode (adding to existing codebase)
node create-prd.js --model claude-opus "desc" # Specify AI model for PRD generation
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
node ralph.js [max_iterations] [--no-sleep-prevent] [--verbose] [--timeout SECONDS]
```

Default is 10 iterations.

**Options:**
- `max_iterations` - Maximum number of iterations (default: 10)
- `--no-sleep-prevent` - Disable automatic sleep prevention
- `--verbose` or `-v` - Enable verbose logging
- `--timeout SECONDS` - Set timeout per agent iteration (default: 7200 = 2 hours)
- `--no-timeout` - Disable agent timeout
- `--greenfield` - Force greenfield mode
- `--brownfield` - Force brownfield mode

**Features:**
- ☕ **Sleep Prevention**: Automatically uses `caffeinate` (macOS) or `systemd-inhibit` (Linux) to prevent system sleep during long runs
- 📊 **Progress Display**: Shows current story, completion progress, and elapsed time
- ⚠️ **Rate Limit Detection**: Automatically stops if API rate limits are hit
- 🔄 **Fallback Support**: Tries the fallback agent if the primary agent fails

Ralph will:
1. Create a feature branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, tests)
5. Commit if checks pass
6. Update `prd.json` to mark story as `passes: true`
7. Append learnings to `progress.txt`
8. Repeat until all stories pass or max iterations reached

## Files Installed by Setup

When you run `node setup-ralph.js`, these files are added to your project:

```
your-project/
├─ ralph.js                     # Main execution loop
├─ setup-ralph.js               # Setup script (for re-installing)
├─ create-prd.js                # Automated PRD generation script
├─ ralph-models.js              # Model listing and cache management
├─ install.js                   # Global installation script
├─ package.json                 # Node.js dependencies
├─ lib/                         # Common utility functions
│  ├─ common.js
│  └─ model-refresh.js
├─ agent.yaml                   # Agent configuration
├─ prd.json                     # Your project requirements
├─ prd.json.example             # Example PRD format
├─ progress.txt                 # Iteration log (auto-generated)
├─ AGENTS.md                    # Pattern documentation
├─ .last-branch                 # Branch tracking (auto-generated)
├─ system_instructions/         # Agent prompts
│  ├─ system_instructions.md
│  ├─ system_instructions_codex.md
│  └─ system_instructions_copilot.md
├─ skills/                      # Optional skills library
│  ├─ prd/
│  └─ ralph/
├─ node_modules/                # Dependencies (auto-generated)
└─ archive/                     # Previous run backups
```

**Git Tracking:**
- ✓ Commit: `ralph.js`, `create-prd.js`, `ralph-models.js`, `setup-ralph.js`, `install.js`, `package.json`, `lib/`, `agent.yaml`, `prd.json`, `prd.json.example`, `AGENTS.md`, `system_instructions/`, `skills/`
- ✗ Ignore: `progress.txt`, `.last-branch`, `archive/`, `.ralph-models-cache.json`, `node_modules/` (automatically added to .gitignore)

## Key Files

| File | Purpose |
|------|---------|
| `ralph.js` | The Node.js loop that spawns fresh agent instances |
| `create-prd.js` | Automated two-step PRD generation and conversion script |
| `ralph-models.js` | Model listing and cache management utility |
| `setup-ralph.js` | Setup script to install Ralph into projects |
| `install.js` | Global installation script |
| `lib/common.js` | Shared utility functions (logging, validation, etc.) |
| `lib/model-refresh.js` | Model detection and caching |
| `package.json` | Node.js dependencies and scripts |
| `agent.yaml` | Configuration for primary/fallback agent selection |
| `system_instructions/` | Agent-specific instruction files |
| `system_instructions/system_instructions.md` | Instructions for Claude Code |
| `system_instructions/system_instructions_codex.md` | Instructions for Codex |
| `system_instructions/system_instructions_copilot.md` | Instructions for GitHub Copilot CLI |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `skills/prd/SKILL.md` | General-purpose PRD skill |
| `skills/prd/GREENFIELD.md` | PRD skill for new projects (architecture, tech selection) |
| `skills/prd/BROWNFIELD.md` | PRD skill for existing codebases (integration, patterns) |
| `skills/ralph/` | Skill for converting PRDs to JSON |
| `flowchart/` | Interactive visualization of how Ralph works |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

The `flowchart/` directory contains the source code. To run locally:

```bash
cd flowchart
npm install
npm run dev
```

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new agent instance** (Claude Code or Codex) with clean context. The only memory between iterations is:
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

### AGENTS.md Updates Are Critical

After each iteration, Ralph updates the relevant `AGENTS.md` files with learnings. This is key because the agent automatically reads these files, so future iterations (and future human developers) benefit from discovered patterns, gotchas, and conventions.

Examples of what to add to AGENTS.md:
- Patterns discovered ("this codebase uses X for Y")
- Gotchas ("do not forget to update Z when changing W")
- Useful context ("the settings panel is in component X")

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
