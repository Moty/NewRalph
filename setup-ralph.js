#!/usr/bin/env node
/**
 * Ralph Setup Script - Install Ralph into any project repository
 * Cross-platform Node.js implementation
 *
 * Usage: node setup-ralph.js [target-directory]
 */

import { existsSync, readFileSync, writeFileSync, copyFileSync, mkdirSync, readdirSync, statSync, appendFileSync, chmodSync } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import YAML from 'yaml';

import {
  colors,
  commandExists,
  getClaudeCmd,
  confirm,
  readLine,
  readYaml,
  writeYaml,
  isWindows
} from './lib/common.js';

import { refreshModels, getCacheFilePath } from './lib/model-refresh.js';

// ---- Script Directory ------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const RALPH_DIR = __dirname;

// ---- Parse Arguments -------------------------------------------------

const args = process.argv.slice(2);

// Show usage if help requested
if (args.includes('-h') || args.includes('--help')) {
  console.log('Ralph Setup Script');
  console.log('');
  console.log('Usage: node setup-ralph.js [target-directory]');
  console.log('');
  console.log('Installs Ralph into the specified project directory.');
  console.log('If no directory is specified, uses current directory.');
  console.log('');
  console.log('Example:');
  console.log('  node setup-ralph.js /path/to/my/project');
  console.log('  node setup-ralph.js .');
  console.log('');
  process.exit(0);
}

const TARGET_DIR = args[0] || '.';
const TARGET_PATH = path.resolve(TARGET_DIR);

// ---- Validation -----------------------------------------------------

if (!existsSync(TARGET_PATH)) {
  console.log(`${colors.RED}Error: Target directory does not exist: ${TARGET_PATH}${colors.NC}`);
  process.exit(1);
}

if (!existsSync(path.join(TARGET_PATH, '.git'))) {
  console.log(`${colors.YELLOW}Warning: Target directory is not a git repository${colors.NC}`);
  const continueAnyway = await confirm('Continue anyway?', false);
  if (!continueAnyway) {
    process.exit(1);
  }
}

// ---- Check dependencies ---------------------------------------------

console.log('Checking dependencies...');

let HAS_CLAUDE = false;
let HAS_CODEX = false;
let HAS_COPILOT = false;
let HAS_GEMINI = false;

if (getClaudeCmd()) {
  HAS_CLAUDE = true;
  console.log(`${colors.GREEN}✓ Claude Code CLI found${colors.NC}`);
}

if (commandExists('codex')) {
  HAS_CODEX = true;
  console.log(`${colors.GREEN}✓ Codex CLI found${colors.NC}`);
}

if (commandExists('copilot')) {
  HAS_COPILOT = true;
  console.log(`${colors.GREEN}✓ GitHub Copilot CLI found${colors.NC}`);
}

if (commandExists('gemini')) {
  HAS_GEMINI = true;
  console.log(`${colors.GREEN}✓ Gemini CLI found${colors.NC}`);
}

if (!HAS_CLAUDE && !HAS_CODEX && !HAS_COPILOT && !HAS_GEMINI) {
  console.log(`${colors.RED}Error: No AI agent CLI found${colors.NC}`);
  console.log('Install at least one:');
  console.log('  Claude Code: https://docs.anthropic.com/claude/docs/cli');
  console.log('  Codex: https://github.com/openai/codex-cli');
  console.log('  GitHub Copilot CLI: npm install -g @github/copilot');
  console.log('  Gemini CLI: npm install -g @google/gemini-cli');
  process.exit(1);
}

// ---- Helper functions -----------------------------------------------

function copyDir(src, dest, options = {}) {
  const { excludePatterns = [] } = options;
  mkdirSync(dest, { recursive: true });
  const entries = readdirSync(src);

  for (const entry of entries) {
    // Skip files matching exclude patterns
    const shouldExclude = excludePatterns.some(pattern => {
      if (pattern instanceof RegExp) {
        return pattern.test(entry);
      }
      return entry.endsWith(pattern);
    });

    if (shouldExclude) {
      continue;
    }

    const srcPath = path.join(src, entry);
    const destPath = path.join(dest, entry);
    const stat = statSync(srcPath);

    if (stat.isDirectory()) {
      copyDir(srcPath, destPath, options);
    } else {
      copyFileSync(srcPath, destPath);
    }
  }
}

function makeExecutable(filePath) {
  if (!isWindows()) {
    try {
      chmodSync(filePath, 0o755);
    } catch {
      // Ignore chmod errors
    }
  }
}

// ---- Copy files -----------------------------------------------------

