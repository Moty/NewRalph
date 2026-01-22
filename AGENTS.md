# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code, Codex, GitHub Copilot, or Gemini) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context.

**Current Version:** See `.ralph-version` file or run `./setup-ralph.sh --version`

## Installation

### Linux/macOS

```bash
# Global installation (recommended)
./install.sh
# Then from anywhere: ralph-setup /path/to/project

# Or direct installation
./setup-ralph.sh /path/to/your/project

# Or manually copy files
cp ralph.sh agent.yaml /path/to/project/
cp -r system_instructions /path/to/project/
```

### Windows

**Requires WSL (recommended) or Git Bash**

```powershell
# Global installation (recommended)
.\install.ps1
# Then from anywhere: ralph-setup C:\path\to\project

# Or use WSL directly
wsl bash ./setup-ralph.sh /mnt/c/path/to/project
```

### Updating Existing Installations

```bash
# Update Ralph while preserving your configuration
./setup-ralph.sh --update /path/to/project

# Force overwrite everything (including agent.yaml)
./setup-ralph.sh --force /path/to/project

# Check installed version
./setup-ralph.sh --version
```

Update mode:
- Updates core scripts (`ralph.sh`, `create-prd.sh`, `lib/`, `skills/`)
- Preserves `agent.yaml` settings (merges in new options)
- Preserves `prd.json`, `progress.txt`, `AGENTS.md`
- Creates backups in `.ralph-backup/`

## Commands

### Linux/macOS

```bash
# Run the setup script
./setup-ralph.sh /path/to/project

# Run Ralph (from your project that has prd.json)
./ralph.sh [max_iterations]

# Self-update from a project
./ralph.sh --check-update    # Check for updates
./ralph.sh --update          # Update to latest version

# Bulk update all projects (from Ralph source repo)
./ralph-update-all.sh                    # Search default paths
./ralph-update-all.sh ~/work ~/projects  # Custom paths
```

### Windows

```powershell
# Run the setup script (from Ralph repo)
ralph-setup C:\path\to\project

# In your project directory - use .cmd wrappers
ralph.cmd [max_iterations]        # Run Ralph
ralph.cmd --update                # Update Ralph
create-prd.cmd "description"       # Generate PRD
ralph-models.cmd --refresh         # List available models

# Or use bash directly in WSL/Git Bash
bash ralph.sh [max_iterations]
```

## Key Files

- `setup-ralph.sh` - Automated installation/update script for any project
- `ralph-update-all.sh` - Bulk updater for all Ralph installations
- `create-prd.sh` - Automated PRD generation and conversion script
- `ralph.sh` - The bash loop that spawns fresh agent instances
- `ralph-models.sh` - Model listing and cache management utility
- `agent.yaml` - Configuration for primary/fallback agent, model selection, and git workflow
- `.ralph-version` - Version tracking file (created in projects)
- `lib/common.sh` - Core utilities: logging, validation, dependency checking
- `lib/git.sh` - Git workflow operations: branch management, merge, push, PR creation
- `lib/context.sh` - Task state management with dependency awareness
- `lib/compaction.sh` - Memory compaction for long-running sessions
- `lib/model-refresh.sh` - Model detection and caching
- `system_instructions/system_instructions.md` - Instructions for Claude Code
- `system_instructions/system_instructions_codex.md` - Instructions for Codex
- `system_instructions/system_instructions_copilot.md` - Instructions for GitHub Copilot CLI
- `prd.json.example` - Example PRD format
- `skills/prd/` - Skill for generating PRDs
- `skills/ralph/` - Skill for converting PRDs to JSON
- `prompt.md` - Legacy prompt file (optional)

## Flowchart

Interactive visualization at https://snarktank.github.io/ralph/ - click through to reveal each step with animations.

## Patterns

- Each iteration spawns a fresh agent instance (Claude Code, Codex, or GitHub Copilot) with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- Agent selection is configured in `agent.yaml` with optional fallback support
- Model selection is also supported for GitHub Copilot via `agent.yaml`
- Ralph lib scripts must be compatible with bash 3.2 (macOS default) - avoid associative arrays
- Use jq's `// empty` operator when accessing optional fields to prevent errors

### Git Workflow

Ralph supports automated git branch management via `lib/git.sh`:

- **Direct commits**: Agents commit directly to the feature branch (no sub-branches)
- **Branch verification**: Ralph verifies the agent stays on the feature branch after each iteration
- **Push support**: Optional push after each story or at end (configured in `agent.yaml`)
- **PR creation**: Optional PR creation via GitHub CLI when all stories complete
- **Disabled by default**: All git workflow features are opt-in for backward compatibility

Configure in `agent.yaml`:
```yaml
git:
  push:
    enabled: true      # Enable auto-push
    timing: iteration  # "iteration" or "end"
  pr:
    enabled: true      # Enable PR creation
```

Or use CLI overrides: `./ralph.sh --push --create-pr`

## The Pin (Discovery Index)

The Pin (`specs/INDEX.md`) is a searchable index of existing functionality to prevent duplicate implementations.

**Format**: Each module entry contains:
- Module name (clear identifier)
- Keywords: 10-20 synonyms, library names, related terms
- File paths: Where to find the implementation
- Optional spec link: Detailed specification reference

**When to use**:
1. Before implementing new features - search keywords to discover existing code
2. When refactoring - update relevant module entries
3. When adding new modules - create new entries with comprehensive keywords

**Maintenance**: Keep keywords current as the codebase evolves

## Context Management

Ralph includes optional context management features for complex projects.

### blockedBy Dependencies

User stories support a `blockedBy` field to manage task dependencies:

```json
{
  "id": "US-002",
  "title": "Display priority indicator",
  "blockedBy": ["US-001"],
  "passes": false
}
```

- Stories in `blockedBy` must complete before the story can start
- Validation checks all referenced story IDs exist
- Ralph warns about circular dependencies (A blocks B, B blocks A)
- See `prd.json.example` for usage examples

### Memory Compaction

The compaction library (`lib/compaction.sh`) prevents context overflow in long-running sessions:

- Auto-triggers when `progress.txt` exceeds 400 lines (configurable)
- Preserves patterns section (first ~50 lines) and recent entries (last ~200 lines)
- Middle section summarized to key bullet points
- Creates backup files before compaction
- Logs actions to `.ralph/compaction.log`

**Configuration**:
```bash
export RALPH_COMPACTION_THRESHOLD=400  # Line count trigger
export RALPH_PRESERVE_START=50         # Lines to preserve from start
export RALPH_PRESERVE_END=200          # Lines to preserve from end
```

### Context State Directory

The `.ralph/` directory stores context management state:

- `context.json` - Task state with dependency awareness (if using lib/context.sh)
- `compaction.log` - Memory compaction history
- Auto-created when context libraries are used
- Gitignored by default

### Discovery Protocol

Before implementing new functionality, agents follow the Discovery Protocol:

1. **Read specs/INDEX.md** - The Pin contains searchable index
2. **Search with keywords** - Extract keywords from task and search index
3. **Read matching specs** - Review referenced files/specs
4. **Only invent if truly new** - Use existing code when possible

**Example**: Task mentions "validation" → search The Pin for "validation", "validate", "checking" → use existing validation utilities if found

This protocol is enforced in all system instructions files.
