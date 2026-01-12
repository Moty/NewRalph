#!/usr/bin/env node
/**
 * Ralph Wiggum - Long-running AI agent loop (agent-agnostic)
 * Cross-platform Node.js implementation
 *
 * Usage: node ralph.js [max_iterations] [--no-sleep-prevent] [--verbose] [--timeout SECONDS] [--no-timeout] [--greenfield] [--brownfield]
 * Agent priority: GitHub Copilot CLI → Claude Code → Gemini → Codex
 */

import { existsSync, readFileSync, writeFileSync, copyFileSync, mkdirSync } from 'fs';
import { spawn, execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';
import YAML from 'yaml';

import {
  colors,
  logInfo,
  logError,
  logWarn,
  logDebug,
  setLogFile,
  setVerbose,
  isVerbose,
  commandExists,
  requireBin,
  getClaudeCmd,
  validatePrdJson,
  validateAgentYaml,
  validateGitStatus,
  formatDuration,
  runWithTimeout,
  readYaml,
  readJson,
  writeJson,
  sleep,
  isMacOS,
  isWindows,
  isLinux
} from './lib/common.js';

// ---- Script Directory ------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCRIPT_DIR = __dirname;

// ---- Configuration --------------------------------------------------

let MAX_ITERATIONS = 10;
let PREVENT_SLEEP = true;
let VERBOSE = false;
let AGENT_TIMEOUT = 7200;  // Default 2 hour timeout per agent iteration (0 = no timeout)
let PROJECT_TYPE = '';  // greenfield, brownfield, or auto-detected

// Parse command line arguments
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  const arg = args[i];

  if (arg === '--no-sleep-prevent') {
    PREVENT_SLEEP = false;
  } else if (arg === '--verbose' || arg === '-v') {
    VERBOSE = true;
    setVerbose(true);
  } else if (arg === '--no-timeout') {
    AGENT_TIMEOUT = 0;
  } else if (arg === '--timeout') {
    i++;
    AGENT_TIMEOUT = parseInt(args[i], 10);
  } else if (arg === '--greenfield') {
    PROJECT_TYPE = 'greenfield';
  } else if (arg === '--brownfield') {
    PROJECT_TYPE = 'brownfield';
  } else if (!arg.startsWith('-') && !isNaN(parseInt(arg, 10))) {
    MAX_ITERATIONS = parseInt(arg, 10);
  }
}

const PRD_FILE = path.join(SCRIPT_DIR, 'prd.json');
const PROGRESS_FILE = path.join(SCRIPT_DIR, 'progress.txt');
const ARCHIVE_DIR = path.join(SCRIPT_DIR, 'archive');
const LAST_BRANCH_FILE = path.join(SCRIPT_DIR, '.last-branch');
const AGENT_CONFIG = path.join(SCRIPT_DIR, 'agent.yaml');
const LOG_FILE = path.join(SCRIPT_DIR, 'ralph.log');

setLogFile(LOG_FILE);
process.env.LOG_FILE = LOG_FILE;
process.env.VERBOSE = VERBOSE.toString();

const START_TIME = Date.now();

// ---- Helper Functions -----------------------------------------------

function getElapsedTime() {
  const elapsed = Math.floor((Date.now() - START_TIME) / 1000);
  return formatDuration(elapsed);
}

function getCurrentStory() {
  if (existsSync(PRD_FILE)) {
    try {
      const prd = readJson(PRD_FILE);
      const story = prd.userStories.find(s => s.passes === false);
      if (story) {
        return `${story.id}: ${story.title}`;
      }
      return 'All stories complete';
    } catch {
      return 'Error reading PRD';
    }
  }
  return 'No PRD found';
}

function getStoryProgress() {
  if (existsSync(PRD_FILE)) {
    try {
      const prd = readJson(PRD_FILE);
      const total = prd.userStories.length;
      const complete = prd.userStories.filter(s => s.passes === true).length;
      return `${complete}/${total}`;
    } catch {
      return '?/?';
    }
  }
  return '?/?';
}

