#!/usr/bin/env node
/**
 * Automated PRD creation and conversion to Ralph format
 * Cross-platform Node.js implementation
 *
 * Usage: node create-prd.js [OPTIONS] "your project description"
 * Supports: GitHub Copilot CLI, Claude Code, Codex, Gemini
 */

import { existsSync, readFileSync, mkdirSync, readdirSync } from 'fs';
import { execSync, spawnSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  colors,
  commandExists,
  getClaudeCmd,
  confirm
} from './lib/common.js';

// ---- Script Directory ------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCRIPT_DIR = __dirname;

// ---- Configuration --------------------------------------------------

let PROJECT_DESC = '';
let DRAFT_ONLY = false;
let PROJECT_TYPE = '';  // greenfield, brownfield, or auto
let PREFERRED_MODEL = '';  // Optional model override

// ---- Help & Usage ---------------------------------------------------

function showHelp() {
  console.log('create-prd.js - Automated PRD generation and conversion');
  console.log('');
  console.log('Usage: node create-prd.js [OPTIONS] "your project description"');
  console.log('');
  console.log('Options:');
  console.log('  -h, --help        Show this help message');
  console.log('  --draft-only      Generate PRD draft only (skip JSON conversion)');
  console.log('  --greenfield      Force greenfield mode (new project from scratch)');
  console.log('  --brownfield      Force brownfield mode (adding to existing codebase)');
  console.log('  --model MODEL     Specify AI model for PRD generation:');
  console.log('                      claude-opus    - Best for technical PRDs (Claude Opus 4.5)');
  console.log('                      claude-sonnet  - Balanced quality/cost (Claude Sonnet 4.5)');
  console.log('                      gemini-pro     - Large context analysis (Gemini 2.5 Pro)');
  console.log('                      gpt-codex      - OpenAI Codex models');
  console.log('');
  console.log('Agent priority: GitHub Copilot CLI → Claude Code → Gemini → Codex');
  console.log('');
  console.log('Project Type Detection (automatic unless --greenfield/--brownfield specified):');
  console.log('  Greenfield: No package.json/requirements.txt, no src/, <10 git commits');
  console.log('  Brownfield: Existing codebase with established patterns');
  console.log('');
  console.log('Model Recommendations:');
  console.log('  Greenfield projects   → claude-sonnet (best balance for new architecture)');
  console.log('  Small brownfield      → claude-opus (best technical accuracy)');
  console.log('  Large brownfield      → gemini-pro (1M token context for full codebase)');
  console.log('');
  console.log('Examples:');
  console.log('  node create-prd.js "A task management API with CRUD operations"');
  console.log('  node create-prd.js --brownfield "Add user notifications to existing app"');
  console.log('  node create-prd.js --model gemini-pro --brownfield "Refactor authentication"');
  console.log('');
  console.log('Output:');
  console.log('  - tasks/prd-draft.md   Markdown PRD document');
  console.log('  - prd.json             Ralph-formatted JSON (unless --draft-only)');
  process.exit(0);
}

// ---- Parse Arguments ------------------------------------------------

const args = process.argv.slice(2);

for (let i = 0; i < args.length; i++) {
  const arg = args[i];

  if (arg === '-h' || arg === '--help') {
    showHelp();
  } else if (arg === '--draft-only') {
    DRAFT_ONLY = true;
  } else if (arg === '--greenfield') {
    PROJECT_TYPE = 'greenfield';
  } else if (arg === '--brownfield') {
    PROJECT_TYPE = 'brownfield';
  } else if (arg === '--model') {
    i++;
    PREFERRED_MODEL = args[i];
  } else if (!arg.startsWith('-')) {
    if (!PROJECT_DESC) {
      PROJECT_DESC = arg;
    }
  }
}

if (!PROJECT_DESC) {
  console.log('Usage: node create-prd.js [OPTIONS] "your project description"');
  console.log("Run 'node create-prd.js --help' for more options");
  process.exit(1);
}

