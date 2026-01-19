# PRD: Context Management Enhancement

## Introduction

Enhance Ralph's autonomous agent loop with advanced context management capabilities to address the core limitation of context loss between iterations. This adds **The Pin** (discovery-based context), **structured task memory** (beads-inspired), **smart context injection**, and **memory compaction** to reduce hallucination, improve task continuity, and enable long-horizon work.

These enhancements integrate directly with the existing `ralph.sh` loop, `lib/common.sh` utilities, and the current `prd.json`/`progress.txt` persistence model.

## Goals

- Reduce code duplication caused by agent "invention" by providing a discovery index (The Pin)
- Add `blockedBy` dependency support to ensure proper story execution order
- Implement memory compaction to prevent context overflow during long runs
- Provide dynamic context injection based on current task keywords
- Maintain backward compatibility with existing `prd.json` format
- Keep all changes modular and opt-in (existing projects continue to work)

## Integration Points

### Existing Components to Modify
- `lib/common.sh` - Add `blockedBy` validation to `validate_prd_json()`
- `ralph.sh` - Add context hooks, update task selection to respect dependencies
- `system_instructions/system_instructions.md` - Add Discovery Protocol section
- `system_instructions/system_instructions_codex.md` - Add Discovery Protocol section
- `system_instructions/system_instructions_copilot.md` - Add Discovery Protocol section

### Existing Components to Reuse
- `lib/common.sh` - Logging utilities (`log_info`, `log_debug`, etc.)
- `lib/common.sh` - Color definitions (`$RED`, `$GREEN`, etc.)
- `lib/common.sh` - `validate_json_file()` function pattern
- `prd.json` schema - Extend with optional `blockedBy` field per story

### New Files to Create
- `lib/context.sh` - Native context management system (task memory, dependencies)
- `lib/context-builder.sh` - Dynamic context injection based on task keywords
- `lib/compaction.sh` - Memory decay/compaction for progress.txt
- `specs/INDEX.md` - The Pin (discovery index with keywords)
- `scripts/generate-pin.sh` - Auto-generate/update specs/INDEX.md

### Directory Changes
- Create `specs/` directory for spec index and feature specs
- Create `.ralph/` directory (runtime state, auto-created)

## Compatibility

### Backward Compatibility
- Existing `prd.json` files without `blockedBy` field continue to work (field is optional)
- Projects without `specs/INDEX.md` work normally (discovery is additive)
- Memory compaction only activates when `progress.txt` exceeds threshold
- All new features are opt-in via file presence

### Migration Requirements
- No database migrations required
- Existing projects: optionally run `generate-pin.sh` to create initial Pin
- No breaking changes to CLI arguments or configuration

### Deprecations
- None

## User Stories

### US-001: Add blockedBy validation to PRD
**Description:** As a developer, I want the PRD validator to support and validate `blockedBy` fields so that task dependencies are checked before Ralph runs.

**Acceptance Criteria:**
- [ ] `lib/common.sh` `validate_prd_json()` accepts optional `blockedBy` array field on each story
- [ ] Validation checks that all referenced story IDs in `blockedBy` exist in the PRD
- [ ] Validation logs warning for circular dependencies (A blocks B, B blocks A)
- [ ] Stories without `blockedBy` are treated as having no dependencies (backward compatible)
- [ ] Existing tests still pass (manual validation with existing prd.json.example)
- [ ] Typecheck passes (shellcheck lib/common.sh)

**Integration Notes:**
- Modifies: `lib/common.sh` - extend `validate_prd_json()` function
- Pattern reference: Follow existing validation style with `jq` queries

---

### US-002: Implement dependency-aware task selection
**Description:** As Ralph, I want to select only tasks whose dependencies are complete so that stories execute in the correct order.

**Acceptance Criteria:**
- [ ] `ralph.sh` `get_current_story()` checks `blockedBy` before selecting a task
- [ ] A story is "ready" when: `passes == false` AND all `blockedBy` story IDs have `passes == true`
- [ ] If no ready stories exist but incomplete stories remain, log a warning about blocked tasks
- [ ] Stories without `blockedBy` remain immediately selectable (backward compatible)
- [ ] Typecheck passes (shellcheck ralph.sh)

**Integration Notes:**
- Modifies: `ralph.sh` - update `get_current_story()` function
- Uses: `jq` for JSON filtering with dependency logic

---

### US-003: Create The Pin (specs/INDEX.md)
**Description:** As an AI agent, I want a searchable index of existing functionality so I can discover code before inventing duplicates.

