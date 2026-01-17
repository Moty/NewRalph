# NewRalph Context Management Enhancement Proposal

## Executive Summary

This document proposes enhancements to NewRalph that address the core limitation of autonomous coding loops: **context loss between iterations**. By incorporating concepts from **The Pin** (discovery-based context) and **Beads** (structured task memory), Ralph can achieve:

1. **Reduced hallucination** - Agents find existing code instead of inventing
2. **Better task continuity** - Dependencies and state survive context resets
3. **Smarter memory decay** - Compress old context while preserving essentials
4. **Multi-session coherence** - Work state persists across days/weeks

---

## Current State Analysis

### How NewRalph Currently Manages Context

```
┌─────────────────────────────────────────────────────────────────┐
│                    Current Context Sources                       │
├─────────────────────────────────────────────────────────────────┤
│  prd.json         │ User stories with passes status             │
│  progress.txt     │ Append-only learnings log                   │
│  AGENTS.md        │ Manual pattern documentation                │
│  git history      │ Commits from previous iterations            │
│  system_instructions.md │ Static agent instructions             │
└─────────────────────────────────────────────────────────────────┘
```

### Current Limitations

| Problem | Impact | Frequency |
|---------|--------|-----------|
| **Agent invents code** | Duplicates existing functionality | High |
| **Search misses** | "login" vs "auth" terminology mismatch | Medium |
| **Context compaction** | Loses architectural decisions | Medium |
| **No dependency tracking** | Stories execute in wrong order | Low (if PRD is good) |
| **Flat task list** | Can't model complex hierarchies | Medium |

---

## Proposed Enhancements

### Enhancement 1: The Pin System (Spec Discovery)

**Concept**: Create a searchable index of specs/code with semantic keywords that improve agent search hit rate.

#### Implementation

**New file: `specs/INDEX.md` (The Pin)**

```markdown
# Specs Index (The Pin)

This file helps agents discover existing functionality. Search for keywords to find relevant specs.

## Authentication System
Keywords: auth, login, logout, session, JWT, token, credentials, signin, signup, 
  password, verification, 2FA, MFA, middleware, bearer, oauth, cookies
Files: src/auth/, src/middleware/auth.ts
Spec: specs/authentication.md

## User Management  
Keywords: user, profile, account, settings, preferences, avatar, email, 
  registration, onboarding, permissions, roles, RBAC
Files: src/users/, src/models/user.ts
Spec: specs/user-management.md

## API Layer
Keywords: api, endpoint, route, REST, handler, controller, request, response,
  validation, serialization, pagination, filtering, sorting
Files: src/api/, src/routes/
Spec: specs/api-design.md

## Database Schema
Keywords: database, schema, model, migration, prisma, drizzle, postgres, sql,
  table, column, relation, foreign key, index
Files: prisma/schema.prisma, src/db/
Spec: specs/database.md
```

#### Integration with Ralph

**Update `system_instructions.md`:**

```markdown
## DISCOVERY PROTOCOL (Before implementing)

1. **Read the Pin first**: Check `specs/INDEX.md` for existing functionality
2. **Search with keywords**: Use multiple terms (e.g., "auth", "login", "session")
3. **Read relevant specs**: Before writing new code, understand what exists
4. **Only invent if truly new**: If Pin has no matches, proceed with implementation

This prevents duplicating existing code. The more you search, the less you invent.
```

**New script: `scripts/generate-pin.sh`**

```bash
#!/bin/bash
# Generate or update specs/INDEX.md from codebase analysis

echo "# Specs Index (The Pin)" > specs/INDEX.md
echo "" >> specs/INDEX.md
echo "Auto-generated: $(date)" >> specs/INDEX.md
echo "" >> specs/INDEX.md

# Use agent to analyze codebase and generate keywords
$AGENT "Analyze the codebase structure and create a Pin index file.
For each major module/feature:
1. List 10-20 keywords (synonyms, related terms, library names)
2. List the relevant file paths
3. Reference any existing spec files

Output in the format shown in specs/INDEX.md"
```

---

### Enhancement 2: Beads Integration (Structured Task Memory)

**Concept**: Replace/augment `prd.json` with a dependency-aware task graph that agents can query efficiently.

#### Option A: Native Beads Integration

```bash
# Install beads
curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash

# Initialize in project
bd init

# Add to AGENTS.md
echo "Use 'bd' for task tracking. Run 'bd ready' to find work." >> AGENTS.md
```

**Update `ralph.sh` to use beads:**

```bash
# In run_agent(), change the prompt to use beads
PROMPT="
1. Run 'bd ready --json' to find the next task
2. Pick the highest priority ready task
3. Implement it following existing patterns
4. Run 'bd update <id> --status done' when complete
5. If you discover new work, run 'bd create \"description\" --type discovered'
6. Output RALPH_COMPLETE when 'bd ready' returns empty
"
```

