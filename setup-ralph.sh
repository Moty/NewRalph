#!/bin/bash
# Ralph Setup Script - Install or Update Ralph in any project repository
# Usage: ./setup-ralph.sh [OPTIONS] /path/to/your/project

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR=""
UPDATE_MODE=false
FORCE_MODE=false

# Ralph version - update this when making releases
RALPH_VERSION="1.2.0"
RALPH_VERSION_DATE="2026-01-25"

# Show usage if help requested
show_help() {
  echo "Ralph Setup Script v${RALPH_VERSION}"
  echo ""
  echo "Usage: ./setup-ralph.sh [OPTIONS] [target-directory]"
  echo ""
  echo "Installs or updates Ralph in the specified project directory."
  echo "If no directory is specified, uses current directory."
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  --update       Update existing Ralph installation (preserves agent.yaml settings)"
  echo "  --force        Force overwrite all files including agent.yaml"
  echo "  --version      Show Ralph version"
  echo ""
  echo "Examples:"
  echo "  ./setup-ralph.sh /path/to/my/project       # Fresh install"
  echo "  ./setup-ralph.sh --update /path/to/project # Update existing installation"
  echo "  ./setup-ralph.sh --update .                # Update current directory"
  echo ""
  echo "Update mode:"
  echo "  - Updates core scripts (ralph.sh, create-prd.sh, lib/, skills/)"
  echo "  - Preserves your agent.yaml configuration (merges new options)"
  echo "  - Preserves prd.json, progress.txt, AGENTS.md"
  echo "  - Creates backup of changed files in .ralph-backup/"
  echo ""
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_help
      ;;
    --update)
      UPDATE_MODE=true
      shift
      ;;
    --force)
      FORCE_MODE=true
      shift
      ;;
    --version)
      echo "Ralph v${RALPH_VERSION} (${RALPH_VERSION_DATE})"
      exit 0
      ;;
    *)
      if [ -z "$TARGET_DIR" ]; then
        TARGET_DIR="$1"
      fi
      shift
      ;;
  esac
done

# Default to current directory if not specified
TARGET_DIR="${TARGET_DIR:-.}"

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

# ---- Detect existing installation -----------------------------

EXISTING_VERSION=""
EXISTING_INSTALL=false
VERSION_FILE="$TARGET_DIR/.ralph-version"

if [ -f "$VERSION_FILE" ]; then
  # Parse version from new format (version=X.X.X) or old format (just version number)
  EXISTING_VERSION=$(grep '^version=' "$VERSION_FILE" 2>/dev/null | sed 's/version=//' || head -n 1 "$VERSION_FILE")
  EXISTING_INSTALL=true
elif [ -f "$TARGET_DIR/ralph.sh" ]; then
  EXISTING_VERSION="pre-1.0 (no version file)"
  EXISTING_INSTALL=true
fi

if [ "$EXISTING_INSTALL" = true ]; then
  echo ""
  echo -e "${CYAN}Existing Ralph installation detected${NC}"
  echo "  Installed version: ${YELLOW}${EXISTING_VERSION}${NC}"
  echo "  New version:       ${GREEN}${RALPH_VERSION}${NC}"
  echo ""
  
  if [ "$UPDATE_MODE" = false ] && [ "$FORCE_MODE" = false ]; then
    echo -e "${YELLOW}Use --update to update while preserving your configuration${NC}"
    echo -e "${YELLOW}Use --force to overwrite everything${NC}"
    echo ""
    read -p "Continue with update mode? (Y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
      exit 0
    fi
    UPDATE_MODE=true
  fi
fi

# ---- Backup function for updates -----------------------------

BACKUP_DIR="$TARGET_DIR/.ralph-backup/$(date +%Y%m%d-%H%M%S)"
BACKUP_CREATED=false

backup_file() {
  local file="$1"
  if [ -f "$TARGET_DIR/$file" ]; then
    if [ "$BACKUP_CREATED" = false ]; then
      mkdir -p "$BACKUP_DIR"
      BACKUP_CREATED=true
    fi
    cp "$TARGET_DIR/$file" "$BACKUP_DIR/"
    echo "  → Backed up: $file"
  fi
}

# ---- Merge agent.yaml function --------------------------------