**Acceptance Criteria:**
- [ ] Create `specs/INDEX.md` with documented format: module name, keywords, file paths, optional spec link
- [ ] Include at least 3 modules from Ralph codebase: Agent System, PRD Management, Progress Tracking
- [ ] Keywords include synonyms, library names, and related terms (10-20 per module)
- [ ] File is valid Markdown and easily parseable by agents
- [ ] Document the Pin format in README.md or AGENTS.md

**Integration Notes:**
- Creates: `specs/INDEX.md`
- Pattern reference: See Enhancement 1 in CONTEXT_MANAGEMENT_ENHANCEMENT.md

---

### US-004: Add Discovery Protocol to system instructions
**Description:** As a developer, I want agent system instructions to include discovery guidance so agents check existing code before implementing.

**Acceptance Criteria:**
- [ ] Add "## DISCOVERY PROTOCOL" section to `system_instructions/system_instructions.md`
- [ ] Add same section to `system_instructions/system_instructions_codex.md`
- [ ] Add same section to `system_instructions/system_instructions_copilot.md`
- [ ] Protocol instructs: 1) Read specs/INDEX.md, 2) Search with keywords, 3) Read matching specs, 4) Only invent if truly new
- [ ] Protocol is placed near the top of instructions (before implementation steps)

**Integration Notes:**
- Modifies: `system_instructions/system_instructions.md`
- Modifies: `system_instructions/system_instructions_codex.md`
- Modifies: `system_instructions/system_instructions_copilot.md`

---

### US-005: Create context management library
**Description:** As Ralph, I want a context management library to track task state with dependency awareness so complex projects maintain coherence.

**Acceptance Criteria:**
- [ ] Create `lib/context.sh` with functions: `init_context()`, `get_ready_tasks()`, `update_task()`, `create_discovered_task()`
- [ ] `get_ready_tasks()` returns tasks that are: not done, not blocked
- [ ] Context state stored in `.ralph/` directory (auto-created)
- [ ] `import_prd()` function converts existing `prd.json` to context format
- [ ] Library can be sourced from `ralph.sh` like `lib/common.sh`
- [ ] Typecheck passes (shellcheck lib/context.sh)

**Integration Notes:**
- Creates: `lib/context.sh`
- Pattern reference: Follow `lib/common.sh` structure (logging, color, function organization)

---

### US-006: Implement memory compaction
**Description:** As Ralph, I want automatic memory compaction so long-running sessions don't overflow context windows.

**Acceptance Criteria:**
- [ ] Create `lib/compaction.sh` with `compact_progress()` function
- [ ] Compaction triggers when `progress.txt` exceeds 400 lines (configurable threshold)
- [ ] Compaction preserves: patterns section (first ~50 lines), recent entries (last ~200 lines)
- [ ] Middle section is summarized to key bullet points
- [ ] Compaction logs action to `.ralph/compaction.log`
- [ ] Add `pre_iteration_compact()` hook that can be called from `ralph.sh`
- [ ] Typecheck passes (shellcheck lib/compaction.sh)

**Integration Notes:**
- Creates: `lib/compaction.sh`
- Pattern reference: Follow `lib/common.sh` logging patterns

---

### US-007: Create generate-pin script
**Description:** As a developer, I want a script to auto-generate specs/INDEX.md from codebase analysis so the Pin stays current.

**Acceptance Criteria:**
- [ ] Create `scripts/generate-pin.sh` that scans codebase structure
- [ ] Script identifies major directories and generates keyword suggestions
- [ ] Output is valid `specs/INDEX.md` format with placeholder keywords
- [ ] Script is idempotent (can be run multiple times safely)
- [ ] Script is executable (`chmod +x`)
- [ ] Document usage in README.md

**Integration Notes:**
- Creates: `scripts/generate-pin.sh`
- Creates: `specs/` directory if not exists

---

### US-008: Implement context builder for dynamic injection
**Description:** As Ralph, I want dynamic context injection based on current task keywords so agents receive relevant context.

**Acceptance Criteria:**
- [ ] Create `lib/context-builder.sh` with `build_context()` function
- [ ] `build_context()` takes current task title/description as input
- [ ] Extracts keywords from task and searches `specs/INDEX.md` for matches
- [ ] Includes: Pin index, matching specs (first 100 lines), recent progress, codebase patterns
- [ ] `inject_context()` function wraps base prompt with relevant context
- [ ] Typecheck passes (shellcheck lib/context-builder.sh)

