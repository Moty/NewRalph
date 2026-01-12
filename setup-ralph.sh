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
HAS_COPILOT=false

if command -v claude >/dev/null 2>&1; then
  HAS_CLAUDE=true
  echo -e "${GREEN}✓ Claude Code CLI found${NC}"
fi

if command -v codex >/dev/null 2>&1; then
  HAS_CODEX=true
  echo -e "${GREEN}✓ Codex CLI found${NC}"
fi

if command -v copilot >/dev/null 2>&1; then
  HAS_COPILOT=true
  echo -e "${GREEN}✓ GitHub Copilot CLI found${NC}"
fi

if [ "$HAS_CLAUDE" = false ] && [ "$HAS_CODEX" = false ] && [ "$HAS_COPILOT" = false ]; then
  echo -e "${RED}Error: No AI agent CLI found${NC}"
  echo "Install at least one:"
  echo "  Claude Code: https://docs.anthropic.com/claude/docs/cli"
  echo "  Codex: https://github.com/openai/codex-cli"
  echo "  GitHub Copilot CLI: npm install -g @github/copilot"
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

# Copy models helper script
echo "→ Copying ralph-models.sh"
cp "$RALPH_DIR/ralph-models.sh" "$TARGET_DIR/"
chmod +x "$TARGET_DIR/ralph-models.sh"

# Copy agent configuration
echo "→ Copying agent.yaml"
cp "$RALPH_DIR/agent.yaml" "$TARGET_DIR/"

# Copy system instructions
echo "→ Copying system_instructions/"
mkdir -p "$TARGET_DIR/system_instructions"
cp "$RALPH_DIR/system_instructions/system_instructions.md" "$TARGET_DIR/system_instructions/"
cp "$RALPH_DIR/system_instructions/system_instructions_codex.md" "$TARGET_DIR/system_instructions/"
cp "$RALPH_DIR/system_instructions/system_instructions_copilot.md" "$TARGET_DIR/system_instructions/"

# Copy lib directory with common functions
if [ -d "$RALPH_DIR/lib" ]; then
  echo "→ Copying lib/"
  mkdir -p "$TARGET_DIR/lib"
  cp -r "$RALPH_DIR/lib/"* "$TARGET_DIR/lib/"
fi

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

# Copy Windows wrapper scripts (if on Windows/WSL or requested)
if [ -d "$RALPH_DIR/windows" ]; then
  # Detect if we're in a Windows environment (WSL or MSYS/Git Bash)
  if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    echo "→ Copying Windows wrapper scripts (ralph.cmd, create-prd.cmd, ralph-models.cmd)"
    cp "$RALPH_DIR/windows/ralph.cmd" "$TARGET_DIR/" 2>/dev/null || true
    cp "$RALPH_DIR/windows/create-prd.cmd" "$TARGET_DIR/" 2>/dev/null || true
    cp "$RALPH_DIR/windows/ralph-models.cmd" "$TARGET_DIR/" 2>/dev/null || true
  fi
fi

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
ralph.log
.ralph-models-cache.json
archive/
EOF
  fi
else
  cat > "$TARGET_DIR/.gitignore" << 'EOF'
# Ralph
.last-branch
progress.txt
ralph.log
.ralph-models-cache.json
archive/
EOF
fi

# ---- Add technology-specific gitignore entries ------------------

# Node.js / JavaScript / TypeScript
if [ -f "$TARGET_DIR/package.json" ]; then
  echo "→ Detected Node.js project, updating .gitignore"
  if ! grep -q "^node_modules" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.pnpm-debug.log*
.npm
.yarn/cache
.yarn/unplugged
.yarn/install-state.gz
dist/
build/
.next/
.nuxt/
.output/
.cache/
coverage/
.env.local
.env.*.local
EOF
  fi
fi

# Python
if [ -f "$TARGET_DIR/requirements.txt" ] || [ -f "$TARGET_DIR/pyproject.toml" ] || [ -f "$TARGET_DIR/setup.py" ] || [ -f "$TARGET_DIR/Pipfile" ]; then
  echo "→ Detected Python project, updating .gitignore"
  if ! grep -q "^__pycache__" "$TARGET_DIR/.gitignore" 2>/dev/null && ! grep -q "^venv" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Python
__pycache__/
*.py[cod]
*$py.class
venv/
.venv/
env/
.env/
.Python
*.egg-info/
dist/
build/
.eggs/
*.egg
.pytest_cache/
.coverage
htmlcov/
.mypy_cache/
.ruff_cache/
EOF
  fi
fi

# Ruby
if [ -f "$TARGET_DIR/Gemfile" ]; then
  echo "→ Detected Ruby project, updating .gitignore"
  if ! grep -q "^vendor/bundle" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Ruby
vendor/bundle/
.bundle/
*.gem
coverage/
EOF
  fi
fi

# Go
if [ -f "$TARGET_DIR/go.mod" ]; then
  echo "→ Detected Go project, updating .gitignore"
  if ! grep -q "^vendor/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Go
