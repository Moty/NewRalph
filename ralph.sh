#!/bin/bash
# Ralph Wiggum - Long-running AI agent loop (agent-agnostic)
# Usage: ./ralph.sh [max_iterations] [--no-sleep-prevent]

set -e

# ---- Configuration ------------------------------------------------

MAX_ITERATIONS=${1:-10}
PREVENT_SLEEP=true
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check for --no-sleep-prevent flag
for arg in "$@"; do
  if [ "$arg" == "--no-sleep-prevent" ]; then
    PREVENT_SLEEP=false
  fi
done

PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$SCRIPT_DIR/.last-branch"
AGENT_CONFIG="$SCRIPT_DIR/agent.yaml"
START_TIME=$(date +%s)

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ---- Helper Functions ---------------------------------------------

require_bin() {
  command -v "$1" >/dev/null 2>&1 || {
    echo -e "${RED}Missing required binary: $1${NC}"
    exit 1
  }
}

require_bin jq
require_bin yq

format_duration() {
  local seconds=$1
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))
  local secs=$((seconds % 60))
  if [ $hours -gt 0 ]; then
    printf "%dh %dm %ds" $hours $minutes $secs
  elif [ $minutes -gt 0 ]; then
    printf "%dm %ds" $minutes $secs
  else
    printf "%ds" $secs
  fi
}

get_elapsed_time() {
  local now=$(date +%s)
  local elapsed=$((now - START_TIME))
  format_duration $elapsed
}

get_current_story() {
  if [ -f "$PRD_FILE" ]; then
    local story=$(jq -r '.userStories[] | select(.passes == false) | "\(.id): \(.title)"' "$PRD_FILE" 2>/dev/null | head -1)
    if [ -n "$story" ]; then
      echo "$story"
    else
      echo "All stories complete"
    fi
  else
    echo "No PRD found"
  fi
}

get_story_progress() {
  if [ -f "$PRD_FILE" ]; then
    local total=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null)
    local complete=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null)
    echo "$complete/$total"
  else
    echo "?/?"
  fi
}

check_rate_limit() {
  local output="$1"
  if echo "$output" | grep -qi "hit your limit\|rate limit\|quota exceeded\|too many requests\|resets [0-9]"; then
    return 0
  fi
  return 1
}

check_error() {
  local output="$1"
  if echo "$output" | grep -qi '"is_error":true\|error_during_execution'; then
    return 0
  fi
  return 1
}

