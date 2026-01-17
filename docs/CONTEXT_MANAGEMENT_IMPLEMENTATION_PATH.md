# Context Management Enhancement - Implementation Path

This document provides a structured implementation path for the context management enhancements proposed in CONTEXT_MANAGEMENT_ENHANCEMENT.md. It is designed to be fed into `create_prd` for PRD generation.

---

## Project Overview

**Project Name**: Ralph Context Management System

**Goal**: Enhance NewRalph with intelligent context management to reduce hallucinations, improve task continuity, and enable sustainable long-horizon autonomous coding.

**Core Problems Solved**:
1. Agents inventing code instead of finding existing implementations
2. Context loss between iterations causing repeated work
3. No dependency tracking leading to wrong execution order
4. Unbounded progress files causing context overflow

---

## Feature Modules

### Module 1: The Pin System (Discovery Index)

**Priority**: P0 (Highest - implement first)
**Complexity**: Low
**Impact**: High

**Description**: Create a searchable keyword index that helps agents discover existing functionality before implementing new code.

#### User Stories

**US-1.1: Create Pin Directory Structure**
- As a developer, I want a `specs/` directory to store discovery-related files
- Acceptance Criteria:
  - `specs/` directory exists in project root
  - Directory is tracked in git
  - README explains the purpose of the directory

**US-1.2: Create Pin Index File Template**
- As an agent, I want a `specs/INDEX.md` file with keyword-to-code mappings so I can find existing functionality
- Acceptance Criteria:
  - `specs/INDEX.md` exists with standard template format
  - Format includes: module name, keywords array, file paths, spec references
  - Example entries demonstrate proper usage

**US-1.3: Create Pin Generation Script**
- As a developer, I want a script to auto-generate the Pin from codebase analysis
- Acceptance Criteria:
  - `scripts/generate-pin.sh` exists and is executable
  - Script analyzes codebase structure and extracts keywords
  - Script generates/updates `specs/INDEX.md` in standard format
  - Script can be run manually or integrated into CI

**US-1.4: Integrate Discovery Protocol into System Instructions**
- As an agent, I want clear instructions to read the Pin before implementing
- Acceptance Criteria:
  - `system_instructions/system_instructions.md` includes Discovery Protocol section
  - Protocol specifies: (1) Read Pin first, (2) Search multiple keywords, (3) Read matching specs, (4) Only invent if no matches
  - Protocol is prominently placed before implementation guidelines

---

### Module 2: Native Context System (Task Memory)

**Priority**: P1
**Complexity**: Medium
**Impact**: High
**Depends On**: None

**Description**: Implement a native context system inspired by Beads that provides structured task memory with dependency tracking.

#### User Stories

**US-2.1: Create Ralph Context Directory**
- As a system, I need a `.ralph/` directory to store context state
- Acceptance Criteria:
  - `.ralph/` directory created on initialization
  - Directory contains `tasks.jsonl`, `context.json`
  - Directory is excluded from git via `.gitignore`

**US-2.2: Implement Context Initialization**
- As a developer, I want to initialize the context system for a project
- Acceptance Criteria:
  - `lib/context.sh` contains `init_context()` function
  - Function creates required directories and files
  - Creates `context.json` with project metadata (name, init date, iteration count)

**US-2.3: Implement PRD to Tasks Import**
- As a system, I want to convert existing `prd.json` to the tasks format
- Acceptance Criteria:
  - `lib/context.sh` contains `import_prd()` function
  - Function reads `prd.json` and creates entries in `tasks.jsonl`
  - Preserves: id, title, description, acceptanceCriteria, priority
  - Converts `passes` boolean to status string (done/ready)

**US-2.4: Implement Ready Task Query**
- As an agent, I want to query tasks that are ready to work on
- Acceptance Criteria:
  - `lib/context.sh` contains `get_ready_tasks()` function
  - Returns tasks where status=ready AND all blockedBy tasks are done
  - Results sorted by priority
  - Returns JSON array format

**US-2.5: Implement Task Status Update**
- As an agent, I want to update task status when I complete work
- Acceptance Criteria:
  - `lib/context.sh` contains `update_task()` function
  - Function takes task_id and new_status parameters
  - Updates status and updated timestamp in tasks.jsonl
  - Handles task not found gracefully