function checkRateLimit(output) {
  const patterns = /hit your limit|rate limit|quota exceeded|too many requests|resets [0-9]/i;
  return patterns.test(output);
}

function checkError(output) {
  return /"is_error":true|error_during_execution/i.test(output);
}

function printStatus(iteration, max) {
  let story = getCurrentStory();
  const progress = getStoryProgress();
  const elapsed = getElapsedTime();

  if (story.length > 45) {
    story = story.substring(0, 42) + '...';
  }

  console.log('');
  console.log(`${colors.CYAN}┌─────────────────────────────────────────────────────────┐${colors.NC}`);
  console.log(`${colors.CYAN}│${colors.NC}  ${colors.BLUE}Ralph Iteration${colors.NC} ${colors.YELLOW}${iteration}${colors.NC} of ${colors.YELLOW}${max}${colors.NC}`);
  console.log(`${colors.CYAN}├─────────────────────────────────────────────────────────┤${colors.NC}`);
  console.log(`${colors.CYAN}│${colors.NC}  📊 Stories: ${colors.GREEN}${progress}${colors.NC} complete`);
  console.log(`${colors.CYAN}│${colors.NC}  🎯 Current: ${colors.YELLOW}${story}${colors.NC}`);
  console.log(`${colors.CYAN}│${colors.NC}  ⏱️  Elapsed: ${colors.BLUE}${elapsed}${colors.NC}`);
  console.log(`${colors.CYAN}└─────────────────────────────────────────────────────────┘${colors.NC}`);
  console.log('');
}

function printIterationSummary(iteration, duration, status) {
  const elapsed = getElapsedTime();
  const progress = getStoryProgress();
  const durationStr = formatDuration(duration);

  if (status === 'success') {
    console.log(`${colors.GREEN}✓ Iteration ${iteration} complete${colors.NC} (${durationStr}) | Stories: ${progress} | Total: ${elapsed}`);
  } else if (status === 'rate_limited') {
    console.log(`${colors.RED}⚠ Rate limited${colors.NC} - stopping Ralph`);
  } else if (status === 'error') {
    console.log(`${colors.YELLOW}⚠ Iteration ${iteration} had errors${colors.NC} (${durationStr}) | Stories: ${progress}`);
  } else {
    console.log(`${colors.BLUE}→ Iteration ${iteration} finished${colors.NC} (${durationStr})`);
  }
}

// Sleep prevention process reference
let sleepPreventionPid = null;

function cleanup() {
  if (sleepPreventionPid) {
    try {
      process.kill(sleepPreventionPid);
    } catch {
      // Process may have already exited
    }
  }
  console.log('');
  console.log(`${colors.YELLOW}Ralph stopped.${colors.NC}`);
  const elapsed = getElapsedTime();
  const progress = getStoryProgress();
  console.log(`Total time: ${colors.BLUE}${elapsed}${colors.NC} | Stories completed: ${colors.GREEN}${progress}${colors.NC}`);
}

// Handle process termination
process.on('SIGINT', () => {
  cleanup();
  process.exit(0);
});

process.on('SIGTERM', () => {
  cleanup();
  process.exit(0);
});

process.on('exit', cleanup);

// ---- Sleep Prevention -----------------------------------------------

function startSleepPrevention() {
  if (!PREVENT_SLEEP) return;

  if (isMacOS()) {
    try {
      const proc = spawn('caffeinate', ['-i', '-w', process.pid.toString()], {
        detached: true,
        stdio: 'ignore'
      });
      proc.unref();
      sleepPreventionPid = proc.pid;
      console.log(`${colors.GREEN}☕ Sleep prevention enabled (caffeinate)${colors.NC}`);
    } catch {
      console.log(`${colors.YELLOW}⚠ Could not start sleep prevention${colors.NC}`);
    }
  } else if (isWindows()) {
    console.log(`${colors.YELLOW}⚠ Windows detected - disable sleep manually or run:${colors.NC}`);
    console.log('  powercfg -change -standby-timeout-ac 0');
  } else if (isLinux()) {
    if (commandExists('systemd-inhibit')) {
      try {
        const proc = spawn('systemd-inhibit', [
          '--what=idle',
          '--who=ralph',
          '--why=Running Ralph iterations',
          '--mode=block',
          'sleep', 'infinity'
        ], {
          detached: true,
          stdio: 'ignore'
        });
        proc.unref();
        sleepPreventionPid = proc.pid;
        console.log(`${colors.GREEN}☕ Sleep prevention enabled (systemd-inhibit)${colors.NC}`);
      } catch {
        console.log(`${colors.YELLOW}⚠ Could not start sleep prevention${colors.NC}`);
      }
    } else {
      console.log(`${colors.YELLOW}⚠ No sleep prevention tool found.${colors.NC}`);
    }
  }
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

  // Threshold: 3+ indicators = brownfield
  return indicators >= 3 ? 'brownfield' : 'greenfield';
}

