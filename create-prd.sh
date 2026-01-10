#!/bin/bash
# Automated PRD creation and conversion to Ralph format
# Usage: ./create-prd.sh "your project description"

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DESC="${1:-}"

if [ -z "$PROJECT_DESC" ]; then
  echo "Usage: ./create-prd.sh \"your project description\""
  echo ""
  echo "Example:"
  echo "  ./create-prd.sh \"A simple task management API with CRUD operations using Node.js and Express\""
  exit 1
fi

# Find claude command
CLAUDE_CMD=$(command -v claude || echo "$HOME/.local/bin/claude")

if [ ! -x "$CLAUDE_CMD" ]; then
  echo "Error: Claude CLI not found. Please install Claude Code first."
  exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Generating PRD..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create tasks directory if it doesn't exist
mkdir -p tasks

# Generate PRD using Claude with the PRD skill
"$CLAUDE_CMD" --print \
  --dangerously-skip-permissions \
  "Load the prd skill from $SCRIPT_DIR/skills/prd/SKILL.md and create a PRD for: $PROJECT_DESC

Answer all clarifying questions with reasonable defaults and generate the complete PRD. Save it to tasks/prd-draft.md"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Converting PRD to Ralph JSON format..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if PRD was created
if [ ! -f "tasks/prd-draft.md" ]; then
  echo "Error: PRD file not found at tasks/prd-draft.md"
  exit 1
fi

# Convert PRD to prd.json using Claude with the Ralph skill
"$CLAUDE_CMD" --print \
  --dangerously-skip-permissions \
  "Load the ralph skill from $SCRIPT_DIR/skills/ralph/SKILL.md and convert tasks/prd-draft.md to prd.json. 

Make sure each story is small and completable in one iteration. Save the output to prd.json in the current directory."

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ PRD Creation Complete!"
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