merge_agent_yaml() {
  local old_yaml="$TARGET_DIR/agent.yaml"
  local new_yaml="$RALPH_DIR/agent.yaml"
  local temp_yaml="$TARGET_DIR/agent.yaml.new"
  
  if [ ! -f "$old_yaml" ]; then
    # No existing config, just copy
    cp "$new_yaml" "$old_yaml"
    return
  fi
  
  # Backup existing
  backup_file "agent.yaml"
  
  # Extract user's current settings
  local user_primary=$(yq '.agent.primary // "auto"' "$old_yaml" 2>/dev/null)
  local user_fallback=$(yq '.agent.fallback // ""' "$old_yaml" 2>/dev/null)
  local user_claude_model=$(yq '.claude-code.model // ""' "$old_yaml" 2>/dev/null)
  local user_codex_model=$(yq '.codex.model // ""' "$old_yaml" 2>/dev/null)
  local user_codex_approval=$(yq '.codex.approval-mode // ""' "$old_yaml" 2>/dev/null)
  local user_codex_sandbox=$(yq '.codex.sandbox // ""' "$old_yaml" 2>/dev/null)
  local user_copilot_model=$(yq '.github-copilot.model // ""' "$old_yaml" 2>/dev/null)
  local user_copilot_approval=$(yq '.github-copilot.tool-approval // ""' "$old_yaml" 2>/dev/null)
  local user_gemini_model=$(yq '.gemini.model // ""' "$old_yaml" 2>/dev/null)
  local user_gemini_approval=$(yq '.gemini.approval-mode // ""' "$old_yaml" 2>/dev/null)
  local user_git_push_enabled=$(yq '.git.push.enabled // ""' "$old_yaml" 2>/dev/null)
  local user_git_push_timing=$(yq '.git.push.timing // ""' "$old_yaml" 2>/dev/null)
  local user_git_pr_enabled=$(yq '.git.pr.enabled // ""' "$old_yaml" 2>/dev/null)
  local user_git_pr_draft=$(yq '.git.pr.draft // ""' "$old_yaml" 2>/dev/null)
  local user_git_pr_auto_merge=$(yq '.git.pr.auto-merge // ""' "$old_yaml" 2>/dev/null)
  local user_git_base_branch=$(yq '.git.base-branch // ""' "$old_yaml" 2>/dev/null)
  local user_git_auto_checkout=$(yq '.git.auto-checkout-branch // ""' "$old_yaml" 2>/dev/null)

  # Start with new template (has new options)
  cp "$new_yaml" "$temp_yaml"

  # Restore user's agent settings
  [ -n "$user_primary" ] && [ "$user_primary" != "null" ] && yq -i ".agent.primary = \"$user_primary\"" "$temp_yaml"
  [ -n "$user_fallback" ] && [ "$user_fallback" != "null" ] && [ "$user_fallback" != "" ] && yq -i ".agent.fallback = \"$user_fallback\"" "$temp_yaml"
  [ -n "$user_claude_model" ] && [ "$user_claude_model" != "null" ] && yq -i ".claude-code.model = \"$user_claude_model\"" "$temp_yaml"
  [ -n "$user_codex_model" ] && [ "$user_codex_model" != "null" ] && yq -i ".codex.model = \"$user_codex_model\"" "$temp_yaml"
  [ -n "$user_codex_approval" ] && [ "$user_codex_approval" != "null" ] && yq -i ".codex.approval-mode = \"$user_codex_approval\"" "$temp_yaml"
  [ -n "$user_codex_sandbox" ] && [ "$user_codex_sandbox" != "null" ] && yq -i ".codex.sandbox = \"$user_codex_sandbox\"" "$temp_yaml"
  [ -n "$user_copilot_model" ] && [ "$user_copilot_model" != "null" ] && yq -i ".github-copilot.model = \"$user_copilot_model\"" "$temp_yaml"
  [ -n "$user_copilot_approval" ] && [ "$user_copilot_approval" != "null" ] && yq -i ".github-copilot.tool-approval = \"$user_copilot_approval\"" "$temp_yaml"
  [ -n "$user_gemini_model" ] && [ "$user_gemini_model" != "null" ] && yq -i ".gemini.model = \"$user_gemini_model\"" "$temp_yaml"
  [ -n "$user_gemini_approval" ] && [ "$user_gemini_approval" != "null" ] && yq -i ".gemini.approval-mode = \"$user_gemini_approval\"" "$temp_yaml"

  # Restore user's git settings
  [ -n "$user_git_push_enabled" ] && [ "$user_git_push_enabled" != "null" ] && yq -i ".git.push.enabled = $user_git_push_enabled" "$temp_yaml"
  [ -n "$user_git_push_timing" ] && [ "$user_git_push_timing" != "null" ] && yq -i ".git.push.timing = \"$user_git_push_timing\"" "$temp_yaml"
  [ -n "$user_git_pr_enabled" ] && [ "$user_git_pr_enabled" != "null" ] && yq -i ".git.pr.enabled = $user_git_pr_enabled" "$temp_yaml"
  [ -n "$user_git_pr_draft" ] && [ "$user_git_pr_draft" != "null" ] && yq -i ".git.pr.draft = $user_git_pr_draft" "$temp_yaml"
  [ -n "$user_git_pr_auto_merge" ] && [ "$user_git_pr_auto_merge" != "null" ] && yq -i ".git.pr.auto-merge = $user_git_pr_auto_merge" "$temp_yaml"
  [ -n "$user_git_base_branch" ] && [ "$user_git_base_branch" != "null" ] && yq -i ".git.base-branch = \"$user_git_base_branch\"" "$temp_yaml"
  [ -n "$user_git_auto_checkout" ] && [ "$user_git_auto_checkout" != "null" ] && yq -i ".git.auto-checkout-branch = $user_git_auto_checkout" "$temp_yaml"
  
  # Replace old with merged
  mv "$temp_yaml" "$old_yaml"
  echo -e "  ${GREEN}✓ Merged agent.yaml (preserved your settings, added new options)${NC}"
}

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
if [ "$UPDATE_MODE" = true ]; then
  echo -e "${CYAN}Updating Ralph in: $TARGET_DIR${NC}"
  echo ""
  if [ "$BACKUP_CREATED" = false ]; then
    echo "Creating backups..."
  fi