#### Option B: Native Ralph Context System (Beads-Inspired)

If you want to avoid external dependencies, implement beads concepts natively:

**New file: `lib/context.sh`**

```bash
#!/bin/bash
# Ralph Context Management System
# Inspired by Beads - provides structured memory for agents

CONTEXT_DIR=".ralph"
TASKS_FILE="$CONTEXT_DIR/tasks.jsonl"
CONTEXT_FILE="$CONTEXT_DIR/context.json"
PIN_FILE="specs/INDEX.md"

# Initialize context system
init_context() {
  mkdir -p "$CONTEXT_DIR"
  mkdir -p specs
  
  # Create tasks file if not exists
  [ ! -f "$TASKS_FILE" ] && echo '[]' > "$TASKS_FILE"
  
  # Create context file
  cat > "$CONTEXT_FILE" << EOF
{
  "project": "$(basename $(pwd))",
  "initialized": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "lastIteration": 0,
  "totalIterations": 0,
  "compactionLevel": 0
}
EOF
}

# Convert prd.json to tasks.jsonl format
import_prd() {
  local prd_file="${1:-prd.json}"
  
  jq -c '.userStories[] | {
    id: .id,
    title: .title,
    description: .description,
    acceptanceCriteria: .acceptanceCriteria,
    priority: .priority,
    status: (if .passes then "done" else "ready" end),
    blockedBy: [],
    discoveredFrom: null,
    created: now | todate,
    updated: now | todate
  }' "$prd_file" >> "$TASKS_FILE"
}

# Get ready tasks (not blocked, not done)
get_ready_tasks() {
  jq -s '[.[] | select(.status == "ready")] | sort_by(.priority)' "$TASKS_FILE"
}

# Update task status
update_task() {
  local task_id="$1"
  local new_status="$2"
  
  local temp_file=$(mktemp)
  jq -c "if .id == \"$task_id\" then .status = \"$new_status\" | .updated = (now | todate) else . end" "$TASKS_FILE" > "$temp_file"
  mv "$temp_file" "$TASKS_FILE"
}

# Create discovered task
create_discovered_task() {
  local title="$1"
  local discovered_from="$2"
  local priority="${3:-5}"
  
  local new_id="DISC-$(date +%s | tail -c 5)"
  
  echo "{
    \"id\": \"$new_id\",
    \"title\": \"$title\",
    \"status\": \"ready\",
    \"priority\": $priority,
    \"discoveredFrom\": \"$discovered_from\",
    \"created\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"
  }" | jq -c >> "$TASKS_FILE"
  
  echo "$new_id"
}

# Compact old completed tasks (memory decay)
compact_tasks() {
  local keep_recent="${1:-10}"
  
  # Keep last N completed tasks, summarize the rest
  local completed=$(jq -s '[.[] | select(.status == "done")] | sort_by(.updated) | reverse' "$TASKS_FILE")
  local recent=$(echo "$completed" | jq ".[:$keep_recent]")
  local old=$(echo "$completed" | jq ".[$keep_recent:]")
  
  if [ "$(echo "$old" | jq 'length')" -gt 0 ]; then
    # Create summary of old tasks
    local summary=$(echo "$old" | jq -r '[.[] | .title] | join(", ")')
    echo "Compacted $(echo "$old" | jq 'length') old tasks: $summary" >> "$CONTEXT_DIR/compaction.log"
    
    # Remove old tasks from main file
    local not_done=$(jq -s '[.[] | select(.status != "done")]' "$TASKS_FILE")
    echo "$not_done" | jq -c '.[]' > "$TASKS_FILE"
    echo "$recent" | jq -c '.[]' >> "$TASKS_FILE"
  fi
}

# Generate context summary for agent
generate_context_summary() {
  cat << EOF
## Project Context

### Ready Tasks
$(get_ready_tasks | jq -r '.[] | "- [\(.id)] \(.title) (P\(.priority))"')

### Recently Completed
$(jq -s '[.[] | select(.status == "done")] | sort_by(.updated) | reverse | .[:5] | .[] | "- [\(.id)] \(.title)"' "$TASKS_FILE" | head -10)

### Discovered Work
$(jq -s '[.[] | select(.discoveredFrom != null) | select(.status == "ready")] | .[] | "- [\(.id)] \(.title) (from \(.discoveredFrom))"' "$TASKS_FILE")

### Patterns (from progress.txt)
$(grep -A 100 "## Codebase Patterns" progress.txt 2>/dev/null | head -20)
EOF
}
```

---

### Enhancement 3: Smart Context Injection

**Concept**: Dynamically build the context window based on the current task.

**New file: `lib/context-builder.sh`**