print_status() {
  local iteration=$1
  local max=$2
  local story=$(get_current_story)
  local progress=$(get_story_progress)
  local elapsed=$(get_elapsed_time)
  
  if [ ${#story} -gt 45 ]; then
    story="${story:0:42}..."
  fi
  
  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC}  ${BLUE}Ralph Iteration${NC} ${YELLOW}$iteration${NC} of ${YELLOW}$max${NC}"
  echo -e "${CYAN}├─────────────────────────────────────────────────────────┤${NC}"
  echo -e "${CYAN}│${NC}  📊 Stories: ${GREEN}$progress${NC} complete"
  echo -e "${CYAN}│${NC}  🎯 Current: ${YELLOW}$story${NC}"
  echo -e "${CYAN}│${NC}  ⏱️  Elapsed: ${BLUE}$elapsed${NC}"
  echo -e "${CYAN}└─────────────────────────────────────────────────────────┘${NC}"
  echo ""
}

print_iteration_summary() {
  local iteration=$1
  local duration=$2
  local status=$3
  local elapsed=$(get_elapsed_time)
  local progress=$(get_story_progress)
  local duration_str=$(format_duration $duration)
  
  if [ "$status" == "success" ]; then
    echo -e "${GREEN}✓ Iteration $iteration complete${NC} ($duration_str) | Stories: $progress | Total: $elapsed"
  elif [ "$status" == "rate_limited" ]; then
    echo -e "${RED}⚠ Rate limited${NC} - stopping Ralph"
  elif [ "$status" == "error" ]; then
    echo -e "${YELLOW}⚠ Iteration $iteration had errors${NC} ($duration_str) | Stories: $progress"
  else
    echo -e "${BLUE}→ Iteration $iteration finished${NC} ($duration_str)"
  fi
}

cleanup() {
  if [ -n "$CAFFEINATE_PID" ]; then
    kill $CAFFEINATE_PID 2>/dev/null || true
  fi
  echo ""
  echo -e "${YELLOW}Ralph stopped.${NC}"
  local elapsed=$(get_elapsed_time)
  local progress=$(get_story_progress)
  echo -e "Total time: ${BLUE}$elapsed${NC} | Stories completed: ${GREEN}$progress${NC}"
}

trap cleanup EXIT

# ---- Sleep Prevention ---------------------------------------------

start_sleep_prevention() {
  if [ "$PREVENT_SLEEP" = true ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
      caffeinate -i -w $$ &
      CAFFEINATE_PID=$!
      echo -e "${GREEN}☕ Sleep prevention enabled (caffeinate)${NC}"
    elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
      echo -e "${YELLOW}⚠ Windows detected - disable sleep manually or run:${NC}"
      echo "  powercfg -change -standby-timeout-ac 0"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
      if command -v systemd-inhibit &>/dev/null; then
        systemd-inhibit --what=idle --who=ralph --why="Running Ralph iterations" --mode=block sleep infinity &
        CAFFEINATE_PID=$!
        echo -e "${GREEN}☕ Sleep prevention enabled (systemd-inhibit)${NC}"
      else
        echo -e "${YELLOW}⚠ No sleep prevention tool found.${NC}"
      fi
    fi
  fi
}

# ---- Agent Configuration ------------------------------------------

get_agent() { yq '.agent.primary' "$AGENT_CONFIG"; }
get_fallback_agent() { yq '.agent.fallback // ""' "$AGENT_CONFIG"; }
get_claude_model() { yq '.claude-code.model // "claude-sonnet-4-20250514"' "$AGENT_CONFIG"; }
get_codex_model() { yq '.codex.model // "gpt-4o"' "$AGENT_CONFIG"; }
get_codex_approval_mode() { yq '.codex.approval-mode // "full-auto"' "$AGENT_CONFIG"; }

CLAUDE_CMD=""
if command -v claude &>/dev/null; then
  CLAUDE_CMD="claude"
elif [ -x "$HOME/.local/bin/claude" ]; then
  CLAUDE_CMD="$HOME/.local/bin/claude"
fi

run_agent() {
  local AGENT="$1"
  case "$AGENT" in
    claude-code)
      local MODEL=$(get_claude_model)
      echo -e "→ Running ${CYAN}Claude Code${NC} (model: $MODEL)"
      [ -z "$CLAUDE_CMD" ] && { echo -e "${RED}Error: Claude CLI not found${NC}"; return 1; }
      "$CLAUDE_CMD" --print --dangerously-skip-permissions --model "$MODEL" \
        --system-prompt "$SCRIPT_DIR/system_instructions/system_instructions.md" \
        "Read prd.json and implement the next incomplete story. Follow the system instructions exactly."
      ;;
    codex)
      local MODEL=$(get_codex_model)
      local APPROVAL=$(get_codex_approval_mode)
      echo -e "→ Running ${CYAN}Codex${NC} (model: $MODEL, approval: $APPROVAL)"
      local APPROVAL_FLAG=""
      [ "$APPROVAL" = "full-auto" ] && APPROVAL_FLAG="--full-auto"
      [ "$APPROVAL" = "danger" ] && APPROVAL_FLAG="--dangerously-bypass-approvals-and-sandbox"
      codex exec $APPROVAL_FLAG -m "$MODEL" --skip-git-repo-check \
        "Read prd.json and implement the next incomplete story. Follow system_instructions/system_instructions_codex.md. When all stories complete, output: RALPH_COMPLETE"
      ;;
    *) echo -e "${RED}Unknown agent: $AGENT${NC}"; exit 1 ;;
  esac
}

