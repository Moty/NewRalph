# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code or Codex) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## Quick Start

### Option 1: Global Installation (Recommended)

Install Ralph globally to use from anywhere:

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
- ✓ Configure your preferred agent (Claude Code or Codex)
- ✓ Detect and cache available models automatically
- ✓ Create template files (prd.json, progress.txt, AGENTS.md)
- ✓ Update .gitignore appropriately

## Prerequisites

### Required Tools
- **jq** - JSON processor
  ```bash
  brew install jq
  ```
- **yq** - YAML processor
  ```bash
  brew install yq
  ```

### At Least One AI Agent CLI
- **Claude Code CLI**
  - Install from: https://docs.anthropic.com/claude/docs/cli
  - Verify: `claude --version`

- **Codex CLI** (OpenAI)
  - Install from: https://github.com/openai/codex-cli
  - Verify: `codex --version`

Ralph works with either agent and can use both with automatic fallback.

## Uninstallation

If you installed Ralph globally:

```bash
sudo rm /usr/local/bin/ralph-setup
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
# From the Ralph repository
./setup-ralph.sh /path/to/your/project
```

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
  primary: claude-code   # Options: claude-code, codex
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
```

**Model Selection:**
- `claude-sonnet-4-20250514` - Latest Claude Sonnet (recommended)
- `codex-5.2` - Latest Codex (recommended)
- `gpt-4o` / `o1` - Alternatives if `codex-5.2` unavailable

**Approval Modes (Codex only):**
- `full-auto` - No human confirmation needed (recommended for Ralph)
- `review` - Review before executing
- `manual` - Approve each step

**Note:** CLI tool versions are determined by what's installed on your system. Run `claude --version` or `codex --version` to check. The `agent.yaml` controls which **model** each CLI uses.

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
1. Load the PRD skill and ask clarifying questions
2. Generate a structured PRD saved to `tasks/prd-draft.md`
3. Automatically convert it to `prd.json` in Ralph's format
4. Ensure stories are appropriately sized for single iterations
5. Warn before overwriting existing `prd.json` files

**Options:**
```bash
./create-prd.sh --help                    # Show help and usage information
./create-prd.sh --draft-only "description" # Generate PRD markdown only (skip JSON conversion)
```

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
./ralph.sh [max_iterations] [--no-sleep-prevent]
```

Default is 10 iterations.

**Options:**
- `max_iterations` - Maximum number of iterations (default: 10)
- `--no-sleep-prevent` - Disable automatic sleep prevention

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
├─ system_instructions/         # Agent prompts
│  ├─ system_instructions.md
│  └─ system_instructions_codex.md
├─ skills/                      # Optional skills library
│  ├─ prd/
│  └─ ralph/
└─ archive/                     # Previous run backups
```

**Git Tracking:**
- ✓ Commit: `ralph.sh`, `create-prd.sh`, `ralph-models.sh`, `agent.yaml`, `prd.json`, `prd.json.example`, `AGENTS.md`, `system_instructions/`, `skills/`
- ✗ Ignore: `progress.txt`, `.last-branch`, `archive/`, `.ralph-models-cache.json` (automatically added to .gitignore)

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh agent instances |
| `create-prd.sh` | Automated two-step PRD generation and conversion script |
| `ralph-models.sh` | Model listing and cache management utility |
| `agent.yaml` | Configuration for primary/fallback agent selection |
| `system_instructions/` | Agent-specific instruction files |
| `system_instructions/system_instructions.md` | Instructions for Claude Code |
| `system_instructions/system_instructions_codex.md` | Instructions for Codex |
| `prd.json` | User stories with `passes` status (the task list) |
| `prd.json.example` | Example PRD format for reference |
| `progress.txt` | Append-only learnings for future iterations |
| `prompt.md` | Legacy prompt file (optional) |
| `skills/prd/` | Skill for generating PRDs |
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

Frontend stories must include browser verification in their acceptance criteria. Ralph agents have access to Playwright browser automation tools that allow them to:

- Navigate to pages and verify they load correctly
- Interact with UI elements (click buttons, fill forms, etc.)
- Capture screenshots to document working features
- Verify visual changes and functionality

**Acceptance criteria should be specific about what to verify:**
- Preferred: "Browser verification: Navigate to /dashboard and verify new chart displays"
- Preferred: "Browser verification: Click submit button and verify success message appears"
- Generic (less preferred): "Browser verification passes"

**How it works:**
When an agent implements a UI story, it will:
1. Start your dev server (e.g., `npm run dev`)
2. Use Playwright tools to navigate to the relevant page
3. Interact with the UI to verify the changes work
4. Take screenshots to confirm the feature is working
5. Only mark the story as complete if browser verification passes

**Available Playwright tools:**
- `browser_navigate` - Open URLs
- `browser_snapshot` - Capture page state with accessibility tree
- `browser_click` - Click elements
- `browser_type` - Fill in text fields
- `browser_take_screenshot` - Document the working feature
- And more (see your agent's tool documentation)

This ensures UI changes are not just syntactically correct, but actually work from a user's perspective.

**Tips for effective browser verification:**
- **Start your dev server first**: Use async mode or background processes (`npm run dev &`)
- **Wait for server to be ready**: Add a short sleep after starting the server
- **Use browser_snapshot for debugging**: It shows the page's accessibility tree, useful for finding element selectors
- **Take screenshots of working features**: Documents the completion for your progress log
- **Test interactions, not just rendering**: Click buttons, fill forms, verify state changes
- **Check for console errors**: Use browser tools to ensure no JavaScript errors

**Example workflow in progress.txt:**
```
Started dev server on port 3000
Used browser_navigate to open http://localhost:3000/dashboard
Verified new priority filter dropdown renders correctly
Clicked "High Priority" filter and confirmed only high-priority tasks displayed
Took screenshot showing the working filter
```

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

### Troubleshooting Browser Verification

If browser verification fails during an iteration:

**Server won't start:**
```bash
# Check if port is already in use
lsof -i :3000

# Review the output to identify the process
# Make sure it's your dev server before killing
# Look for process name (node, npm, yarn, etc.) and PID

# Get the PID for manual verification
PID=$(lsof -t -i:3000)
echo "Process $PID is using port 3000"
ps -p $PID  # Review process details

# Kill the process (sends SIGTERM, allows graceful shutdown)
kill $PID

# If process still running after a few seconds, use force kill
# WARNING: Force kill (SIGKILL) doesn't allow cleanup and may cause:
# - Unsaved data loss
# - Corrupted files
# - Orphaned child processes
# Only use as last resort:
# kill -9 $PID

# Alternative: Use a different port instead
# First check the new port is available
lsof -i :3001 || PORT=3001 npm run dev
# Or try multiple ports automatically
for port in 3001 3002 3003; do lsof -i :$port || { PORT=$port npm run dev; break; }; done
```

**Page won't load:**
```bash
# Verify server is running
curl http://localhost:3000

# Check server logs for errors
# (Look at the process output where you started the dev server)

# Wait longer for server startup
sleep 10  # instead of sleep 5
```

**Elements not found:**
- Use `browser_snapshot` to see the page's accessibility tree
- Check element selectors match what's actually rendered
- Ensure JavaScript has finished loading (add small delay)
- Look for elements by aria-label, role, or visible text

**Screenshots show errors:**
- Check browser console for JavaScript errors
- Verify all dependencies are installed
- Check that environment variables are set correctly
- Review server logs for API errors


## Customizing System Instructions

Edit the files in `system_instructions/` to customize agent behavior for your project:
- `system_instructions.md` - Instructions for Claude Code
- `system_instructions_codex.md` - Instructions for Codex

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
