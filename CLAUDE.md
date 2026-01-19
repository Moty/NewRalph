# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Ralph?

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code, Codex, GitHub Copilot, or Gemini) repeatedly until all PRD items are complete. Each iteration spawns a fresh agent instance with clean context. Memory persists via git history, `progress.txt`, and `prd.json`.

## Commands

### Running Ralph (from a project with prd.json)
```bash
./ralph.sh [max_iterations]           # Default: 10 iterations
./ralph.sh --verbose                  # Enable debug logging
./ralph.sh --no-sleep-prevent         # Disable caffeinate/systemd-inhibit
./ralph.sh --timeout 3600             # Custom timeout per iteration (seconds)
./ralph.sh --check-update             # Check for updates
./ralph.sh --update                   # Self-update from source repo
./ralph.sh --push                     # Enable auto-push (override config)
./ralph.sh --no-push                  # Disable auto-push (override config)
./ralph.sh --create-pr                # Enable PR creation (override config)
./ralph.sh --no-pr                    # Disable PR creation (override config)
```

### Installing Ralph into a project
```bash
./setup-ralph.sh /path/to/project     # Fresh install
./setup-ralph.sh --update /path/to/project  # Update preserving config
./setup-ralph.sh --force /path/to/project   # Force overwrite all
```

### PRD Generation
```bash
./create-prd.sh "feature description"       # Auto-detect project type
./create-prd.sh --greenfield "description"  # New project from scratch
./create-prd.sh --brownfield "description"  # Existing codebase
./create-prd.sh --draft-only "description"  # PRD markdown only (skip JSON)
./create-prd.sh --model claude-opus "desc"  # Specify model
```

### Model Management
```bash
./ralph-models.sh                     # Show all models and cache
./ralph-models.sh --refresh           # Force refresh model cache
./ralph-models.sh config              # Show current configuration
```

### Flowchart (interactive visualization)

View the interactive flowchart at: https://snarktank.github.io/ralph/

## Architecture

### Core Execution Loop (`ralph.sh`)
1. Reads `prd.json` for user stories
2. Picks highest priority story where `passes: false`
3. Spawns fresh agent instance (configured in `agent.yaml`)
4. Agent implements story, runs quality checks, commits
5. Updates `prd.json` to mark `passes: true`
6. Appends learnings to `progress.txt`
7. Repeats until all stories pass or max iterations reached

### Library Structure (`lib/`)
- `common.sh` - Logging, colors, JSON validation, dependency checking
- `compaction.sh` - Memory compaction for long-running sessions (auto-triggers at 400 lines)
- `context.sh` - Task state management with dependency awareness
- `context-builder.sh` - Builds context for agent prompts
- `model-refresh.sh` - Model detection and caching
- `git.sh` - Git workflow operations (branch management, merge, push, PR creation)

**Bash compatibility**: All lib scripts must work with bash 3.2 (macOS default). Avoid associative arrays. Use `jq`'s `// empty` operator when accessing optional JSON fields.

### Skills (`skills/`)
- `prd/SKILL.md` - General PRD generation with clarifying questions
- `prd/GREENFIELD.md` - PRD for new projects (tech selection, scaffolding)
- `prd/BROWNFIELD.md` - PRD for existing codebases (integration patterns)
- `ralph/SKILL.md` - Converts PRD markdown to `prd.json` format

### System Instructions (`system_instructions/`)
Agent-specific prompts that define Ralph's autonomous behavior:
- `system_instructions.md` - Claude Code
- `system_instructions_codex.md` - Codex
- `system_instructions_copilot.md` - GitHub Copilot CLI

### Key Configuration Files
- `agent.yaml` - Agent selection (primary/fallback) and model settings
- `prd.json` - User stories with `passes` status and `blockedBy` dependencies
- `progress.txt` - Append-only learnings for future iterations
- `specs/INDEX.md` - The Pin: searchable index of existing functionality

## PRD and Story Structure

### prd.json Format
```json
{
  "project": "ProjectName",
  "branchName": "ralph/feature-name",
  "description": "Feature description",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": ["Criterion 1", "Typecheck passes"],
      "priority": 1,
      "blockedBy": [],
      "passes": false,
      "notes": ""
    }
  ]
}
```

### Story Dependencies (`blockedBy`)
- Database/schema stories: typically `[]` (no dependencies)
- Backend stories: blocked by schema they read/write
- UI stories: blocked by backend APIs they call
- Ralph skips blocked stories automatically

### Story Size Rule
Each story must complete in one context window. If it requires >2-3 sentences to describe, split it.

## Discovery Protocol (The Pin)

Before implementing new features, agents must:
1. Read `specs/INDEX.md` (searchable index)
2. Search keywords from the task
3. Read matching specs/files
4. Use existing code instead of duplicating

Generate/update The Pin: `./scripts/generate-pin.sh`

## Agent Configuration (agent.yaml)

Priority order when `primary: auto`: GitHub Copilot CLI → Claude Code → Gemini → Codex

```yaml
agent:
  primary: github-copilot  # or: claude-code, gemini, codex, auto
  fallback: codex

claude-code:
  model: claude-sonnet-4-20250514

codex:
  model: gpt-5.2-codex
  approval-mode: full-auto
  sandbox: full-access

github-copilot:
  model: auto
  tool-approval: allow-all

gemini:
  model: gemini-3-pro
  approval-mode: auto
```

## Git Workflow Configuration

Ralph uses a sub-branch workflow for better isolation and history:

```
main (stable)
  └── ralph/feature-name (feature branch)
        ├── ralph/feature-name/US-001 (sub-branch per story)
        │     └── merged back after story completes
        ├── ralph/feature-name/US-002
        │     └── merged back after story completes
        └── PR → main (when all stories complete)
```

### Workflow Summary
1. **setup-ralph.sh** creates the feature branch `ralph/feature-name` and pushes to GitHub
2. **ralph.sh** ensures the feature branch is checked out before each iteration
3. **Agent** creates sub-branch `ralph/feature-name/US-XXX` and commits there
4. **ralph.sh** merges sub-branch → feature branch with `--no-ff`, pushes, and deletes sub-branch
5. **ralph.sh** creates PR from feature branch → main when RALPH_COMPLETE

### Git Configuration (agent.yaml)

```yaml
git:
  auto-checkout-branch: true    # Ralph checkouts feature branch before spawning agent
  base-branch: main             # Branch to create feature branches from
  push:
    enabled: false              # Disabled by default for backward compatibility
    timing: iteration           # "iteration" (after each story) or "end" (after RALPH_COMPLETE)
  pr:
    enabled: false              # Disabled by default
    draft: false                # Create as draft PR
```

### CLI Overrides

Override git settings for a single run:
- `--push` / `--no-push` - Enable/disable auto-push
- `--create-pr` / `--no-pr` - Enable/disable PR creation

Example: `./ralph.sh --push --create-pr` enables both push and PR creation for this run.

## Key Patterns

- Each iteration = fresh agent instance with clean context
- Memory persists only via: git commits, `progress.txt`, `prd.json`
- Always update `AGENTS.md` files with discovered patterns
- Update `README.md` when implementing new features
- Frontend stories must include browser verification in acceptance criteria
- Quality checks (typecheck, lint, test) must pass before committing
- Stop condition: `RALPH_COMPLETE` output when all stories have `passes: true`