**US-2.6: Implement Discovered Task Creation**
- As an agent, I want to create new tasks discovered during implementation
- Acceptance Criteria:
  - `lib/context.sh` contains `create_discovered_task()` function
  - Creates task with auto-generated ID (DISC-xxxxx format)
  - Records `discoveredFrom` reference to source task
  - Sets default priority (configurable)

**US-2.7: Implement Context Summary Generation**
- As an agent, I want a summary of current context for efficient understanding
- Acceptance Criteria:
  - `lib/context.sh` contains `generate_context_summary()` function
  - Summary includes: ready tasks, recent completions, discovered work, patterns
  - Output is markdown formatted
  - Respects token limits (configurable max lines)

---

### Module 3: Dependency-Aware Task Selection

**Priority**: P1
**Complexity**: Low
**Impact**: Medium
**Depends On**: Module 2

**Description**: Enhance prd.json schema and task selection to respect dependencies.

#### User Stories

**US-3.1: Extend PRD Schema with Dependencies**
- As a developer, I want to specify task dependencies in prd.json
- Acceptance Criteria:
  - `prd.json` schema supports `blockedBy` array field on user stories
  - `blockedBy` contains task IDs that must complete first
  - Schema supports optional `parentEpic` field for hierarchy

**US-3.2: Extend PRD Schema with Epics**
- As a developer, I want to group related tasks into epics
- Acceptance Criteria:
  - `prd.json` schema supports `epics` array at root level
  - Each epic has: id, title, description, children (task IDs)
  - User stories can reference parentEpic

**US-3.3: Implement Dependency-Aware Task Selection**
- As a system, I want task selection to respect blockedBy dependencies
- Acceptance Criteria:
  - `lib/common.sh` or `ralph.sh` contains `get_next_task()` function
  - Function filters tasks where ALL blockedBy tasks are complete
  - Among eligible tasks, selects highest priority
  - Returns null if no tasks ready

**US-3.4: Validate PRD Dependencies**
- As a developer, I want validation that dependencies are valid
- Acceptance Criteria:
  - `validate_prd_json()` checks blockedBy references exist
  - Detects circular dependencies
  - Warns on orphan epic references
  - Returns clear error messages

---

### Module 4: Smart Context Injection

**Priority**: P2
**Complexity**: Medium
**Impact**: High
**Depends On**: Module 1, Module 2

**Description**: Dynamically build context window based on current task to maximize relevance.

#### User Stories

**US-4.1: Implement Context Builder**
- As a system, I want to build optimal context for each iteration
- Acceptance Criteria:
  - `lib/context-builder.sh` contains `build_context()` function
  - Function takes current task as input
  - Includes: Pin index, relevant specs, recent progress, patterns, task context
  - Output is properly formatted markdown

**US-4.2: Implement Keyword-Based Spec Matching**
- As a system, I want to include specs relevant to the current task
- Acceptance Criteria:
  - Context builder extracts keywords from task title/description
  - Matches keywords against specs/INDEX.md
  - Includes matching spec files (first 100 lines)
  - Limits total spec content to prevent overflow

**US-4.3: Implement Context Injection**
- As a system, I want context injected into agent prompts
- Acceptance Criteria:
  - `lib/context-builder.sh` contains `inject_context()` function
  - Function prepends built context to base prompt
  - Maintains clear separator between context and instructions
  - Respects model token limits

**US-4.4: Integrate Context Injection into Ralph Loop**
- As a system, I want each iteration to receive appropriate context
- Acceptance Criteria:
  - `ralph.sh` calls `inject_context()` before running agent
  - Context is built fresh each iteration
  - Injection is optional (fallback to current behavior)

---

### Module 5: Memory Compaction

**Priority**: P2
**Complexity**: Medium
**Impact**: Medium
**Depends On**: Module 2

**Description**: Automatically summarize old context to prevent token overflow while preserving essential information.

#### User Stories

**US-5.1: Implement Progress File Compaction**
- As a system, I want progress.txt to stay within manageable size
- Acceptance Criteria:
  - `lib/compaction.sh` contains `compact_progress()` function
  - Function triggers when file exceeds threshold (default 400 lines)
  - Preserves: patterns section, recent N entries
  - Middle content is summarized
  - Original line count logged

**US-5.2: Implement Task Compaction**
- As a system, I want old completed tasks compressed
- Acceptance Criteria:
  - `lib/compaction.sh` or `lib/context.sh` contains `compact_tasks()` function
  - Keeps last N completed tasks (default 10)
  - Older completions archived to compaction.log
  - Function is idempotent

