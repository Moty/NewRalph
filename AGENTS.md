# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code or Codex) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context.

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

## Commands

### Linux/macOS

```bash
# Run the setup script
./setup-ralph.sh /path/to/project

# Run the flowchart dev server
cd flowchart && npm run dev

# Build the flowchart
cd flowchart && npm run build

# Run Ralph (from your project that has prd.json)
./ralph.sh [max_iterations]
```

### Windows

```powershell
# Run the setup script (from Ralph repo)
ralph-setup C:\path\to\project

# In your project directory - use .cmd wrappers
ralph.cmd [max_iterations]        # Run Ralph
create-prd.cmd "description"       # Generate PRD
ralph-models.cmd --refresh         # List available models

# Or use bash directly in WSL/Git Bash
bash ralph.sh [max_iterations]
```

## Key Files

- `setup-ralph.sh` - Automated installation script for any project
- `create-prd.sh` - Automated PRD generation and conversion script
- `ralph.sh` - The bash loop that spawns fresh agent instances
- `ralph-models.sh` - Model listing and cache management utility
- `agent.yaml` - Configuration for primary/fallback agent selection
- `system_instructions/system_instructions.md` - Instructions for Claude Code
- `system_instructions/system_instructions_codex.md` - Instructions for Codex
- `prd.json.example` - Example PRD format
- `skills/prd/` - Skill for generating PRDs
- `skills/ralph/` - Skill for converting PRDs to JSON
- `flowchart/` - Interactive React Flow diagram explaining how Ralph works
- `prompt.md` - Legacy prompt file (optional)

## Flowchart

The `flowchart/` directory contains an interactive visualization built with React Flow. It's designed for presentations - click through to reveal each step with animations.

To run locally:
```bash
cd flowchart
npm install
npm run dev
```

## Patterns

- Each iteration spawns a fresh agent instance (Claude Code or Codex) with clean context
- Memory persists via git history, `progress.txt`, and `prd.json`
- Stories should be small enough to complete in one context window
- Always update AGENTS.md with discovered patterns for future iterations
- Agent selection is configured in `agent.yaml` with optional fallback support