// Auto-detect project type if not specified
if (!PROJECT_TYPE) {
  PROJECT_TYPE = detectProjectType();
  console.log(`${colors.CYAN}Auto-detected project type: ${colors.YELLOW}${PROJECT_TYPE}${colors.NC}`);
} else {
  console.log(`${colors.GREEN}Project type: ${colors.YELLOW}${PROJECT_TYPE}${colors.NC}`);
}

// ---- Auto-detect Agent ----------------------------------------------

function autoDetectAgent() {
  // Priority 1: GitHub Copilot CLI
  if (commandExists('copilot')) {
    return 'github-copilot';
  }

  // Priority 2: Claude Code
  if (getClaudeCmd()) {
    return 'claude-code';
  }

  // Priority 3: Gemini
  if (commandExists('gemini')) {
    return 'gemini';
  }

  // Priority 4: Codex
  if (commandExists('codex')) {
    return 'codex';
  }

  return null;
}

function checkAgentAvailable(agent) {
  switch (agent) {
    case 'github-copilot':
      return commandExists('copilot');
    case 'claude-code':
      return !!getClaudeCmd();
    case 'gemini':
      return commandExists('gemini');
    case 'codex':
      return commandExists('codex');
    default:
      return false;
  }
}

// ---- Agent Configuration --------------------------------------------

function getAgentConfig() {
  if (existsSync(AGENT_CONFIG)) {
    return readYaml(AGENT_CONFIG);
  }
  return {};
}

function getAgent() {
  const config = getAgentConfig();
  const configuredAgent = config?.agent?.primary;

  // If agent is configured and available, use it
  if (configuredAgent && configuredAgent !== 'null' && configuredAgent !== 'auto') {
    if (checkAgentAvailable(configuredAgent)) {
      return configuredAgent;
    }
    console.error(`${colors.YELLOW}Warning: Configured agent '${configuredAgent}' not available, auto-detecting...${colors.NC}`);
  }

  // Auto-detect agent based on priority
  const detected = autoDetectAgent();
  if (detected) {
    return detected;
  }

  // No agent found
  console.error(`${colors.RED}Error: No AI agent found.${colors.NC}`);
  console.error('Please install one of the following:');
  console.error('  - GitHub Copilot CLI: https://github.com/github/gh-copilot');
  console.error('  - Claude Code: https://docs.anthropic.com/claude/docs/cli');
  console.error('  - Gemini CLI: npm install -g @google/gemini-cli');
  console.error('  - Codex: npm install -g @openai/codex');
  return null;
}

function getFallbackAgent() {
  const config = getAgentConfig();
  return config?.agent?.fallback || '';
}

function getClaudeModel() {
  const config = getAgentConfig();
  return config?.['claude-code']?.model || 'claude-sonnet-4-20250514';
}

function getCodexModel() {
  const config = getAgentConfig();
  return config?.codex?.model || 'gpt-4o';
}

function getCodexApprovalMode() {
  const config = getAgentConfig();
  return config?.codex?.['approval-mode'] || 'full-auto';
}

function getCodexSandbox() {
  const config = getAgentConfig();
  return config?.codex?.sandbox || 'full-access';
}

function getCopilotToolApproval() {
  const config = getAgentConfig();
  return config?.['github-copilot']?.['tool-approval'] || 'allow-all';
}