**US-5.3: Implement Pre-Iteration Compaction Hook**
- As a system, I want compaction to run before each iteration
- Acceptance Criteria:
  - `lib/compaction.sh` contains `pre_iteration_compact()` function
  - Calls both progress and task compaction
  - Runs silently unless changes made
  - Logs compaction events

**US-5.4: Integrate Compaction into Ralph Loop**
- As a system, I want compaction to run automatically
- Acceptance Criteria:
  - `ralph.sh` calls `pre_iteration_compact()` at start of each iteration
  - Compaction is configurable (can be disabled)
  - Errors in compaction don't halt iteration

**US-5.5: Implement Compaction Configuration**
- As a developer, I want to configure compaction thresholds
- Acceptance Criteria:
  - Configuration in `ralph.conf` or environment variables
  - Configurable: progress threshold, keep-recent count, task keep count
  - Sensible defaults documented

---

### Module 6: Updated System Instructions

**Priority**: P1
**Complexity**: Low
**Impact**: High
**Depends On**: Module 1, Module 2

**Description**: Update system instructions to leverage all context enhancements.

#### User Stories

**US-6.1: Add Discovery Protocol Section**
- As an agent, I need clear instructions for discovery-first approach
- Acceptance Criteria:
  - System instructions include Discovery Protocol section
  - Steps: Read Pin, search keywords, read specs, only invent if new
  - Examples of good discovery behavior

**US-6.2: Add Task Selection Protocol**
- As an agent, I need instructions for proper task selection
- Acceptance Criteria:
  - System instructions include Task Selection section
  - Steps: check context, find ready tasks, respect dependencies
  - Instructions for RALPH_COMPLETE output

**US-6.3: Add Implementation Guidelines**
- As an agent, I need guidelines for during-implementation behavior
- Acceptance Criteria:
  - Instructions to follow patterns from progress.txt
  - Guidelines for creating discovered tasks
  - Emphasis on minimal, focused changes

**US-6.4: Add Post-Implementation Protocol**
- As an agent, I need instructions for after completing work
- Acceptance Criteria:
  - Steps: update task status, add learnings, update patterns
  - Instructions to update Pin when creating new modules
  - Clear completion criteria

---

## Implementation Dependencies Graph

```
Module 1 (Pin System) ──────────────────────────────┐
     │                                               │
     ├─── US-1.1 → US-1.2 → US-1.3                  │
     │              │                                │
     │              └──────────────────────────────────────┐
     │                                               │     │
Module 2 (Context System)                            │     │
     │                                               │     │
     ├─── US-2.1 → US-2.2                           │     │
     │              │                                │     │
     │              ├─── US-2.3                      │     │
     │              │                                │     │
     │              ├─── US-2.4 ──┐                  │     │
     │              │             │                  │     │
     │              ├─── US-2.5   │                  │     │
     │              │             │                  │     │
     │              ├─── US-2.6   │                  │     │
     │              │             │                  │     │
     │              └─── US-2.7 ──┼──────────────────┼─────┤
     │                            │                  │     │
Module 3 (Dependencies)           │                  │     │
     │                            │                  │     │
     ├─── US-3.1 ─────────────────┤                  │     │
     │                            │                  │     │
     ├─── US-3.2                  │                  │     │
     │                            │                  │     │
     ├─── US-3.3 ─────────────────┤                  │     │
     │                            │                  │     │
     └─── US-3.4                  │                  │     │
                                  │                  │     │
Module 4 (Context Injection) ─────┼──────────────────┘     │
     │                            │                        │
     ├─── US-4.1 ─────────────────┤                        │
     │                            │                        │
     ├─── US-4.2 ────────────────────────────────────────────┘
     │                            │
     ├─── US-4.3 ─────────────────┤
     │                            │
     └─── US-4.4                  │
                                  │
Module 5 (Compaction) ────────────┘
     │
     ├─── US-5.1
     │
     ├─── US-5.2
     │
     ├─── US-5.3
     │
     ├─── US-5.4
     │
     └─── US-5.5

Module 6 (System Instructions)
     │
     ├─── US-6.1 (depends on Module 1)
     │
     ├─── US-6.2 (depends on Module 2, 3)
     │
     ├─── US-6.3
     │
     └─── US-6.4
```

---

## Suggested Implementation Order