vendor/
*.exe
*.exe~
*.dll
*.so
*.dylib
EOF
  fi
fi

# Rust
if [ -f "$TARGET_DIR/Cargo.toml" ]; then
  echo "→ Detected Rust project, updating .gitignore"
  if ! grep -q "^target/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Rust
target/
Cargo.lock
EOF
  fi
fi

# Java / Kotlin / Gradle / Maven
if [ -f "$TARGET_DIR/pom.xml" ] || [ -f "$TARGET_DIR/build.gradle" ] || [ -f "$TARGET_DIR/build.gradle.kts" ]; then
  echo "→ Detected Java/Kotlin project, updating .gitignore"
  if ! grep -q "^target/" "$TARGET_DIR/.gitignore" 2>/dev/null && ! grep -q "^build/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Java / Kotlin
target/
build/
.gradle/
*.class
*.jar
*.war
*.ear
.idea/
*.iml
EOF
  fi
fi

# .NET / C#
if ls "$TARGET_DIR"/*.csproj 1>/dev/null 2>&1 || ls "$TARGET_DIR"/*.sln 1>/dev/null 2>&1 || [ -d "$TARGET_DIR/obj" ]; then
  echo "→ Detected .NET project, updating .gitignore"
  if ! grep -q "^bin/" "$TARGET_DIR/.gitignore" 2>/dev/null && ! grep -q "^obj/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# .NET
bin/
obj/
*.user
*.suo
.vs/
EOF
  fi
fi

# PHP / Composer
if [ -f "$TARGET_DIR/composer.json" ]; then
  echo "→ Detected PHP project, updating .gitignore"
  if ! grep -q "^vendor/" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# PHP
vendor/
.phpunit.result.cache
EOF
  fi
fi

# ---- Configure agent ------------------------------------------

echo ""
echo "Configuring agent preference..."

AGENT_COUNT=0
[ "$HAS_CLAUDE" = true ] && ((AGENT_COUNT++))
[ "$HAS_CODEX" = true ] && ((AGENT_COUNT++))
[ "$HAS_COPILOT" = true ] && ((AGENT_COUNT++))

if [ "$AGENT_COUNT" -gt 1 ]; then
  echo "Multiple AI agents are available."
  echo "Which would you like as primary?"
  OPTION=1
  [ "$HAS_CLAUDE" = true ] && echo "  $OPTION) Claude Code" && CLAUDE_OPTION=$OPTION && ((OPTION++))
  [ "$HAS_CODEX" = true ] && echo "  $OPTION) Codex" && CODEX_OPTION=$OPTION && ((OPTION++))
  [ "$HAS_COPILOT" = true ] && echo "  $OPTION) GitHub Copilot CLI" && COPILOT_OPTION=$OPTION && ((OPTION++))
  
  read -p "Enter choice (1-$((OPTION-1))): " -n 1 -r CHOICE
  echo ""
  
  PRIMARY_SET=false
  FALLBACK_SET=false
  
  if [ "$HAS_CLAUDE" = true ] && [ "$CHOICE" == "$CLAUDE_OPTION" ]; then
    yq -i '.agent.primary = "claude-code"' "$TARGET_DIR/agent.yaml"
    PRIMARY_SET=true
    # Set fallback to first available alternative
    if [ "$HAS_CODEX" = true ]; then
      yq -i '.agent.fallback = "codex"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    elif [ "$HAS_COPILOT" = true ]; then
      yq -i '.agent.fallback = "github-copilot"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    fi
  elif [ "$HAS_CODEX" = true ] && [ "$CHOICE" == "$CODEX_OPTION" ]; then
    yq -i '.agent.primary = "codex"' "$TARGET_DIR/agent.yaml"
    PRIMARY_SET=true
    # Set fallback to first available alternative
    if [ "$HAS_CLAUDE" = true ]; then
      yq -i '.agent.fallback = "claude-code"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    elif [ "$HAS_COPILOT" = true ]; then
      yq -i '.agent.fallback = "github-copilot"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    fi
  elif [ "$HAS_COPILOT" = true ] && [ "$CHOICE" == "$COPILOT_OPTION" ]; then
    yq -i '.agent.primary = "github-copilot"' "$TARGET_DIR/agent.yaml"
    PRIMARY_SET=true
    # Set fallback to first available alternative
    if [ "$HAS_CLAUDE" = true ]; then
      yq -i '.agent.fallback = "claude-code"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    elif [ "$HAS_CODEX" = true ]; then
      yq -i '.agent.fallback = "codex"' "$TARGET_DIR/agent.yaml"
      FALLBACK_SET=true
    fi
  fi
  
  if [ "$PRIMARY_SET" = true ]; then
    PRIMARY_NAME=$(yq '.agent.primary' "$TARGET_DIR/agent.yaml")
    if [ "$FALLBACK_SET" = true ]; then
      FALLBACK_NAME=$(yq '.agent.fallback' "$TARGET_DIR/agent.yaml")
      echo -e "${GREEN}✓ Configured $PRIMARY_NAME as primary, $FALLBACK_NAME as fallback${NC}"
    else
      echo -e "${GREEN}✓ Configured $PRIMARY_NAME as primary (no fallback)${NC}"
    fi
  else
    # Invalid choice - use first available agent
    echo -e "${YELLOW}⚠ Invalid choice, using first available agent as default${NC}"
    if [ "$HAS_CLAUDE" = true ]; then
      yq -i '.agent.primary = "claude-code"' "$TARGET_DIR/agent.yaml"
      echo -e "${GREEN}✓ Configured Claude Code as primary${NC}"
    elif [ "$HAS_CODEX" = true ]; then
      yq -i '.agent.primary = "codex"' "$TARGET_DIR/agent.yaml"
      echo -e "${GREEN}✓ Configured Codex as primary${NC}"
    elif [ "$HAS_COPILOT" = true ]; then
      yq -i '.agent.primary = "github-copilot"' "$TARGET_DIR/agent.yaml"
      echo -e "${GREEN}✓ Configured GitHub Copilot CLI as primary${NC}"
    fi
  fi
elif [ "$HAS_CLAUDE" = true ]; then
  yq -i '.agent.primary = "claude-code"' "$TARGET_DIR/agent.yaml"
  yq -i 'del(.agent.fallback)' "$TARGET_DIR/agent.yaml"
  echo -e "${GREEN}✓ Configured Claude Code as primary (no fallback)${NC}"
elif [ "$HAS_CODEX" = true ]; then
  yq -i '.agent.primary = "codex"' "$TARGET_DIR/agent.yaml"
  yq -i 'del(.agent.fallback)' "$TARGET_DIR/agent.yaml"
  echo -e "${GREEN}✓ Configured Codex as primary (no fallback)${NC}"
elif [ "$HAS_COPILOT" = true ]; then
  yq -i '.agent.primary = "github-copilot"' "$TARGET_DIR/agent.yaml"
  yq -i 'del(.agent.fallback)' "$TARGET_DIR/agent.yaml"
  echo -e "${GREEN}✓ Configured GitHub Copilot CLI as primary (no fallback)${NC}"
fi

# ---- Refresh available models ---------------------------------

echo ""
echo "Detecting available models..."

# Run model refresh to populate cache
if [ -f "$TARGET_DIR/lib/model-refresh.sh" ]; then
  cd "$TARGET_DIR" || exit 1
  source lib/model-refresh.sh
  MODELS_CACHE="$TARGET_DIR/.ralph-models-cache.json"

  # Perform initial model detection (suppress verbose output)
  refresh_models >/dev/null 2>&1

  if [ -f "$MODELS_CACHE" ]; then
    echo -e "${GREEN}✓ Available models detected and cached${NC}"

    # Show quick summary
    claude_count=$(jq '.claude | length' "$MODELS_CACHE" 2>/dev/null || echo "0")
    codex_count=$(jq '.codex | length' "$MODELS_CACHE" 2>/dev/null || echo "0")

    echo "  • Claude models: $claude_count"
    echo "  • Codex models: $codex_count"
    echo ""
    echo "  Run ${CYAN}./ralph-models.sh${NC} to see full list"
  else
    echo -e "${YELLOW}⚠ Model detection completed (using defaults)${NC}"
  fi
else
  echo -e "${YELLOW}⚠ Model refresh utility not found (using static lists)${NC}"
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
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  echo "   ${YELLOW}ralph.cmd${NC}               # Windows (PowerShell/cmd)"
  echo "   ${YELLOW}bash ralph.sh${NC}           # WSL/Git Bash"
else
  echo "   ${YELLOW}./ralph.sh${NC}"
fi
echo ""
echo "Optional flags:"
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  echo "   ${YELLOW}ralph.cmd 20 --verbose${NC}         # Run 20 iterations with verbose logging"
  echo "   ${YELLOW}ralph.cmd --timeout 7200${NC}       # Set 2-hour timeout per iteration"
else
  echo "   ${YELLOW}./ralph.sh 20 --verbose${NC}         # Run 20 iterations with verbose logging"
  echo "   ${YELLOW}./ralph.sh --timeout 7200${NC}       # Set 2-hour timeout per iteration"
fi
echo ""
echo "Files created in $TARGET_DIR:"
echo "  • ralph.sh - Main execution script"
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
  echo "  • ralph.cmd - Windows wrapper for ralph.sh"
  echo "  • create-prd.cmd - Windows wrapper for create-prd.sh"
  echo "  • ralph-models.cmd - Windows wrapper for ralph-models.sh"
fi
echo "  • agent.yaml - Agent configuration"
echo "  • system_instructions/ - Agent prompts"
echo "  • lib/ - Validation and utility functions"
echo "  • prd.json - Project requirements"
echo "  • progress.txt - Iteration log"
echo "  • ralph.log - Debug log (verbose mode)"
echo "  • AGENTS.md - Pattern documentation"
echo "  • archive/ - Previous run backups"
if [ -d "$RALPH_DIR/skills" ]; then
  echo "  • skills/ - Reusable skills library"
fi
echo ""