```bash
#!/bin/bash
# Build optimal context for current iteration

build_context() {
  local current_task="$1"
  local context=""
  
  # 1. Always include: Pin index (discovery)
  if [ -f "specs/INDEX.md" ]; then
    context+="## Specs Index\n"
    context+="$(cat specs/INDEX.md)\n\n"
  fi
  
  # 2. Include relevant specs based on task keywords
  local task_keywords=$(echo "$current_task" | tr ' ' '\n' | grep -E '^[a-zA-Z]{3,}$')
  for keyword in $task_keywords; do
    local matching_spec=$(grep -il "$keyword" specs/*.md 2>/dev/null | head -1)
    if [ -n "$matching_spec" ]; then
      context+="## Relevant Spec: $matching_spec\n"
      context+="$(head -100 "$matching_spec")\n\n"
    fi
  done
  
  # 3. Include recent progress (last 3 entries)
  context+="## Recent Progress\n"
  context+="$(tail -50 progress.txt)\n\n"
  
  # 4. Include codebase patterns
  context+="## Codebase Patterns\n"
  context+="$(grep -A 50 "## Codebase Patterns" progress.txt 2>/dev/null | head -30)\n\n"
  
  # 5. Include task dependencies
  context+="## Task Context\n"
  context+="$(generate_context_summary)\n\n"
  
  echo -e "$context"
}

# Inject context into agent prompt
inject_context() {
  local base_prompt="$1"
  local task="$2"
  local context=$(build_context "$task")
  
  echo "
$context

---

$base_prompt
"
}
```

---

### Enhancement 4: Hierarchical Task Support

**Concept**: Support epics with child tasks for complex features.

**Update `prd.json` schema:**

```json
{
  "project": "MyApp",
  "branchName": "ralph/auth-system",
  "epics": [
    {
      "id": "EPIC-001",
      "title": "User Authentication System",
      "description": "Complete auth flow with JWT",
      "children": ["US-001", "US-002", "US-003", "US-004"]
    }
  ],
  "userStories": [
    {
      "id": "US-001",
      "title": "Database schema for users",
      "parentEpic": "EPIC-001",
      "blockedBy": [],
      "priority": 1,
      "passes": false
    },
    {
      "id": "US-002", 
      "title": "JWT token generation",
      "parentEpic": "EPIC-001",
      "blockedBy": ["US-001"],
      "priority": 2,
      "passes": false
    }
  ]
}
```

**Update task selection in `ralph.sh`:**

```bash
get_next_task() {
  # Get highest priority task that:
  # 1. Has passes: false
  # 2. Has no blockedBy tasks that are incomplete
  
  jq -r '
    .userStories as $stories |
    [.userStories[] | select(.passes == false)] |
    [.[] | select(
      (.blockedBy // []) | all(. as $bid | $stories | any(.id == $bid and .passes == true))
    )] |
    sort_by(.priority) |
    .[0]
  ' "$PRD_FILE"
}
```

---

### Enhancement 5: Memory Compaction

**Concept**: Automatically summarize old context to free up token space.

**New file: `lib/compaction.sh`**

```bash
#!/bin/bash
# Memory compaction - summarize old context while preserving essentials

PROGRESS_FILE="progress.txt"
MAX_PROGRESS_LINES=500
COMPACTION_THRESHOLD=400

compact_progress() {
  local line_count=$(wc -l < "$PROGRESS_FILE")
  
  if [ "$line_count" -lt "$COMPACTION_THRESHOLD" ]; then
    echo "Progress file within limits ($line_count lines)"
    return 0
  fi
  
  echo "Compacting progress.txt ($line_count lines)..."
  
  # Preserve patterns section at top
  local patterns=$(grep -A 100 "## Codebase Patterns" "$PROGRESS_FILE" | head -50)
  
  # Get last N entries (most recent work)
  local recent=$(tail -200 "$PROGRESS_FILE")
  
  # Summarize middle section using agent
  local middle_start=50
  local middle_end=$((line_count - 200))
  local middle=$(sed -n "${middle_start},${middle_end}p" "$PROGRESS_FILE")
  
  # Ask agent to summarize (or use simple extraction)
  local summary="## Compacted History ($(date +%Y-%m-%d))
The following work was completed and compacted:
$(echo "$middle" | grep -E "^## \[|^- " | head -30)
---
"
  
  # Rebuild progress file
  cat > "$PROGRESS_FILE" << EOF
# Ralph Progress Log
Compacted: $(date)

$patterns

$summary

$recent
EOF
  
  echo "Compacted to $(wc -l < "$PROGRESS_FILE") lines"
}

# Run compaction before each iteration
pre_iteration_compact() {
  compact_progress
  
  # Also compact tasks if using native context system
  if [ -f ".ralph/tasks.jsonl" ]; then
    source lib/context.sh
    compact_tasks 10
  fi
}
```

---