// ---- Project Type Detection -----------------------------------------

function detectProjectType() {
  let indicators = 0;

  // Check for package managers / project files
  const projectFiles = ['package.json', 'requirements.txt', 'Cargo.toml', 'go.mod', 'pom.xml', 'build.gradle', 'Gemfile'];
  if (projectFiles.some(f => existsSync(f))) {
    indicators += 2;
  }

  // Check for source directories
  const srcDirs = ['src', 'lib', 'app', 'pkg'];
  if (srcDirs.some(d => existsSync(d))) {
    indicators += 2;
  }

  // Check git history
  try {
    const commitCount = parseInt(execSync('git rev-list --count HEAD', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim(), 10);
    if (commitCount > 10) {
      indicators += 2;
    } else if (commitCount > 3) {
      indicators += 1;
    }
  } catch {
    // Not a git repo or no commits
  }

  // Check for existing tests
  const testDirs = ['tests', 'test', '__tests__', 'spec'];
  if (testDirs.some(d => existsSync(d))) {
    indicators += 1;
  }

  // Check for config files indicating established project
  const configFiles = ['.eslintrc.js', 'tsconfig.json', 'jest.config.js', '.prettierrc', 'webpack.config.js', 'vite.config.ts'];
  if (configFiles.some(f => existsSync(f))) {
    indicators += 1;
  }

  return indicators >= 3 ? 'brownfield' : 'greenfield';
}

function gatherBrownfieldContext() {
  let context = '';

  // Gather tech stack
  if (existsSync('package.json')) {
    try {
      const pkg = JSON.parse(readFileSync('package.json', 'utf8'));
      context += '## Tech Stack (from package.json)\n';
      context += `Dependencies: ${Object.keys(pkg.dependencies || {}).join(', ') || 'N/A'}\n`;
      context += `Dev Dependencies: ${Object.keys(pkg.devDependencies || {}).join(', ') || 'N/A'}\n\n`;
    } catch {
      // Ignore parse errors
    }
  }

  if (existsSync('requirements.txt')) {
    const content = readFileSync('requirements.txt', 'utf8');
    const lines = content.split('\n').slice(0, 20).join('\n');
    context += '## Tech Stack (from requirements.txt)\n';
    context += `${lines}\n\n`;
  }

  // Gather directory structure
  context += '## Directory Structure\n```\n';
  try {
    const result = execSync('find . -maxdepth 3 -type d ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/.*" 2>/dev/null | head -30', {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    });
    context += result || 'Unable to list directories';
  } catch {
    context += 'Unable to list directories';
  }
  context += '\n```\n\n';

  // Gather API routes if they exist
  if (existsSync('app/api') || existsSync('src/api') || existsSync('pages/api')) {
    context += '## Existing API Routes\n```\n';
    try {
      const result = execSync('find . -path "*/api/*.ts" -o -path "*/api/*.js" 2>/dev/null | head -20', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      context += result || 'None found';
    } catch {
      context += 'None found';
    }
    context += '\n```\n\n';
  }

  // Check for database schema
  if (existsSync('prisma') || existsSync('drizzle') || existsSync('migrations')) {
    context += '## Database Schema Location\n';
    if (existsSync('prisma/schema.prisma')) {
      const schema = readFileSync('prisma/schema.prisma', 'utf8');
      const modelCount = (schema.match(/^model /gm) || []).length;
      context += 'Schema: prisma/schema.prisma\n';
      context += `Models: ${modelCount} models found\n`;
    }
    if (existsSync('drizzle')) {
      context += 'Schema: drizzle/ directory\n';
    }
    context += '\n';
  }

  // Check for component library patterns
  if (existsSync('src/components') || existsSync('components') || existsSync('app/components')) {
    context += '## UI Component Patterns\n';
    const componentDirs = ['src/components', 'components', 'app/components'].filter(d => existsSync(d));
    context += `Components found in: ${componentDirs.join(', ')}\n`;

    try {
      const result = execSync('find . -path "*/components/*.tsx" -o -path "*/components/*.jsx" 2>/dev/null | head -5 | xargs -I {} basename {} 2>/dev/null | tr "\\n" ", "', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      context += `Sample components: ${result}\n`;
    } catch {
      // Ignore
    }
    context += '\n';
  }

  return context;
}

// Auto-detect if not specified
if (!PROJECT_TYPE) {
  PROJECT_TYPE = detectProjectType();
  console.log(`${colors.CYAN}Auto-detected project type: ${colors.YELLOW}${PROJECT_TYPE}${colors.NC}`);
}

console.log(`${colors.GREEN}Project type: ${colors.YELLOW}${PROJECT_TYPE}${colors.NC}`);

// ---- Detect available agents ----------------------------------------

let AGENT = '';
let AGENT_NAME = '';

function inferAgentFromModel(model) {
  if (model.startsWith('gemini-')) {
    if (commandExists('gemini')) {
      AGENT = 'gemini';
      AGENT_NAME = 'Gemini';
      return true;
    } else {
      console.log(`${colors.RED}Error: Gemini CLI not installed but gemini model specified${colors.NC}`);
      console.log('Install: npm install -g @google/gemini-cli');
      process.exit(1);
    }
  } else if (model.startsWith('claude-')) {
    const claudeCmd = getClaudeCmd();
    if (claudeCmd) {
      AGENT = claudeCmd;
      AGENT_NAME = 'Claude Code';
      return true;
    } else {
      console.log(`${colors.RED}Error: Claude CLI not installed but claude model specified${colors.NC}`);
      console.log('Install: https://docs.anthropic.com/claude/docs/cli');
      process.exit(1);
    }
  } else if (model.startsWith('gpt-') || model === 'codex') {
    if (commandExists('codex')) {
      AGENT = 'codex';
      AGENT_NAME = 'Codex';
      return true;
    } else {
      console.log(`${colors.RED}Error: Codex CLI not installed but gpt/codex model specified${colors.NC}`);
      console.log('Install: npm install -g @openai/codex');
      process.exit(1);
    }
  }
  return false;
}

// If model was specified via --model, try to infer agent from it
if (PREFERRED_MODEL) {
  if (inferAgentFromModel(PREFERRED_MODEL)) {
    console.log(`${colors.CYAN}Model specified: ${colors.YELLOW}${PREFERRED_MODEL}${colors.NC} → using ${colors.CYAN}${AGENT_NAME}${colors.NC}`);
  }
}

// If agent wasn't set by model inference, auto-detect by priority
if (!AGENT) {
  // Priority 1: GitHub Copilot CLI
  if (commandExists('copilot')) {
    AGENT = 'copilot';
    AGENT_NAME = 'GitHub Copilot CLI';
  }
  // Priority 2: Claude Code
  else if (getClaudeCmd()) {
    AGENT = getClaudeCmd();
    AGENT_NAME = 'Claude Code';
  }
  // Priority 3: Gemini
  else if (commandExists('gemini')) {
    AGENT = 'gemini';
    AGENT_NAME = 'Gemini';
  }
  // Priority 4: Codex
  else if (commandExists('codex')) {
    AGENT = 'codex';
    AGENT_NAME = 'Codex';
  } else {
    console.log(`${colors.RED}Error: No AI agent found.${colors.NC}`);
    console.log('Please install one of the following:');
    console.log('  - GitHub Copilot CLI: https://github.com/github/gh-copilot');
    console.log('  - Claude Code: https://docs.anthropic.com/claude/docs/cli');
    console.log('  - Gemini CLI: npm install -g @google/gemini-cli');
    console.log('  - Codex: npm install -g @openai/codex');
    process.exit(1);
  }
}

console.log(`${colors.GREEN}Using agent: ${colors.CYAN}${AGENT_NAME}${colors.NC}`);

// ---- Model Selection ------------------------------------------------

function getRecommendedModel(type) {
  if (type === 'greenfield') {
    return 'claude-sonnet';  // Best balance for new architecture decisions
  } else if (type === 'brownfield') {
    // Check codebase size
    try {
      const result = execSync('find . -type f \\( -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" \\) 2>/dev/null | wc -l', {
        encoding: 'utf8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      const fileCount = parseInt(result.trim(), 10) || 0;
      if (fileCount > 100) {
        return 'gemini-pro';  // Large context for big codebases
      }
      return 'claude-opus';  // Best accuracy for smaller brownfield
    } catch {
      return 'claude-opus';
    }
  }
  return 'claude-sonnet';
}

if (!PREFERRED_MODEL) {
  PREFERRED_MODEL = getRecommendedModel(PROJECT_TYPE);
  console.log(`${colors.CYAN}Recommended model for ${PROJECT_TYPE}: ${colors.YELLOW}${PREFERRED_MODEL}${colors.NC}`);
}

// ---- Agent-specific run functions -----------------------------------

function runCopilot(prompt) {
  const result = spawnSync('copilot', ['-p', prompt, '--allow-all-tools'], {
    stdio: 'inherit',
    shell: true
  });
  return result.status || 0;
}

function runClaude(prompt) {
  let modelFlag = '';
  if (PREFERRED_MODEL === 'claude-opus') {
    modelFlag = '--model claude-opus-4-20250514';
  } else if (PREFERRED_MODEL === 'claude-sonnet') {
    modelFlag = '--model claude-sonnet-4-20250514';
  }

  const claudeCmd = AGENT === 'claude' ? 'claude' : AGENT;
  const args = ['--print', '--dangerously-skip-permissions'];
  if (modelFlag) {
    const [flag, model] = modelFlag.split(' ');
    args.push(flag, model);
  }
  args.push(prompt);

  const result = spawnSync(claudeCmd, args, {
    stdio: 'inherit',
    shell: true
  });
  return result.status || 0;
}

function runGemini(prompt) {
  let model = 'gemini-2.5-pro';
  if (PREFERRED_MODEL === 'gemini-pro') model = 'gemini-2.5-pro';
  else if (PREFERRED_MODEL === 'gemini-flash') model = 'gemini-2.5-flash';

  const result = spawnSync('gemini', ['--model', model, '--yolo', prompt], {
    stdio: 'inherit',
    shell: true
  });
  return result.status || 0;
}

function runCodex(prompt) {
  const result = spawnSync('codex', ['exec', '--full-auto', prompt], {
    stdio: 'inherit',
    shell: true
  });
  return result.status || 0;
}

function runAgentCommand(prompt) {
  if (AGENT === 'copilot') {
    return runCopilot(prompt);
  } else if (AGENT === 'claude' || AGENT.includes('claude')) {
    return runClaude(prompt);
  } else if (AGENT === 'gemini') {
    return runGemini(prompt);
  } else if (AGENT === 'codex') {
    return runCodex(prompt);
  }
  console.log(`${colors.RED}Unknown agent: ${AGENT}${colors.NC}`);
  process.exit(1);
}

// ---- Gather Context for Brownfield ----------------------------------

let BROWNFIELD_CONTEXT = '';
if (PROJECT_TYPE === 'brownfield') {
  console.log('');
  console.log(`${colors.CYAN}Gathering existing codebase context...${colors.NC}`);
  BROWNFIELD_CONTEXT = gatherBrownfieldContext();
  console.log(`${colors.GREEN}✓ Context gathered${colors.NC}`);
}

// ---- Step 1: Generate PRD -------------------------------------------

console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(`Step 1: Generating PRD (${PROJECT_TYPE} mode)...`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

// Create tasks directory if it doesn't exist
mkdirSync('tasks', { recursive: true });

// Select the appropriate skill file
let SKILL_FILE = path.join(SCRIPT_DIR, 'skills', 'prd', 'SKILL.md');
if (PROJECT_TYPE === 'greenfield' && existsSync(path.join(SCRIPT_DIR, 'skills', 'prd', 'GREENFIELD.md'))) {
  SKILL_FILE = path.join(SCRIPT_DIR, 'skills', 'prd', 'GREENFIELD.md');
} else if (PROJECT_TYPE === 'brownfield' && existsSync(path.join(SCRIPT_DIR, 'skills', 'prd', 'BROWNFIELD.md'))) {
  SKILL_FILE = path.join(SCRIPT_DIR, 'skills', 'prd', 'BROWNFIELD.md');
}

// Build the prompt
let PRD_PROMPT = `Load the prd skill from ${SKILL_FILE} and create a PRD for: ${PROJECT_DESC}

Project type: ${PROJECT_TYPE}`;

if (PROJECT_TYPE === 'brownfield' && BROWNFIELD_CONTEXT) {
  PRD_PROMPT += `

## Existing Codebase Context
${BROWNFIELD_CONTEXT}

IMPORTANT: Consider the existing patterns, tech stack, and architecture when defining requirements.
Ensure new features integrate smoothly with existing code.`;
}

PRD_PROMPT += `

Answer all clarifying questions with reasonable defaults and generate the complete PRD. Save it to tasks/prd-draft.md`;

// Generate PRD using the detected agent with the PRD skill
runAgentCommand(PRD_PROMPT);

console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('Step 2: Converting PRD to Ralph JSON format...');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

// Check if PRD was created
if (!existsSync('tasks/prd-draft.md')) {
  console.log(`${colors.RED}Error: PRD file not found at tasks/prd-draft.md${colors.NC}`);
  process.exit(1);
}

// If draft-only mode, skip conversion
if (DRAFT_ONLY) {
  console.log('');
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log(`${colors.GREEN}✓ PRD Draft Complete!${colors.NC}`);
  console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  console.log('');
  console.log('File created:');
  console.log('  - tasks/prd-draft.md - Original PRD');
  console.log('');
  console.log('Next steps:');
  console.log('  1. Review tasks/prd-draft.md');
  console.log('  2. Run without --draft-only to convert to prd.json');
  console.log('  3. Or manually convert: Load the ralph skill and convert tasks/prd-draft.md');
  console.log('');
  process.exit(0);
}

// Warn if prd.json already exists
if (existsSync('prd.json')) {
  console.log('');
  console.log(`${colors.YELLOW}Warning: prd.json already exists in this directory.${colors.NC}`);
  console.log('   Continuing will overwrite the existing file.');
  console.log('');
  const shouldContinue = await confirm('Continue?', false);
  if (!shouldContinue) {
    console.log('Cancelled. Your existing prd.json was not modified.');
    process.exit(0);
  }
}

// Convert PRD to prd.json using the detected agent with the Ralph skill
const RALPH_SKILL_FILE = path.join(SCRIPT_DIR, 'skills', 'ralph', 'SKILL.md');
runAgentCommand(`Load the ralph skill from ${RALPH_SKILL_FILE} and convert tasks/prd-draft.md to prd.json.

Make sure each story is small and completable in one iteration. Save the output to prd.json in the current directory.`);

console.log('');
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log(`${colors.GREEN}✓ PRD Creation Complete!${colors.NC}`);
console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
console.log('');
console.log('Files created:');
console.log(`  - tasks/prd-draft.md - Original PRD (${PROJECT_TYPE})`);
console.log('  - prd.json - Ralph-formatted requirements');
console.log('');
console.log('Next steps:');
console.log('  1. Review prd.json to ensure stories are appropriately sized');
console.log('  2. Run Ralph: node ralph.js');
console.log('');
