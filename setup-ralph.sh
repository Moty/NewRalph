#!/bin/bash
# Ralph Setup Script - Install Ralph into any project repository
# Usage: ./setup-ralph.sh /path/to/your/project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-.}"

# Show usage if help requested
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  echo "Ralph Setup Script"
  echo ""
  echo "Usage: ./setup-ralph.sh [target-directory]"
  echo ""
  echo "Installs Ralph into the specified project directory."
  echo "If no directory is specified, uses current directory."
  echo ""
  echo "Example:"
  echo "  ./setup-ralph.sh /path/to/my/project"
  echo "  ./setup-ralph.sh ."
  echo ""
  exit 0
fi

# ---- Validation -----------------------------------------------

if [ ! -d "$TARGET_DIR" ]; then
  echo -e "${RED}Error: Target directory does not exist: $TARGET_DIR${NC}"
  exit 1
fi

if [ ! -d "$TARGET_DIR/.git" ]; then
  echo -e "${YELLOW}Warning: Target directory is not a git repository${NC}"
  read -p "Continue anyway? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# ---- Check dependencies ---------------------------------------

echo "Checking dependencies..."

command -v jq >/dev/null 2>&1 || {
  echo -e "${RED}Missing required tool: jq${NC}"
  echo "Install with: brew install jq"
  exit 1
}

command -v yq >/dev/null 2>&1 || {
  echo -e "${RED}Missing required tool: yq${NC}"
  echo "Install with: brew install yq"
  exit 1
}

HAS_CLAUDE=false
HAS_CODEX=false

if command -v claude >/dev/null 2>&1; then
  HAS_CLAUDE=true
  echo -e "${GREEN}✓ Claude Code CLI found${NC}"
fi

if command -v codex >/dev/null 2>&1; then
  HAS_CODEX=true
  echo -e "${GREEN}✓ Codex CLI found${NC}"
fi

if [ "$HAS_CLAUDE" = false ] && [ "$HAS_CODEX" = false ]; then
  echo -e "${RED}Error: Neither Claude Code nor Codex CLI found${NC}"
  echo "Install at least one:"
  echo "  Claude Code: https://docs.anthropic.com/claude/docs/cli"
  echo "  Codex: https://github.com/openai/codex-cli"
  exit 1
fi

# ---- Copy files -----------------------------------------------

echo ""
echo "Installing Ralph into: $TARGET_DIR"
echo ""

# Copy main script
echo "→ Copying ralph.sh"
cp "$RALPH_DIR/ralph.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/ralph.sh"

# Copy PRD creation script
echo "→ Copying create-prd.sh"
cp "$RALPH_DIR/create-prd.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/create-prd.sh"

# Copy agent configuration
echo "→ Copying agent.yaml"
cp "$RALPH_DIR/agent.yaml" "$TARGET_DIR/"

# Copy system instructions
echo "→ Copying system_instructions/"
mkdir -p "$TARGET_DIR/system_instructions"
cp "$RALPH_DIR/system_instructions/system_instructions.md" "$TARGET_DIR/system_instructions/"
cp "$RALPH_DIR/system_instructions/system_instructions_codex.md" "$TARGET_DIR/system_instructions/"

# Copy skills (optional)
if [ -d "$RALPH_DIR/skills" ]; then
  echo "→ Copying skills/"
  cp -r "$RALPH_DIR/skills" "$TARGET_DIR/"
fi

# Create PRD from example
if [ ! -f "$TARGET_DIR/prd.json" ]; then
  echo "→ Creating prd.json from example"
  cp "$RALPH_DIR/prd.json.example" "$TARGET_DIR/prd.json"
else
  echo "→ Skipping prd.json (already exists)"
fi

# Create progress file
if [ ! -f "$TARGET_DIR/progress.txt" ]; then
  echo "→ Creating progress.txt"
  echo "# Ralph Progress Log" > "$TARGET_DIR/progress.txt"
  echo "Started: $(date)" >> "$TARGET_DIR/progress.txt"
  echo "---" >> "$TARGET_DIR/progress.txt"