function getCopilotDenyTools() {
  const config = getAgentConfig();
  return config?.['github-copilot']?.['deny-tools'] || [];
}

function getGeminiModel() {
  const config = getAgentConfig();
  return config?.gemini?.model || 'gemini-2.5-pro';
}

// ---- Run Agent ------------------------------------------------------

async function runAgent(agent) {
  const timeoutDisplay = AGENT_TIMEOUT > 0 ? `${AGENT_TIMEOUT}s` : 'no timeout';
  logInfo(`Starting agent: ${agent} (timeout: ${timeoutDisplay})`);

  let command, args;

  switch (agent) {
    case 'claude-code': {
      const model = getClaudeModel();
      console.log(`→ Running ${colors.CYAN}Claude Code${colors.NC} (model: ${model}, timeout: ${timeoutDisplay})`);

      const claudeCmd = getClaudeCmd();
      if (!claudeCmd) {
        console.log(`${colors.RED}Error: Claude CLI not found${colors.NC}`);
        return { code: 1, output: '' };
      }

      command = claudeCmd;
      args = [
        '--print',
        '--dangerously-skip-permissions',
        '--model', model,
        '--system-prompt', path.join(SCRIPT_DIR, 'system_instructions', 'system_instructions.md'),
        'Read prd.json and implement the next incomplete story. Follow the system instructions exactly.'
      ];
      break;
    }

    case 'codex': {
      const model = getCodexModel();
      const approval = getCodexApprovalMode();
      const sandbox = getCodexSandbox();
      console.log(`→ Running ${colors.CYAN}Codex${colors.NC} (model: ${model}, approval: ${approval}, sandbox: ${sandbox}, timeout: ${timeoutDisplay})`);

      command = 'codex';
      args = ['exec'];

      // Handle approval mode and sandbox
      if (approval === 'danger' || sandbox === 'full-access') {
        args.push('--dangerously-bypass-approvals-and-sandbox');
      } else if (approval === 'full-auto') {
        args.push('--full-auto');
      } else if (sandbox === 'workspace-write') {
        args.push('--sandbox', 'workspace-write');
      } else if (sandbox === 'read-only') {
        args.push('--sandbox', 'read-only');
      }

      args.push('-m', model, '--skip-git-repo-check');
      args.push('Read prd.json and implement the next incomplete story. Follow system_instructions/system_instructions_codex.md. When all stories complete, output: RALPH_COMPLETE');
      break;
    }

    case 'github-copilot': {
      const toolApproval = getCopilotToolApproval();
      console.log(`→ Running ${colors.CYAN}GitHub Copilot${colors.NC} (tool-approval: ${toolApproval}, timeout: ${timeoutDisplay})`);

      if (!commandExists('copilot')) {
        console.log(`${colors.RED}Error: Copilot CLI not found${colors.NC}`);
        return { code: 1, output: '' };
      }

      command = 'copilot';
      const prompt = 'Read prd.json and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions_copilot.md exactly. When all stories are complete, output: RALPH_COMPLETE';

      args = ['-p', prompt];

      if (toolApproval === 'allow-all') {
        args.push('--allow-all-tools');
        const denyTools = getCopilotDenyTools();
        for (const tool of denyTools) {
          if (tool) {
            args.push('--deny-tool', tool);
          }
        }
      }
      break;
    }

    case 'gemini': {
      const model = getGeminiModel();
      console.log(`→ Running ${colors.CYAN}Gemini${colors.NC} (model: ${model}, timeout: ${timeoutDisplay})`);

      if (!commandExists('gemini')) {
        console.log(`${colors.RED}Error: Gemini CLI not found${colors.NC}`);
        console.log(`${colors.YELLOW}Install: npm install -g @anthropic/gemini-cli or pip install google-generativeai${colors.NC}`);
        return { code: 1, output: '' };
      }

      command = 'gemini';
      const prompt = 'Read prd.json and implement the next incomplete story. Follow the instructions in system_instructions/system_instructions.md exactly. When all stories are complete, output: RALPH_COMPLETE';
      args = ['--model', model, '--yolo', prompt];
      break;
    }

    default:
      console.log(`${colors.RED}Unknown agent: ${agent}${colors.NC}`);
      process.exit(1);
  }

  // Run the agent
  const result = await runWithTimeout(AGENT_TIMEOUT, command, args);

  if (result.code === 124) {
    logError(`Agent timed out after ${AGENT_TIMEOUT}s`);
    console.log(`${colors.RED}Error: Agent execution timed out after ${AGENT_TIMEOUT}s${colors.NC}`);
    console.log(`${colors.YELLOW}Try increasing timeout with: --timeout <seconds> or --no-timeout${colors.NC}`);
  }

  return { code: result.code, output: result.stdout + result.stderr };
}