## Integration Plan

### Phase 1: The Pin (Week 1)
1. Create `specs/INDEX.md` manually or via script
2. Update system instructions to read Pin first
3. Add `generate-pin.sh` to automate updates

### Phase 2: Native Context System (Week 2)
1. Implement `lib/context.sh`
2. Add `blockedBy` support to `prd.json`
3. Update task selection logic

### Phase 3: Smart Context Injection (Week 3)
1. Implement `lib/context-builder.sh`
2. Modify `ralph.sh` to inject dynamic context
3. Test with various task types

### Phase 4: Compaction (Week 4)
1. Implement `lib/compaction.sh`
2. Add pre-iteration compaction hook
3. Tune thresholds based on model context windows

### Optional: Full Beads Integration
If native system isn't enough:
1. Install beads: `curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash`
2. Add to AGENTS.md
3. Update ralph.sh to use `bd` commands

---

## File Structure After Enhancement

```
NewRalph/
├── lib/
│   ├── common.sh           # Existing utilities
│   ├── context.sh          # NEW: Task memory system
│   ├── context-builder.sh  # NEW: Dynamic context injection
│   ├── compaction.sh       # NEW: Memory decay
│   └── model-refresh.sh    # Existing model detection
├── specs/
│   ├── INDEX.md            # NEW: The Pin (discovery index)
│   ├── authentication.md   # Example spec
│   └── api-design.md       # Example spec
├── scripts/
│   └── generate-pin.sh     # NEW: Auto-generate Pin
├── .ralph/                  # NEW: Context state directory
│   ├── tasks.jsonl         # Task graph (beads-style)
│   ├── context.json        # Project context metadata
│   └── compaction.log      # Compaction history
├── ralph.sh                # Updated with context hooks
├── system_instructions/
│   └── system_instructions.md  # Updated with discovery protocol
└── ...
```

---

## Updated System Instructions

```markdown
# SYSTEM INSTRUCTIONS — RALPH EXECUTION MODE (Enhanced)

## DISCOVERY PROTOCOL (Before implementing)

1. **Read the Pin**: Check `specs/INDEX.md` for existing functionality
2. **Search broadly**: Use multiple keywords (synonyms, library names)
3. **Read matching specs**: Understand existing patterns before coding
4. **Only invent if truly new**: If no Pin matches, proceed carefully

## TASK SELECTION

1. Run context check: Read `.ralph/tasks.jsonl` or `prd.json`
2. Find ready tasks: `passes: false` AND all `blockedBy` tasks complete
3. Pick highest priority ready task
4. If no ready tasks, output RALPH_COMPLETE

## DURING IMPLEMENTATION

- Follow patterns in `## Codebase Patterns` section of progress.txt
- If you discover new work needed, create a discovered task
- Keep changes minimal and focused

## AFTER IMPLEMENTATION

1. Update task status to done
2. Add learnings to progress.txt
3. If pattern is reusable, add to Codebase Patterns section
4. If new module created, update specs/INDEX.md with keywords

## MEMORY MANAGEMENT

- Progress.txt is auto-compacted; recent entries are preserved
- Old work summaries are in Compacted History section
- Focus on current task, not historical details
```

---

## Metrics to Track

| Metric | Current | Target | How to Measure |
|--------|---------|--------|----------------|
| Code duplication rate | Unknown | <5% | Count similar functions created |
| Search hit rate | Unknown | >80% | Log Pin matches vs misses |
| Tasks per iteration | ~1 | 1-2 | Count completed per loop |
| Context overflow | Occasional | Rare | Track compaction triggers |
| Dependency violations | Some | 0 | Validate execution order |

---

## Quick Start Implementation

**Minimum viable enhancement (do this first):**

```bash
# 1. Create specs directory and Pin
mkdir -p specs
cat > specs/INDEX.md << 'EOF'
# Specs Index (The Pin)

Read this file first to discover existing functionality.
Search for keywords to find relevant code.

## [Add your modules here with keywords]
EOF

# 2. Update system instructions
cat >> system_instructions/system_instructions.md << 'EOF'

## DISCOVERY PROTOCOL
Before implementing, read specs/INDEX.md and search for related keywords.
Only create new code if no existing functionality matches.
EOF

# 3. Add blockedBy support to PRD validation
# Update lib/common.sh validate_prd_json to check blockedBy
```

---

## Conclusion

These enhancements transform Ralph from a simple iteration loop into a context-aware autonomous system. The key innovations are:

1. **The Pin** - Discovery-based context prevents hallucination
2. **Task Dependencies** - Proper execution order
3. **Memory Compaction** - Sustainable long-horizon work
4. **Context Injection** - Right information at the right time

Start with The Pin (simplest, highest impact), then add native task memory, then compaction as needed.

Would you like me to implement any of these enhancements directly?