else
  echo "Installing Ralph into: $TARGET_DIR"
fi
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

# Copy agent configuration (with merge for updates)
if [ "$UPDATE_MODE" = true ] && [ "$FORCE_MODE" = false ]; then
  echo "→ Updating agent.yaml (preserving your settings)"
  merge_agent_yaml
else
  echo "→ Copying agent.yaml"
  cp "$RALPH_DIR/agent.yaml" "$TARGET_DIR/"
fi

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

# Copy scripts (discovery tools)
if [ -d "$RALPH_DIR/scripts" ]; then
  echo "→ Copying scripts/"
  mkdir -p "$TARGET_DIR/scripts"
  cp -r "$RALPH_DIR/scripts/"* "$TARGET_DIR/scripts/"
  chmod +x "$TARGET_DIR/scripts/"*.sh 2>/dev/null || true
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
GITIGNORE="$TARGET_DIR/.gitignore"
touch "$GITIGNORE"

ensure_gitignore_entry() {
  local entry="$1"
  if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
    echo "$entry" >> "$GITIGNORE"
  fi
}

# Add Ralph header if missing
if ! grep -q "^# Ralph" "$GITIGNORE"; then
  echo "" >> "$GITIGNORE"
  echo "# Ralph" >> "$GITIGNORE"
fi

ensure_gitignore_entry ".last-branch"
ensure_gitignore_entry ".ralph-version"
ensure_gitignore_entry ".ralph-backup/"
ensure_gitignore_entry "progress.txt"
ensure_gitignore_entry "ralph.log"
ensure_gitignore_entry ".ralph-models-cache.json"
ensure_gitignore_entry "archive/"
ensure_gitignore_entry ".ralph/repl/"
ensure_gitignore_entry ".ralph/context.json"
ensure_gitignore_entry "node_modules/"

# Universal OS/editor entries
if ! grep -q "^# OS" "$GITIGNORE"; then
  echo "" >> "$GITIGNORE"
  echo "# OS generated files" >> "$GITIGNORE"
fi
ensure_gitignore_entry ".DS_Store"
ensure_gitignore_entry "**/.DS_Store"
ensure_gitignore_entry "._*"
ensure_gitignore_entry "Thumbs.db"
ensure_gitignore_entry "desktop.ini"

# Environment files (secrets)
ensure_gitignore_entry ".env"

# Editor swap files
ensure_gitignore_entry "*.swp"
ensure_gitignore_entry "*.swo"

# ---- Add technology-specific gitignore entries ------------------

# Node.js / JavaScript / TypeScript
if [ -f "$TARGET_DIR/package.json" ]; then
  echo "→ Detected Node.js project, updating .gitignore"
  if ! grep -q "^npm-debug.log" "$TARGET_DIR/.gitignore" 2>/dev/null; then
    cat >> "$TARGET_DIR/.gitignore" << 'EOF'