else
  echo "→ Skipping progress.txt (already exists)"
fi

# Create archive directory
echo "→ Creating archive/"
mkdir -p "$TARGET_DIR/archive"

# Copy AGENTS.md template
if [ ! -f "$TARGET_DIR/AGENTS.md" ]; then
  echo "→ Creating AGENTS.md"
  cat > "$TARGET_DIR/AGENTS.md" << 'EOF'
# Agent Learnings

This file tracks patterns and learnings discovered during Ralph iterations.

## Patterns

*Document patterns here as they emerge*

## Common Issues

*Document recurring issues and solutions*

## Architecture Notes

*Document important architectural decisions*
EOF
else
  echo "→ Skipping AGENTS.md (already exists)"
fi

# Update .gitignore
echo "→ Updating .gitignore"
if [ -f "$TARGET_DIR/.gitignore" ]; then
  if ! grep -q "^# Ralph" "$TARGET_DIR/.gitignore"; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Ralph
.last-branch
progress.txt
archive/
EOF
  fi
else
  cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Ralph
.last-branch
progress.txt
archive/
EOF
fi

# ---- Configure agent ------------------------------------------

echo ""
echo "Configuring agent preference..."

if [ "$HAS_CLAUDE" = true ] && [ "$HAS_CODEX" = true ]; then
  echo "Both Claude Code and Codex are available."
  echo "Which would you like as primary?"
  echo "  1) Claude Code"
  echo "  2) Codex"
  read -p "Enter choice (1-2): " -n 1 -r CHOICE
  echo ""
  
  if [[ $CHOICE == "2" ]]; then
    yq -i '.agent.primary = "codex"' "$TARGET_DIR/agent.yaml"
    yq -i '.agent.fallback = "claude-code"' "$TARGET_DIR/agent.yaml"
    echo -e "${GREEN}✓ Configured Codex as primary, Claude Code as fallback${NC}"
  else
    yq -i '.agent.primary = "claude-code"' "$TARGET_DIR/agent.yaml"
    yq -i '.agent.fallback = "codex"' "$TARGET_DIR/agent.yaml"
    echo -e "${GREEN}✓ Configured Claude Code as primary, Codex as fallback${NC}"
  fi
elif [ "$HAS_CLAUDE" = true ]; then
  yq -i '.agent.primary = "claude-code"' "$TARGET_DIR/agent.yaml"
  yq -i 'del(.agent.fallback)' "$TARGET_DIR/agent.yaml"
  echo -e "${GREEN}✓ Configured Claude Code as primary (no fallback)${NC}"
else
  yq -i '.agent.primary = "codex"' "$TARGET_DIR/agent.yaml"
  yq -i 'del(.agent.fallback)' "$TARGET_DIR/agent.yaml"
  echo -e "${GREEN}✓ Configured Codex as primary (no fallback)${NC}"
fi

# ---- Setup complete -------------------------------------------

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Ralph setup complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit prd.json to define your project requirements:"
echo "   ${YELLOW}cd $TARGET_DIR && vim prd.json${NC}"
echo ""
echo "2. Review and customize agent.yaml if needed:"
echo "   ${YELLOW}vim agent.yaml${NC}"
echo ""
echo "3. Run Ralph:"
echo "   ${YELLOW}./ralph.sh${NC}"
echo ""
echo "Files created in $TARGET_DIR:"
echo "  • ralph.sh - Main execution script"
echo "  • agent.yaml - Agent configuration"
echo "  • system_instructions/ - Agent prompts"
echo "  • prd.json - Project requirements"
echo "  • progress.txt - Iteration log"
echo "  • AGENTS.md - Pattern documentation"
echo "  • archive/ - Previous run backups"
if [ -d "$RALPH_DIR/skills" ]; then
  echo "  • skills/ - Reusable skills library"
fi
echo ""
