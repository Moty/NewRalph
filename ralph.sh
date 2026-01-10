#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (agent-agnostic)
# Usage: ./ralph.sh [max_iterations]

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
AGENT_CONFIG="$SCRIPT_DIR/agent.yaml"

# ---- helpers -------------------------------------------------

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required binary: $1"
    exit 1
  }
}

require_bin jq
require_bin yq

get_agent() {
  yq '.agent.primary' "$AGENT_CONFIG"
}

get_fallback_agent() {
  yq '.agent.fallback // ""' "$AGENT_CONFIG"
}

get_claude_model() {
  yq '.claude-code.model // "claude-sonnet-4-20250514"' "$AGENT_CONFIG"
}

get_codex_model() {
  yq '.codex.model // "codex"' "$AGENT_CONFIG"
}

get_codex_approval_mode() {
  yq '.codex.approval-mode // "full-auto"' "$AGENT_CONFIG"
}

run_agent() {
  local AGENT="$1"

  case "$AGENT" in
    claude-code)
      local MODEL=$(get_claude_model)
      echo "→ Running Claude Code (model: $MODEL)"
      # Claude Code CLI - adjust flags based on your installed version
      claude --print \
        --dangerously-skip-permissions \
        --model "$MODEL" \
        --system-prompt "$SCRIPT_DIR/system_instructions/system_instructions.md" \
        "Read prd.json and implement the next incomplete story. Follow the system instructions exactly."
      ;;
    codex)
      local MODEL=$(get_codex_model)
      local APPROVAL=$(get_codex_approval_mode)
      echo "→ Running Codex (model: $MODEL)"
      # OpenAI Codex CLI - adjust based on your installed version
      codex --quiet \
        --approval-mode "$APPROVAL" \
        --model "$MODEL" \
        "Read prd.json and implement the next incomplete story following $SCRIPT_DIR/system_instructions/system_instructions_codex.md"
      ;;
    *)
      echo "Unknown agent: $AGENT"
      exit 1
      ;;
  esac
}

# ---- archive previous run if branch changed ------------------

if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    DATE=$(date +%Y-%m-%d)
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

    echo "Archiving previous run: $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "Archived to: $ARCHIVE_FOLDER"

    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

# ---- track current branch -----------------------------------

if [ -f "$PRD_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ]; then
    echo "$CURRENT_BRANCH" > "$LAST_BRANCH_FILE"
  fi
fi

# ---- initialize progress file --------------------------------

if [ ! -f "$PROGRESS_FILE" ]; then
  echo "# Ralph Progress Log" > "$PROGRESS_FILE"
  echo "Started: $(date)" >> "$PROGRESS_FILE"
  echo "---" >> "$PROGRESS_FILE"
fi

# ---- main loop -----------------------------------------------

PRIMARY_AGENT=$(get_agent)
FALLBACK_AGENT=$(get_fallback_agent)

echo "Starting Ralph"
echo "Primary agent: $PRIMARY_AGENT"
[ -n "$FALLBACK_AGENT" ] && echo "Fallback agent: $FALLBACK_AGENT"
echo "Max iterations: $MAX_ITERATIONS"

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo ""
  echo "═══════════════════════════════════════════════════════"
  echo "  Ralph Iteration $i of $MAX_ITERATIONS"
  echo "═══════════════════════════════════════════════════════"

  set +e
  OUTPUT=$(run_agent "$PRIMARY_AGENT" 2>&1 | tee /dev/stderr)
  STATUS=$?
  set -e

  if [ $STATUS -ne 0 ] && [ -n "$FALLBACK_AGENT" ]; then
    echo "Primary agent failed — falling back to $FALLBACK_AGENT"
    set +e
    OUTPUT=$(run_agent "$FALLBACK_AGENT" 2>&1 | tee /dev/stderr)
    STATUS=$?
    set -e
  fi

  if echo "$OUTPUT" | grep -q "RALPH_COMPLETE"; then
    echo ""
    echo "🎉 Ralph completed all tasks!"
    echo "Completed at iteration $i of $MAX_ITERATIONS"
    exit 0
  fi

  echo "Iteration $i complete. Continuing..."
  sleep 2
done

echo ""
echo "Ralph reached max iterations ($MAX_ITERATIONS) without completing all tasks."
echo "Check $PROGRESS_FILE for status."
exit 1