console.log('');
console.log(`Installing Ralph into: ${TARGET_PATH}`);
console.log('');

// Copy main script
console.log('→ Copying ralph.js');
copyFileSync(path.join(RALPH_DIR, 'ralph.js'), path.join(TARGET_PATH, 'ralph.js'));
makeExecutable(path.join(TARGET_PATH, 'ralph.js'));

// Copy PRD creation script
console.log('→ Copying create-prd.js');
copyFileSync(path.join(RALPH_DIR, 'create-prd.js'), path.join(TARGET_PATH, 'create-prd.js'));
makeExecutable(path.join(TARGET_PATH, 'create-prd.js'));

// Copy models helper script
console.log('→ Copying ralph-models.js');
copyFileSync(path.join(RALPH_DIR, 'ralph-models.js'), path.join(TARGET_PATH, 'ralph-models.js'));
makeExecutable(path.join(TARGET_PATH, 'ralph-models.js'));

// Copy package.json
console.log('→ Copying package.json');
copyFileSync(path.join(RALPH_DIR, 'package.json'), path.join(TARGET_PATH, 'package.json'));

// Copy agent configuration
console.log('→ Copying agent.yaml');
copyFileSync(path.join(RALPH_DIR, 'agent.yaml'), path.join(TARGET_PATH, 'agent.yaml'));

// Copy system instructions
console.log('→ Copying system_instructions/');
const sysInstrDir = path.join(TARGET_PATH, 'system_instructions');
mkdirSync(sysInstrDir, { recursive: true });
copyFileSync(path.join(RALPH_DIR, 'system_instructions', 'system_instructions.md'), path.join(sysInstrDir, 'system_instructions.md'));
copyFileSync(path.join(RALPH_DIR, 'system_instructions', 'system_instructions_codex.md'), path.join(sysInstrDir, 'system_instructions_codex.md'));
copyFileSync(path.join(RALPH_DIR, 'system_instructions', 'system_instructions_copilot.md'), path.join(sysInstrDir, 'system_instructions_copilot.md'));

// Copy lib directory with common functions (exclude .sh files)
if (existsSync(path.join(RALPH_DIR, 'lib'))) {
  console.log('→ Copying lib/');
  copyDir(path.join(RALPH_DIR, 'lib'), path.join(TARGET_PATH, 'lib'), {
    excludePatterns: ['.sh']
  });
}

// Copy skills (optional, exclude .sh files)
if (existsSync(path.join(RALPH_DIR, 'skills'))) {
  console.log('→ Copying skills/');
  copyDir(path.join(RALPH_DIR, 'skills'), path.join(TARGET_PATH, 'skills'), {
    excludePatterns: ['.sh']
  });
}

// Create PRD from example
const prdPath = path.join(TARGET_PATH, 'prd.json');
if (!existsSync(prdPath)) {
  console.log('→ Creating prd.json from example');
  copyFileSync(path.join(RALPH_DIR, 'prd.json.example'), prdPath);
} else {
  console.log('→ Skipping prd.json (already exists)');
}

// Create progress file
const progressPath = path.join(TARGET_PATH, 'progress.txt');
if (!existsSync(progressPath)) {
  console.log('→ Creating progress.txt');
  writeFileSync(progressPath, `# Ralph Progress Log\nStarted: ${new Date().toISOString()}\n---\n`);
} else {
  console.log('→ Skipping progress.txt (already exists)');
}

// Create archive directory
console.log('→ Creating archive/');
mkdirSync(path.join(TARGET_PATH, 'archive'), { recursive: true });

// Copy AGENTS.md template
const agentsMdPath = path.join(TARGET_PATH, 'AGENTS.md');
if (!existsSync(agentsMdPath)) {
  console.log('→ Creating AGENTS.md');
  writeFileSync(agentsMdPath, `# Agent Learnings

This file tracks patterns and learnings discovered during Ralph iterations.

## Patterns

*Document patterns here as they emerge*

## Common Issues

*Document recurring issues and solutions*

## Architecture Notes

*Document important architectural decisions*
`);
} else {
  console.log('→ Skipping AGENTS.md (already exists)');
}

// Update .gitignore
console.log('→ Updating .gitignore');
const gitignorePath = path.join(TARGET_PATH, '.gitignore');
const ralphGitignore = `
# Ralph
.last-branch
progress.txt
ralph.log
.ralph-models-cache.json
archive/
`;

if (existsSync(gitignorePath)) {
  const content = readFileSync(gitignorePath, 'utf8');
  if (!content.includes('# Ralph')) {
    appendFileSync(gitignorePath, ralphGitignore);
  }
} else {
  writeFileSync(gitignorePath, ralphGitignore.trim() + '\n');
}