# ---- Archive previous run -----------------------------------------

if [ -f "$PRD_FILE" ] && [ -f "$LAST_BRANCH_FILE" ]; then
  CURRENT_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
  LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ] && [ -n "$LAST_BRANCH" ] && [ "$CURRENT_BRANCH" != "$LAST_BRANCH" ]; then
    FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||' | sed 's|/|-|g')
    ARCHIVE_FOLDER="$ARCHIVE_DIR/$(date +%Y-%m-%d)-$FOLDER_NAME"
    echo -e "${YELLOW}Archiving previous run:${NC} $LAST_BRANCH"
    mkdir -p "$ARCHIVE_FOLDER"
    [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
    [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
  fi
fi

[ -f "$PRD_FILE" ] && echo "$(jq -r '.branchName // empty' "$PRD_FILE")" > "$LAST_BRANCH_FILE"

[ ! -f "$PROGRESS_FILE" ] && { echo "# Ralph Progress Log" > "$PROGRESS_FILE"; echo "Started: $(date)" >> "$PROGRESS_FILE"; echo "---" >> "$PROGRESS_FILE"; }

# ---- Main loop ----------------------------------------------------

PRIMARY_AGENT=$(get_agent)
FALLBACK_AGENT=$(get_fallback_agent)

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🐻 Starting Ralph${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Primary agent: ${CYAN}$PRIMARY_AGENT${NC}"
[ -n "$FALLBACK_AGENT" ] && echo -e "Fallback agent: ${CYAN}$FALLBACK_AGENT${NC}"
echo -e "Max iterations: ${YELLOW}$MAX_ITERATIONS${NC}"
echo -e "Started at: ${BLUE}$(date '+%Y-%m-%d %H:%M:%S')${NC}"

start_sleep_prevention

for i in $(seq 1 "$MAX_ITERATIONS"); do
  ITERATION_START=$(date +%s)
  print_status $i $MAX_ITERATIONS

  set +e
  OUTPUT=$(run_agent "$PRIMARY_AGENT" 2>&1 | tee /dev/stderr)
  STATUS=$?
  set -e

  if check_rate_limit "$OUTPUT"; then
    print_iteration_summary $i 0 "rate_limited"
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}  ⚠ Rate limit hit - Ralph stopping${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    echo -e "Resume later with: ${YELLOW}./ralph.sh $((MAX_ITERATIONS - i + 1))${NC}"
    exit 1
  fi

  if [ $STATUS -ne 0 ] && [ -n "$FALLBACK_AGENT" ]; then
    echo -e "${YELLOW}Primary agent failed — trying $FALLBACK_AGENT${NC}"
    set +e
    OUTPUT=$(run_agent "$FALLBACK_AGENT" 2>&1 | tee /dev/stderr)
    STATUS=$?
    set -e
    check_rate_limit "$OUTPUT" && { echo -e "${RED}⚠ Rate limit on fallback${NC}"; exit 1; }
  fi

  ITERATION_END=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END - ITERATION_START))

  if echo "$OUTPUT" | grep -q "RALPH_COMPLETE"; then
    print_iteration_summary $i $ITERATION_DURATION "success"
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  🎉 Ralph completed all tasks!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "Completed at iteration ${YELLOW}$i${NC} | Total time: ${BLUE}$(get_elapsed_time)${NC}"
    exit 0
  fi

  check_error "$OUTPUT" && print_iteration_summary $i $ITERATION_DURATION "error" || print_iteration_summary $i $ITERATION_DURATION "success"
  sleep 2
done

echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}  Ralph reached max iterations ($MAX_ITERATIONS)${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "Stories: ${GREEN}$(get_story_progress)${NC} | Check ${BLUE}$PROGRESS_FILE${NC}"
exit 1
