# Ralph Agent Instructions

## Overview

Ralph is an autonomous AI agent loop that runs AI coding agents (Claude Code or Codex) repeatedly until all PRD items are complete. Each iteration is a fresh agent instance with clean context.

## Installation

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

## Commands

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

## Browser Verification Best Practices

When implementing UI stories, agents should follow these patterns:

### Starting Dev Servers
- Use async mode or background processes: `npm run dev &` or `yarn dev &`
- Add appropriate wait time after starting (usually 5-10 seconds)
- Check server is ready before navigation: `curl http://localhost:3000 || sleep 5`

### Effective Browser Testing
- **Use browser_snapshot first**: Shows the page's accessibility tree for debugging
- **Navigate to the specific page**: Use exact URLs (e.g., `http://localhost:3000/dashboard`)
- **Interact with real user flows**: Click buttons, fill forms, test the actual feature
- **Verify state changes**: After interactions, confirm the UI updated correctly
- **Take screenshots**: Document working features in your progress log

### Common Patterns
```bash
# Start dev server
npm run dev &
sleep 5

# Navigate and test
browser_navigate http://localhost:3000/dashboard
browser_snapshot  # Verify page loaded
browser_click "Submit button"
browser_snapshot  # Verify result
browser_take_screenshot dashboard-feature-working.png
```

### What NOT to Do
- Don't skip browser verification for UI stories - it catches visual bugs
- Don't just check the page loads - actually test the feature works
- Don't forget to verify error states and edge cases
- Don't proceed if browser shows errors or unexpected behavior