### Phase 1: Foundation (Start Here)
1. **US-1.1** - Create specs directory
2. **US-1.2** - Create Pin index template
3. **US-1.4** - Add discovery protocol to instructions
4. **US-6.1** - Add discovery protocol section

**Deliverable**: Minimal viable discovery system

### Phase 2: Task Memory
5. **US-2.1** - Create .ralph directory
6. **US-2.2** - Implement init_context()
7. **US-2.3** - Implement import_prd()
8. **US-2.4** - Implement get_ready_tasks()
9. **US-2.5** - Implement update_task()
10. **US-2.6** - Implement create_discovered_task()
11. **US-2.7** - Implement generate_context_summary()

**Deliverable**: Native context system working

### Phase 3: Dependencies
12. **US-3.1** - Extend PRD schema with blockedBy
13. **US-3.3** - Implement dependency-aware selection
14. **US-3.4** - Validate PRD dependencies
15. **US-6.2** - Add task selection protocol

**Deliverable**: Dependency-aware task execution

### Phase 4: Automation
16. **US-1.3** - Create generate-pin.sh script
17. **US-3.2** - Extend PRD schema with epics
18. **US-4.1** - Implement build_context()
19. **US-4.2** - Implement keyword spec matching
20. **US-4.3** - Implement inject_context()
21. **US-4.4** - Integrate into Ralph loop

**Deliverable**: Smart context injection working

### Phase 5: Sustainability
22. **US-5.1** - Implement progress compaction
23. **US-5.2** - Implement task compaction
24. **US-5.3** - Implement pre-iteration hook
25. **US-5.4** - Integrate compaction into loop
26. **US-5.5** - Add compaction configuration

**Deliverable**: Memory compaction working

### Phase 6: Polish
27. **US-6.3** - Add implementation guidelines
28. **US-6.4** - Add post-implementation protocol

**Deliverable**: Complete enhanced system

---

## Testing Strategy

### Unit Tests
- `test_context_init()` - Verify directory/file creation
- `test_import_prd()` - Verify PRD conversion
- `test_get_ready_tasks()` - Verify dependency filtering
- `test_update_task()` - Verify status updates
- `test_compact_progress()` - Verify compaction behavior

### Integration Tests
- Full loop with Pin discovery enabled
- Full loop with dependencies
- Compaction triggering mid-loop
- Recovery from corrupt context files

### Validation Metrics
| Metric | Target | How to Validate |
|--------|--------|-----------------|
| Code duplication | <5% | Compare new code to Pin matches |
| Search hit rate | >80% | Log Pin matches vs implementations |
| Dependency violations | 0 | Verify task execution order |
| Context overflow | Rare | Track compaction frequency |

---

## Configuration

### Default Configuration (ralph.conf)
```bash
# Context Management Configuration
RALPH_CONTEXT_ENABLED=true
RALPH_PIN_PATH="specs/INDEX.md"
RALPH_CONTEXT_DIR=".ralph"

# Compaction Settings
RALPH_PROGRESS_THRESHOLD=400
RALPH_PROGRESS_KEEP_RECENT=200
RALPH_TASK_KEEP_COMPLETED=10
RALPH_COMPACTION_ENABLED=true

# Context Injection
RALPH_INJECT_CONTEXT=true
RALPH_MAX_SPEC_LINES=100
RALPH_MAX_CONTEXT_TOKENS=4000
```

---

## Success Criteria

The implementation is successful when:

1. **Discovery Works**: Agents read Pin before implementing and find existing code >80% of the time
2. **Dependencies Respected**: Tasks execute in correct order based on blockedBy
3. **Context Sustained**: Long-running sessions don't overflow context windows
4. **Discovered Work Tracked**: Agents can create and track discovered tasks
5. **Minimal Disruption**: Existing ralph.sh workflows continue to work without configuration

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Pin becomes stale | Medium | Add generate-pin.sh to CI, update instructions to maintain |
| Context overhead slows iterations | Low | Make injection optional, tune token limits |
| Compaction loses important info | Medium | Always preserve patterns, keep generous recent count |
| Complex dependencies confuse agents | Medium | Clear instructions, validation errors, sensible defaults |

---

## Future Enhancements (Out of Scope)

- Full Beads integration (external dependency)
- Semantic search over Pin (requires embeddings)
- Multi-project context sharing
- AI-powered compaction summaries
- Visual dependency graph generation