// ---- Archive previous run -------------------------------------------

if (existsSync(PRD_FILE) && existsSync(LAST_BRANCH_FILE)) {
  try {
    const prd = readJson(PRD_FILE);
    const currentBranch = prd.branchName || '';
    const lastBranch = readFileSync(LAST_BRANCH_FILE, 'utf8').trim();

    if (currentBranch && lastBranch && currentBranch !== lastBranch) {
      const folderName = lastBranch.replace(/^ralph\//, '').replace(/\//g, '-');
      const date = new Date().toISOString().split('T')[0];
      const archiveFolder = path.join(ARCHIVE_DIR, `${date}-${folderName}`);

      console.log(`${colors.YELLOW}Archiving previous run:${colors.NC} ${lastBranch}`);
      mkdirSync(archiveFolder, { recursive: true });

      if (existsSync(PRD_FILE)) {
        copyFileSync(PRD_FILE, path.join(archiveFolder, 'prd.json'));
      }
      if (existsSync(PROGRESS_FILE)) {
        copyFileSync(PROGRESS_FILE, path.join(archiveFolder, 'progress.txt'));
      }

      // Reset progress file
      writeFileSync(PROGRESS_FILE, `# Ralph Progress Log\nStarted: ${new Date().toISOString()}\n---\n`);
    }
  } catch {
    // Ignore archive errors
  }
}

// Save current branch
if (existsSync(PRD_FILE)) {
  try {
    const prd = readJson(PRD_FILE);
    if (prd.branchName) {
      writeFileSync(LAST_BRANCH_FILE, prd.branchName);
    }
  } catch {
    // Ignore
  }
}

// Create progress file if not exists
if (!existsSync(PROGRESS_FILE)) {
  writeFileSync(PROGRESS_FILE, `# Ralph Progress Log\nStarted: ${new Date().toISOString()}\n---\n`);
}

// ---- Validation -----------------------------------------------------

console.log('');
console.log(`${colors.CYAN}Running pre-flight checks...${colors.NC}`);
console.log('');

// Validate agent configuration
if (!validateAgentYaml(AGENT_CONFIG)) {
  console.log(`${colors.RED}Agent configuration validation failed. Exiting.${colors.NC}`);
  process.exit(1);
}

// Validate PRD if it exists
if (existsSync(PRD_FILE)) {
  if (!validatePrdJson(PRD_FILE)) {
    console.log(`${colors.RED}PRD validation failed. Exiting.${colors.NC}`);
    process.exit(1);
  }
} else {
  console.log(`${colors.YELLOW}Warning: prd.json not found at ${PRD_FILE}${colors.NC}`);
  console.log(`${colors.YELLOW}Ralph may not be able to proceed without a valid PRD${colors.NC}`);
}

// Validate git status
const gitValid = await validateGitStatus(true);
if (!gitValid) {
  console.log(`${colors.RED}Git status check failed or was cancelled. Exiting.${colors.NC}`);
  process.exit(1);
}

console.log(`${colors.GREEN}✓ Pre-flight checks complete${colors.NC}`);
console.log('');

// ---- Main loop ------------------------------------------------------

const PRIMARY_AGENT = getAgent();
if (!PRIMARY_AGENT) {
  console.log(`${colors.RED}Failed to detect or configure an agent. Exiting.${colors.NC}`);
  process.exit(1);
}
const FALLBACK_AGENT = getFallbackAgent();

console.log('');
console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`${colors.GREEN}  🐻 Starting Ralph${colors.NC}`);
console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`Project type: ${colors.YELLOW}${PROJECT_TYPE}${colors.NC}`);
console.log(`Primary agent: ${colors.CYAN}${PRIMARY_AGENT}${colors.NC}`);
if (FALLBACK_AGENT) {
  console.log(`Fallback agent: ${colors.CYAN}${FALLBACK_AGENT}${colors.NC}`);
}
console.log(`Max iterations: ${colors.YELLOW}${MAX_ITERATIONS}${colors.NC}`);
if (AGENT_TIMEOUT > 0) {
  console.log(`Agent timeout: ${colors.YELLOW}${AGENT_TIMEOUT}s${colors.NC}`);
} else {
  console.log(`Agent timeout: ${colors.YELLOW}no timeout${colors.NC}`);
}
if (VERBOSE) {
  console.log(`Verbose mode: ${colors.GREEN}enabled${colors.NC}`);
}
console.log(`Log file: ${colors.BLUE}${LOG_FILE}${colors.NC}`);
console.log(`Started at: ${colors.BLUE}${new Date().toISOString().replace('T', ' ').substring(0, 19)}${colors.NC}`);

