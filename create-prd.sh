#!/bin/bash
# Automated PRD creation and conversion to Ralph format
# Usage: ./create-prd.sh "your project description"
# Supports: GitHub Copilot CLI (primary), Claude Code (fallback), Codex (last resort)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DESC="${1:-}"
DRAFT_ONLY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse flags
if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "create-prd.sh - Automated PRD generation and conversion"
  echo ""
  echo "Usage: ./create-prd.sh [OPTIONS] \"your project description\""
  echo ""
  echo "Options:"
  echo "  -h, --help        Show this help message"
  echo "  --draft-only      Generate PRD draft only (skip JSON conversion)"
  echo ""
  echo "Agent priority: GitHub Copilot CLI → Claude Code → Codex"
  echo ""
  echo "Example:"
  echo "  ./create-prd.sh \"A simple task management API with CRUD operations using Node.js and Express\""
  echo ""
  echo "Output:"
  echo "  - tasks/prd-draft.md   Markdown PRD document"
  echo "  - prd.json             Ralph-formatted JSON (unless --draft-only)"
  exit 0
fi

if [ "$1" = "--draft-only" ]; then
  DRAFT_ONLY=true
  shift
  PROJECT_DESC="${1:-}"
fi

if [ -z "$PROJECT_DESC" ]; then
  echo "Usage: ./create-prd.sh \"your project description\""
  echo "Run './create-prd.sh --help' for more options"
  exit 1
fi

# ---- Detect available agents --------------------------------------

AGENT=""
AGENT_NAME=""

# Priority 1: GitHub Copilot CLI
if command -v copilot &>/dev/null; then
  AGENT="copilot"
  AGENT_NAME="GitHub Copilot CLI"
# Priority 2: Claude Code
elif command -v claude &>/dev/null; then
  AGENT="claude"
  AGENT_NAME="Claude Code"
elif [ -x "$HOME/.local/bin/claude" ]; then
  AGENT="$HOME/.local/bin/claude"
  AGENT_NAME="Claude Code"
# Priority 3: Codex
elif command -v codex &>/dev/null; then
  AGENT="codex"
  AGENT_NAME="Codex"
else
  echo -e "${RED}Error: No AI agent found.${NC}"
  echo "Please install one of the following:"
  echo "  • GitHub Copilot CLI: https://github.com/github/gh-copilot"
  echo "  • Claude Code: https://docs.anthropic.com/claude/docs/cli"
  echo "  • Codex: npm install -g @openai/codex"
  exit 1
fi

echo -e "${GREEN}Using agent: ${CYAN}$AGENT_NAME${NC}"
echo ""

# ---- Agent-specific run functions ---------------------------------

run_copilot() {
  local prompt="$1"
  copilot -p "$prompt" --allow-all-tools
}

run_claude() {
  local prompt="$1"
  local claude_cmd="$AGENT"
  [ "$AGENT" = "claude" ] && claude_cmd="claude"
  "$claude_cmd" --print --dangerously-skip-permissions "$prompt"
}

run_codex() {
  local prompt="$1"
  codex exec --full-auto "$prompt"
}

run_agent() {
  local prompt="$1"
  case "$AGENT" in
    copilot) run_copilot "$prompt" ;;
    claude|"$HOME/.local/bin/claude") run_claude "$prompt" ;;
    codex) run_codex "$prompt" ;;
    *) echo -e "${RED}Unknown agent: $AGENT${NC}"; exit 1 ;;
  esac
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Generating PRD..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create tasks directory if it doesn't exist
mkdir -p tasks

# Generate PRD using the detected agent with the PRD skill
run_agent "Load the prd skill from $SCRIPT_DIR/skills/prd/SKILL.md and create a PRD for: $PROJECT_DESC

Answer all clarifying questions with reasonable defaults and generate the complete PRD. Save it to tasks/prd-draft.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Converting PRD to Ralph JSON format..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if PRD was created
if [ ! -f "tasks/prd-draft.md" ]; then
  echo -e "${RED}Error: PRD file not found at tasks/prd-draft.md${NC}"
  exit 1
fi

# If draft-only mode, skip conversion
if [ "$DRAFT_ONLY" = true ]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}✓ PRD Draft Complete!${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "File created:"
  echo "  • tasks/prd-draft.md - Original PRD"
  echo ""
  echo "Next steps:"
  echo "  1. Review tasks/prd-draft.md"
  echo "  2. Run without --draft-only to convert to prd.json"
  echo "  3. Or manually convert: Load the ralph skill and convert tasks/prd-draft.md"
  echo ""
  exit 0
fi

# Warn if prd.json already exists
if [ -f "prd.json" ]; then
  echo ""
  echo -e "${YELLOW}⚠️  Warning: prd.json already exists in this directory.${NC}"
  echo "   Continuing will overwrite the existing file."
  echo ""
  read -p "Continue? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled. Your existing prd.json was not modified."
    exit 0
  fi
fi

# Convert PRD to prd.json using the detected agent with the Ralph skill
run_agent "Load the ralph skill from $SCRIPT_DIR/skills/ralph/SKILL.md and convert tasks/prd-draft.md to prd.json.

Make sure each story is small and completable in one iteration. Save the output to prd.json in the current directory."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓ PRD Creation Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Files created:"
echo "  • tasks/prd-draft.md - Original PRD"
echo "  • prd.json - Ralph-formatted requirements"
echo ""
echo "Next steps:"
echo "  1. Review prd.json to ensure stories are appropriately sized"
echo "  2. Run Ralph: ./ralph.sh"
echo ""