# Node.js
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

# Skip agent configuration in update mode (settings are preserved)
if [ "$UPDATE_MODE" = true ] && [ "$FORCE_MODE" = false ]; then
  echo ""
  echo -e "${GREEN}✓ Agent configuration preserved from existing installation${NC}"
else
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
fi  # End of UPDATE_MODE check

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

# Write version file with source repo for self-update capability
cat > "$TARGET_DIR/.ralph-version" << EOF
version=$RALPH_VERSION
date=$RALPH_VERSION_DATE
source=$RALPH_DIR
EOF

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
if [ "$UPDATE_MODE" = true ]; then
  echo -e "${GREEN}✓ Ralph updated to v${RALPH_VERSION}!${NC}"
else
  echo -e "${GREEN}✓ Ralph v${RALPH_VERSION} setup complete!${NC}"
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$BACKUP_CREATED" = true ]; then
  echo -e "Backups saved to: ${CYAN}${BACKUP_DIR}${NC}"
  echo ""
fi

if [ "$UPDATE_MODE" = true ]; then
  echo "Updated files:"
  echo "  • ralph.sh, create-prd.sh, ralph-models.sh"
  echo "  • system_instructions/"
  echo "  • lib/"
  echo "  • skills/"
  echo "  • scripts/"
  if [ "$FORCE_MODE" = false ]; then
    echo ""
    echo -e "Preserved: ${YELLOW}agent.yaml${NC} (settings merged), prd.json, progress.txt, AGENTS.md"
  fi
  echo ""
  echo "Run ${CYAN}./ralph.sh${NC} to continue with updated version"
else
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
  if [ -d "$RALPH_DIR/scripts" ]; then
    echo "  • scripts/ - Discovery tools (generate-pin.sh)"
  fi
fi
echo ""


# ---- Git Commit -----------------------------------------------

if [ -d "$TARGET_DIR/.git" ]; then
  cd "$TARGET_DIR"
  if [ "$UPDATE_MODE" = true ]; then
    # Only commit if there are changes
    if ! git diff --quiet HEAD -- ralph.sh create-prd.sh ralph-models.sh agent.yaml lib/ skills/ scripts/ system_instructions/ .gitignore 2>/dev/null; then
      echo "Creating commit with Ralph update..."
      git add ralph.sh create-prd.sh ralph-models.sh agent.yaml lib/ skills/ system_instructions/ .ralph-version .gitignore 2>/dev/null || true
      [ -d scripts ] && git add scripts/ 2>/dev/null || true
      git commit -m "Update Ralph to v${RALPH_VERSION}" 2>/dev/null || true
      echo -e "${GREEN}✓ Update committed${NC}"
    fi
  else
    echo "Creating initial commit with Ralph setup..."
    git add -A && git commit -m "Initial commit with Ralph v${RALPH_VERSION} setup"
    echo -e "${GREEN}✓ Initial commit created${NC}"
  fi
  echo ""
fi

# ---- Feature Branch Setup (for fresh installs) ------------------

if [ -d "$TARGET_DIR/.git" ] && [ "$UPDATE_MODE" = false ] && [ -f "$TARGET_DIR/prd.json" ]; then
  cd "$TARGET_DIR"

  # Read branch name from prd.json
  FEATURE_BRANCH=$(jq -r '.branchName // empty' prd.json 2>/dev/null)

  if [ -n "$FEATURE_BRANCH" ] && [ "$FEATURE_BRANCH" != "null" ]; then
    echo "Setting up feature branch: $FEATURE_BRANCH"

    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/$FEATURE_BRANCH" 2>/dev/null; then
      echo -e "${YELLOW}Branch $FEATURE_BRANCH already exists locally${NC}"
    else
      # Create the feature branch
      git checkout -b "$FEATURE_BRANCH"
      echo -e "${GREEN}✓ Created branch: $FEATURE_BRANCH${NC}"

      # Push to remote if origin exists
      if git remote get-url origin >/dev/null 2>&1; then
        echo "Pushing branch to remote..."
        if git push -u origin "$FEATURE_BRANCH" 2>/dev/null; then
          echo -e "${GREEN}✓ Pushed branch to origin${NC}"
        else
          echo -e "${YELLOW}⚠ Could not push to remote (check permissions)${NC}"
        fi
      else
        echo -e "${YELLOW}⚠ No remote 'origin' configured, branch stays local${NC}"
      fi
    fi
    echo ""
  fi
fi