// ---- Add technology-specific gitignore entries ----------------------

function appendToGitignore(content) {
  appendFileSync(gitignorePath, content);
}

function gitignoreContains(pattern) {
  if (!existsSync(gitignorePath)) return false;
  const content = readFileSync(gitignorePath, 'utf8');
  return content.includes(pattern);
}

// Node.js / JavaScript / TypeScript
if (existsSync(path.join(TARGET_PATH, 'package.json'))) {
  console.log('→ Detected Node.js project, updating .gitignore');
  if (!gitignoreContains('node_modules')) {
    appendToGitignore(`
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
`);
  }
}

// Python
if (existsSync(path.join(TARGET_PATH, 'requirements.txt')) ||
    existsSync(path.join(TARGET_PATH, 'pyproject.toml')) ||
    existsSync(path.join(TARGET_PATH, 'setup.py')) ||
    existsSync(path.join(TARGET_PATH, 'Pipfile'))) {
  console.log('→ Detected Python project, updating .gitignore');
  if (!gitignoreContains('__pycache__') && !gitignoreContains('venv')) {
    appendToGitignore(`
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
`);
  }
}

// Ruby
if (existsSync(path.join(TARGET_PATH, 'Gemfile'))) {
  console.log('→ Detected Ruby project, updating .gitignore');
  if (!gitignoreContains('vendor/bundle')) {
    appendToGitignore(`
# Ruby
vendor/bundle/
.bundle/
*.gem
coverage/
`);
  }
}

// Go
if (existsSync(path.join(TARGET_PATH, 'go.mod'))) {
  console.log('→ Detected Go project, updating .gitignore');
  if (!gitignoreContains('vendor/')) {
    appendToGitignore(`
# Go
vendor/
*.exe
*.exe~
*.dll
*.so
*.dylib
`);
  }
}

// Rust
if (existsSync(path.join(TARGET_PATH, 'Cargo.toml'))) {
  console.log('→ Detected Rust project, updating .gitignore');
  if (!gitignoreContains('target/')) {
    appendToGitignore(`
# Rust
target/
Cargo.lock
`);
  }
}

// Java / Kotlin / Gradle / Maven
if (existsSync(path.join(TARGET_PATH, 'pom.xml')) ||
    existsSync(path.join(TARGET_PATH, 'build.gradle')) ||
    existsSync(path.join(TARGET_PATH, 'build.gradle.kts'))) {
  console.log('→ Detected Java/Kotlin project, updating .gitignore');
  if (!gitignoreContains('target/') && !gitignoreContains('build/')) {
    appendToGitignore(`
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
`);
  }
}

// .NET / C#
const hasDotNet = readdirSync(TARGET_PATH).some(f =>
  f.endsWith('.csproj') || f.endsWith('.sln')
) || existsSync(path.join(TARGET_PATH, 'obj'));

if (hasDotNet) {
  console.log('→ Detected .NET project, updating .gitignore');
  if (!gitignoreContains('bin/') && !gitignoreContains('obj/')) {
    appendToGitignore(`
# .NET
bin/
obj/
*.user
*.suo
.vs/
`);
  }
}

// PHP / Composer
if (existsSync(path.join(TARGET_PATH, 'composer.json'))) {
  console.log('→ Detected PHP project, updating .gitignore');
  if (!gitignoreContains('vendor/')) {
    appendToGitignore(`
# PHP
vendor/
.phpunit.result.cache
`);
  }
}

// ---- Configure agent ------------------------------------------------

console.log('');
console.log('Configuring agent preference...');

const agentYamlPath = path.join(TARGET_PATH, 'agent.yaml');
let agentConfig = readYaml(agentYamlPath);

const agentCount = [HAS_CLAUDE, HAS_CODEX, HAS_COPILOT, HAS_GEMINI].filter(Boolean).length;

