#!/bin/bash
# ralph-models.sh - List available models for each agent
# Usage: ./ralph-models.sh [agent-name]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_CONFIG="$SCRIPT_DIR/agent.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Ralph Available Models${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Claude Code models
show_claude_models() {
  echo -e "${BLUE}Claude Code${NC} (via claude CLI)"
  echo -e "  ${YELLOW}Current:${NC} $(yq '.claude-code.model // "claude-sonnet-4-20250514"' "$AGENT_CONFIG" 2>/dev/null)"
  echo ""
  echo -e "  ${GREEN}Available models:${NC}"
  echo "    • claude-sonnet-4-20250514 (recommended, fast)"
  echo "    • claude-opus-4-20250514   (powerful, slower)"
  echo "    • claude-3-5-sonnet-20241022"
  echo "    • claude-3-5-haiku-20241022"
  echo ""
  
  CLAUDE_CMD=""
  if command -v claude &>/dev/null; then
    CLAUDE_CMD="claude"
  elif [ -x "$HOME/.local/bin/claude" ]; then
    CLAUDE_CMD="$HOME/.local/bin/claude"
  fi
  
  if [ -n "$CLAUDE_CMD" ]; then
    echo -e "  ${GREEN}CLI found:${NC} $("$CLAUDE_CMD" --version 2>/dev/null || echo 'unknown version')"
    echo -e "  ${CYAN}Tip:${NC} Run 'claude models' for full list from Anthropic"
  else
    echo -e "  ${RED}CLI not found${NC} - install from https://claude.ai/download"
  fi
  echo ""
}

# Codex models
show_codex_models() {
  echo -e "${BLUE}Codex${NC} (via codex CLI)"
  echo -e "  ${YELLOW}Current:${NC} $(yq '.codex.model // "gpt-4o"' "$AGENT_CONFIG" 2>/dev/null)"
  echo ""
  echo -e "  ${GREEN}Available models:${NC}"
  echo "    • gpt-4o           (recommended for ChatGPT Pro)"
  echo "    • gpt-4o-mini      (faster, cheaper)"
  echo "    • gpt-4-turbo      (older, still good)"
  echo "    • o3               (reasoning model, slow)"
  echo "    • o4-mini          (mini reasoning)"
  echo "    • codex-5.2        (requires API access)"
  echo ""
  
  if command -v codex &>/dev/null; then
    echo -e "  ${GREEN}CLI found:${NC} $(codex --version 2>/dev/null || echo 'unknown version')"
    echo -e "  ${CYAN}Note:${NC} Some models require OpenAI API access (not ChatGPT Pro)"
  else
    echo -e "  ${RED}CLI not found${NC} - install with 'npm install -g @openai/codex'"
  fi
  echo ""
}

# Current config
show_current_config() {
  echo -e "${YELLOW}Current Configuration${NC} ($AGENT_CONFIG)"
  echo ""
  if [ -f "$AGENT_CONFIG" ]; then
    cat "$AGENT_CONFIG" | sed 's/^/  /'
  else
    echo -e "  ${RED}No agent.yaml found${NC}"
  fi
  echo ""
}

# Main
case "${1:-all}" in
  claude|claude-code)
    show_claude_models
    ;;
  codex|openai)
    show_codex_models
    ;;
  config)
    show_current_config
    ;;
  all|*)
    show_claude_models
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo ""
    show_codex_models
    echo -e "${CYAN}───────────────────────────────────────────────────────────${NC}"
    echo ""
    show_current_config
    ;;
esac

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "To change model: edit ${BLUE}agent.yaml${NC} and update the model field"
echo ""