startSleepPrevention();

for (let i = 1; i <= MAX_ITERATIONS; i++) {
  const iterationStart = Date.now();
  printStatus(i, MAX_ITERATIONS);

  let result = await runAgent(PRIMARY_AGENT);
  let output = result.output;

  if (checkRateLimit(output)) {
    printIterationSummary(i, 0, 'rate_limited');
    console.log('');
    console.log(`${colors.RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
    console.log(`${colors.RED}  ⚠ Rate limit hit - Ralph stopping${colors.NC}`);
    console.log(`${colors.RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
    console.log('');
    console.log(`Resume later with: ${colors.YELLOW}node ralph.js ${MAX_ITERATIONS - i + 1}${colors.NC}`);
    process.exit(1);
  }

  if (result.code !== 0 && FALLBACK_AGENT) {
    console.log(`${colors.YELLOW}Primary agent failed — trying ${FALLBACK_AGENT}${colors.NC}`);
    result = await runAgent(FALLBACK_AGENT);
    output = result.output;

    if (checkRateLimit(output)) {
      console.log(`${colors.RED}⚠ Rate limit on fallback${colors.NC}`);
      process.exit(1);
    }
  }

  const iterationEnd = Date.now();
  const iterationDuration = Math.floor((iterationEnd - iterationStart) / 1000);

  // Check for RALPH_COMPLETE - must be a standalone line, not part of the prompt
  const completePattern = /^RALPH_COMPLETE$|^[^:]*RALPH_COMPLETE[^"]*$/m;
  if (completePattern.test(output)) {
    // Double-check: verify all stories in PRD are marked as passing
    try {
      const prd = readJson(PRD_FILE);
      const allPass = prd.userStories.every(s => s.passes === true);

      if (allPass) {
        printIterationSummary(i, iterationDuration, 'success');
        console.log('');
        console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
        console.log(`${colors.GREEN}  🎉 Ralph completed all tasks!${colors.NC}`);
        console.log(`${colors.GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
        console.log(`Completed at iteration ${colors.YELLOW}${i}${colors.NC} | Total time: ${colors.BLUE}${getElapsedTime()}${colors.NC}`);
        process.exit(0);
      }
    } catch {
      // Continue if PRD read fails
    }
  }

  if (checkError(output)) {
    printIterationSummary(i, iterationDuration, 'error');
  } else {
    printIterationSummary(i, iterationDuration, 'success');
  }

  await sleep(2000);
}

console.log('');
console.log(`${colors.YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`${colors.YELLOW}  Ralph reached max iterations (${MAX_ITERATIONS})${colors.NC}`);
console.log(`${colors.YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`Stories: ${colors.GREEN}${getStoryProgress()}${colors.NC} | Check ${colors.BLUE}${PROGRESS_FILE}${colors.NC}`);
process.exit(1);
