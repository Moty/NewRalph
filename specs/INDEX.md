# The Pin - Ralph Discovery Index

This index helps AI agents discover existing functionality before implementing duplicates.

## Format

Each module entry includes:
- **Module Name**: Clear identifier for the functionality
- **Keywords**: Synonyms, library names, related terms (10-20 per module)
- **File Paths**: Where to find the implementation
- **Spec Link** (optional): Link to detailed specification

## Modules

### Agent System
**Keywords**: agent execution, agent loop, autonomous coding, iteration management, agent spawning, fresh context, claude code, codex, ai coding agents, continuous integration, task executor, agent orchestration, agent instance, agent lifecycle, copilot integration, agent types

**File Paths**:
- `ralph.sh` - Main agent loop executor
- `agent.yaml` - Agent configuration and fallback support
- `system_instructions/system_instructions.md` - Claude Code instructions
- `system_instructions/system_instructions_codex.md` - Codex instructions
- `system_instructions/system_instructions_copilot.md` - GitHub Copilot CLI instructions

**Spec Link**: N/A

---

### PRD Management
**Keywords**: product requirements, user stories, task definition, acceptance criteria, story validation, prd validation, json validation, task structure, requirements document, story tracking, task priorities, story dependencies, blockedBy, dependency graph, circular dependencies, task ordering

**File Paths**:
- `prd.json` - Current project requirements
- `prd.json.example` - Example PRD format
- `lib/common.sh` - PRD validation logic (validate_prd_json function)
- `create-prd.sh` - PRD generation script
- `skills/prd/` - PRD generation skill
- `skills/ralph/` - PRD conversion skill

**Spec Link**: See prd.json.example for format

---

### Progress Tracking
**Keywords**: progress logging, iteration history, learning capture, pattern discovery, codebase patterns, execution history, agent memory, state persistence, git history, commit tracking, task completion, progress append, learnings, gotchas, context preservation

**File Paths**:
- `progress.txt` - Main progress log
- `ralph.sh` - Progress tracking integration
- System instructions files - Define progress report format

**Spec Link**: N/A

---

### Installation & Setup
**Keywords**: installation, setup, bootstrap, project initialization, global install, windows support, wsl, git bash, powershell, unix installation, cross-platform, dependency installation, directory setup, file copying, setup script

**File Paths**:
- `install.sh` - Global installation for Linux/macOS
- `install.ps1` - Global installation for Windows
- `setup-ralph.sh` - Project-specific setup script
- `windows/` - Windows-specific wrapper scripts

**Spec Link**: See README.md and AGENTS.md

---

### Model Management
**Keywords**: model selection, model listing, ai models, claude models, gpt models, model cache, model refresh, available models, model configuration, primary agent, fallback agent, agent selection, model switching

**File Paths**:
- `ralph-models.sh` - Model listing and cache management
- `agent.yaml` - Model configuration

**Spec Link**: N/A

---

### Common Utilities
**Keywords**: bash utilities, common functions, shared functions, helper functions, utility library, bash 3.2 compatibility, jq processing, json manipulation, validation helpers, error handling, logging utilities, cross-platform bash

**File Paths**:
- `lib/common.sh` - Shared bash utilities and validation

**Spec Link**: N/A

---

### Documentation & Visualization
**Keywords**: flowchart, react flow, visualization, interactive diagram, documentation, readme, agents.md, pattern documentation, architecture diagram, presentation mode, animated flow, process visualization

**File Paths**:
- `flowchart/` - Interactive React Flow visualization
- `README.md` - Main documentation
- `AGENTS.md` - Agent-specific patterns and instructions
- `CONTEXT_MANAGEMENT_ENHANCEMENT.md` - Context management spec
- `ENHANCEMENTS.md` - Enhancement documentation

**Spec Link**: See flowchart/README.md

---

## Usage Guidelines

1. **Before implementing new functionality**: Search this index for related keywords
2. **Found a match?**: Read the referenced files and specs
3. **No match?**: Implement the feature and add it to this index
4. **Updating the index**: Run `scripts/generate-pin.sh` (if available) or update manually

## Maintenance

This index should be updated when:
- New major functionality is added
- Existing modules are significantly refactored
- Keywords need refinement based on discovery patterns