**Integration Notes:**
- Creates: `lib/context-builder.sh`
- Uses: `specs/INDEX.md` for keyword matching

---

### US-009: Integrate context system into ralph.sh
**Description:** As a developer, I want ralph.sh to optionally use the new context system so enhanced features are available.

**Acceptance Criteria:**
- [ ] `ralph.sh` sources `lib/context.sh` if present (optional enhancement)
- [ ] `ralph.sh` sources `lib/compaction.sh` if present and calls `pre_iteration_compact()`
- [ ] Task selection uses `get_ready_tasks()` when available, falls back to current logic
- [ ] All changes are backward compatible (Ralph works without new libs)
- [ ] Typecheck passes (shellcheck ralph.sh)
- [ ] Manual test: run `./ralph.sh 1` successfully with existing prd.json.example

**Integration Notes:**
- Modifies: `ralph.sh` - add optional library sourcing and hooks
- Uses: `lib/context.sh`, `lib/compaction.sh`, `lib/context-builder.sh`

---

### US-010: Update prd.json.example with blockedBy
**Description:** As a developer, I want the example PRD to demonstrate `blockedBy` usage so new users understand the feature.

**Acceptance Criteria:**
- [ ] Update `prd.json.example` to include `blockedBy` field on stories US-002, US-003, US-004
- [ ] US-002 depends on US-001, US-003 depends on US-001, US-004 depends on US-002
- [ ] Example validates successfully with updated `validate_prd_json()`
- [ ] Add brief comment in example explaining blockedBy usage

**Integration Notes:**
- Modifies: `prd.json.example`
- Validates with: `lib/common.sh` `validate_prd_json()`

---

### US-011: Document context management in AGENTS.md
**Description:** As a developer, I want AGENTS.md to document the new context management features so future agents understand how to use them.

**Acceptance Criteria:**
- [ ] Add "Context Management" section to AGENTS.md
- [ ] Document: The Pin (specs/INDEX.md), blockedBy dependencies, memory compaction
- [ ] Include examples of using discovery protocol
- [ ] Document `.ralph/` directory purpose and contents
- [ ] Keep documentation concise (< 50 lines for new section)

**Integration Notes:**
- Modifies: `AGENTS.md`

## Functional Requirements

- FR-1: `blockedBy` field is optional on all user stories (backward compatible)
- FR-2: All `blockedBy` references must point to valid story IDs within the same PRD
- FR-3: Tasks with unmet dependencies are never selected for execution
- FR-4: The Pin (specs/INDEX.md) follows a documented, parseable format
- FR-5: Memory compaction preserves patterns and recent history while summarizing old entries
- FR-6: All new library files follow existing `lib/common.sh` patterns (shebang, logging, colors)
- FR-7: Context system gracefully degrades when optional files/directories are missing

## Non-Goals

- No external dependency on Beads CLI (native implementation only)
- No automatic Pin generation using AI (script provides structure, humans add keywords)
- No database or external storage (all state in filesystem)
- No changes to agent.yaml configuration format
- No UI for managing context (CLI/file-based only)
- No real-time context updates during agent execution (per-iteration only)
- No hierarchical epics support in this release (future enhancement)

## Technical Considerations

### Alignment with Existing Architecture
- All new libraries follow `lib/common.sh` patterns (sourcing, logging, colors)
- New scripts follow `ralph.sh` patterns (argument parsing, help text)
- State files use JSON/Markdown for consistency with existing files
- Directory structure mirrors existing conventions (`lib/`, `scripts/`, `system_instructions/`)

### Performance Impact
- Compaction only runs when threshold exceeded (no impact on short runs)
- Pin reading adds minimal overhead (single file read per iteration)
- Context building is opt-in and runs once per iteration

### Testing Strategy
- Manual testing with `prd.json.example` and existing Ralph workflows
- ShellCheck validation for all new bash scripts
- Backward compatibility verified by running Ralph without new files

### Error Handling
- Missing optional files logged as debug messages, not errors
- Invalid blockedBy references fail validation with clear error message
- Compaction failures are logged but don't halt Ralph execution

## Success Metrics

- Zero code duplication issues when agents use discovery protocol
- Task execution order respects all dependency constraints
- Ralph runs for 20+ iterations without context overflow
- All existing Ralph projects work without modification

## Open Questions

1. Should `generate-pin.sh` use AI assistance or remain purely structural?
2. Should compaction thresholds be configurable via `agent.yaml`?
3. Should we add a `--discover` flag to Ralph for manual Pin searches?
4. How should circular dependencies be handled (error vs. warning)?