if (agentCount > 1) {
  console.log('Multiple AI agents are available.');
  console.log('Which would you like as primary?');

  const options = [];
  if (HAS_COPILOT) options.push({ name: 'GitHub Copilot CLI', value: 'github-copilot' });
  if (HAS_CLAUDE) options.push({ name: 'Claude Code', value: 'claude-code' });
  if (HAS_GEMINI) options.push({ name: 'Gemini', value: 'gemini' });
  if (HAS_CODEX) options.push({ name: 'Codex', value: 'codex' });

  options.forEach((opt, i) => {
    console.log(`  ${i + 1}) ${opt.name}`);
  });

  const choice = await readLine(`Enter choice (1-${options.length}): `);
  const choiceNum = parseInt(choice, 10);

  let selectedAgent = null;
  let fallbackAgent = null;

  if (choiceNum >= 1 && choiceNum <= options.length) {
    selectedAgent = options[choiceNum - 1].value;
    // Set fallback to first available alternative
    fallbackAgent = options.find(o => o.value !== selectedAgent)?.value || null;
  } else {
    // Invalid choice - use first available agent
    console.log(`${colors.YELLOW}⚠ Invalid choice, using first available agent as default${colors.NC}`);
    selectedAgent = options[0].value;
  }

  agentConfig.agent = agentConfig.agent || {};
  agentConfig.agent.primary = selectedAgent;
  if (fallbackAgent) {
    agentConfig.agent.fallback = fallbackAgent;
    console.log(`${colors.GREEN}✓ Configured ${selectedAgent} as primary, ${fallbackAgent} as fallback${colors.NC}`);
  } else {
    delete agentConfig.agent.fallback;
    console.log(`${colors.GREEN}✓ Configured ${selectedAgent} as primary (no fallback)${colors.NC}`);
  }

  writeYaml(agentYamlPath, agentConfig);

} else {
  // Single agent available
  let primary = null;
  if (HAS_COPILOT) primary = 'github-copilot';
  else if (HAS_CLAUDE) primary = 'claude-code';
  else if (HAS_GEMINI) primary = 'gemini';
  else if (HAS_CODEX) primary = 'codex';

  agentConfig.agent = agentConfig.agent || {};
  agentConfig.agent.primary = primary;
  delete agentConfig.agent.fallback;
  writeYaml(agentYamlPath, agentConfig);
  console.log(`${colors.GREEN}✓ Configured ${primary} as primary (no fallback)${colors.NC}`);
}

// ---- Refresh available models ---------------------------------------

console.log('');
console.log('Detecting available models...');

try {
  refreshModels({ baseDir: TARGET_PATH, silent: true });
  const cacheFile = getCacheFilePath(TARGET_PATH);

  if (existsSync(cacheFile)) {
    console.log(`${colors.GREEN}✓ Available models detected and cached${colors.NC}`);

    const cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
    console.log(`  • Claude models: ${cache.claude?.length || 0}`);
    console.log(`  • Codex models: ${cache.codex?.length || 0}`);
    console.log(`  • Gemini models: ${cache.gemini?.length || 0}`);
    console.log('');
    console.log(`  Run ${colors.CYAN}node ralph-models.js${colors.NC} to see full list`);
  } else {
    console.log(`${colors.YELLOW}⚠ Model detection completed (using defaults)${colors.NC}`);
  }
} catch {
  console.log(`${colors.YELLOW}⚠ Model refresh utility error (using static lists)${colors.NC}`);
}

// ---- Setup complete -------------------------------------------------

console.log('');
console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`${colors.GREEN}✓ Ralph setup complete!${colors.NC}`);
console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log('');
console.log('Next steps:');
console.log('');
console.log('1. Edit prd.json to define your project requirements:');
console.log(`   ${colors.YELLOW}cd ${TARGET_PATH} && vim prd.json${colors.NC}`);
console.log('');
console.log('2. Review and customize agent.yaml if needed:');
console.log(`   ${colors.YELLOW}vim agent.yaml${colors.NC}`);
console.log('');
console.log('3. Install dependencies and run Ralph:');
console.log(`   ${colors.YELLOW}npm install && node ralph.js${colors.NC}`);
console.log('');
console.log('Optional flags:');
console.log(`   ${colors.YELLOW}node ralph.js 20 --verbose${colors.NC}         # Run 20 iterations with verbose logging`);
console.log(`   ${colors.YELLOW}node ralph.js --timeout 7200${colors.NC}       # Set 2-hour timeout per iteration`);
console.log('');
console.log(`Files created in ${TARGET_PATH}:`);
console.log('  • ralph.js - Main execution script');
console.log('  • agent.yaml - Agent configuration');
console.log('  • system_instructions/ - Agent prompts');
console.log('  • lib/ - Validation and utility functions');
console.log('  • prd.json - Project requirements');
console.log('  • progress.txt - Iteration log');
console.log('  • ralph.log - Debug log (verbose mode)');
console.log('  • AGENTS.md - Pattern documentation');
console.log('  • archive/ - Previous run backups');
if (existsSync(path.join(RALPH_DIR, 'skills'))) {
  console.log('  • skills/ - Reusable skills library');
}
console.log('');
