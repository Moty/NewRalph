/**
 * Ralph Common Library - Shared functions for validation, logging, and utilities
 * Cross-platform Node.js implementation
 */

import { existsSync, readFileSync, writeFileSync, appendFileSync } from 'fs';
import { execSync, spawn } from 'child_process';
import { createInterface } from 'readline';
import path from 'path';
import YAML from 'yaml';

// ---- Colors -------------------------------------------------------
// ANSI color codes - works on most terminals (including Windows 10+)
const supportsColor = process.stdout.isTTY &&
  (process.env.FORCE_COLOR ||
   process.platform !== 'win32' ||
   process.env.TERM === 'xterm-256color' ||
   parseInt(process.env.COLORTERM || '0', 10) > 0);

export const colors = {
  RED: supportsColor ? '\x1b[0;31m' : '',
  GREEN: supportsColor ? '\x1b[0;32m' : '',
  YELLOW: supportsColor ? '\x1b[1;33m' : '',
  BLUE: supportsColor ? '\x1b[0;34m' : '',
  CYAN: supportsColor ? '\x1b[0;36m' : '',
  NC: supportsColor ? '\x1b[0m' : ''  // No Color
};

// ---- Logging Functions --------------------------------------------

let LOG_FILE = process.env.LOG_FILE || path.join(process.cwd(), 'ralph.log');
let VERBOSE = process.env.VERBOSE === 'true';

export function setLogFile(filePath) {
  LOG_FILE = filePath;
}

export function setVerbose(verbose) {
  VERBOSE = verbose;
}

export function isVerbose() {
  return VERBOSE;
}

function getTimestamp() {
  return new Date().toISOString().replace('T', ' ').substring(0, 19);
}

function writeToLog(level, message) {
  try {
    appendFileSync(LOG_FILE, `[${getTimestamp()}] [${level}] ${message}\n`);
  } catch (err) {
    // Silently ignore log write failures
  }
}

export function logDebug(message) {
  if (VERBOSE) {
    console.error(`${colors.BLUE}[DEBUG]${colors.NC} ${message}`);
  }
  writeToLog('DEBUG', message);
}

export function logInfo(message) {
  console.error(`${colors.GREEN}[INFO]${colors.NC} ${message}`);
  writeToLog('INFO', message);
}

export function logWarn(message) {
  console.error(`${colors.YELLOW}[WARN]${colors.NC} ${message}`);
  writeToLog('WARN', message);
}

export function logError(message) {
  console.error(`${colors.RED}[ERROR]${colors.NC} ${message}`);
  writeToLog('ERROR', message);
}

// ---- Dependency Checking ------------------------------------------

/**
 * Check if a binary exists in PATH
 */
export function commandExists(command) {
  try {
    const cmd = process.platform === 'win32' ? 'where' : 'which';
    execSync(`${cmd} ${command}`, { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Require a binary to exist, exit if not found
 */
export function requireBin(bin) {
  if (!commandExists(bin)) {
    logError(`Missing required binary: ${bin}`);
    console.error(`${colors.RED}Missing required binary: ${bin}${colors.NC}`);
    console.error(`${colors.YELLOW}Install it and try again.${colors.NC}`);
    process.exit(1);
  }
}

/**
 * Get the path to Claude CLI
 */
export function getClaudeCmd() {
  if (commandExists('claude')) {
    return 'claude';
  }
  const localPath = path.join(process.env.HOME || process.env.USERPROFILE || '', '.local', 'bin', 'claude');
  if (existsSync(localPath)) {
    return localPath;
  }
  return null;
}

// ---- JSON Validation ----------------------------------------------

/**
 * Validate a JSON file exists and contains valid JSON
 */
export function validateJsonFile(file, fileType) {
  if (!existsSync(file)) {
    logError(`${fileType} not found: ${file}`);
    console.error(`${colors.RED}Error: ${fileType} not found: ${file}${colors.NC}`);
    return false;
  }

  logDebug(`Validating JSON file: ${file}`);

  try {
    const content = readFileSync(file, 'utf8');
    JSON.parse(content);
    logDebug(`JSON syntax valid: ${file}`);
    return true;
  } catch (err) {
    logError(`${fileType} contains invalid JSON: ${file}`);
    console.error(`${colors.RED}Error: ${fileType} contains invalid JSON${colors.NC}`);
    console.error(`${colors.YELLOW}Error: ${err.message}${colors.NC}`);
    return false;
  }
}

/**
 * Validate PRD JSON structure
 */
export function validatePrdJson(prdFile) {
  logInfo(`Validating PRD structure: ${prdFile}`);

  // First check basic JSON validity
  if (!validateJsonFile(prdFile, 'prd.json')) {
    return false;
  }

  let prd;
  try {
    prd = JSON.parse(readFileSync(prdFile, 'utf8'));
  } catch (err) {
    return false;
  }

  // Check required top-level fields
  const requiredFields = ['project', 'branchName', 'userStories'];
  for (const field of requiredFields) {
    if (!(field in prd)) {
      logError(`PRD missing required field: ${field}`);
      console.error(`${colors.RED}Error: prd.json missing required field: ${field}${colors.NC}`);
      return false;
    }
  }

  // Validate userStories is an array
  if (!Array.isArray(prd.userStories)) {
    logError("PRD field 'userStories' must be an array");
    console.error(`${colors.RED}Error: userStories must be an array${colors.NC}`);
    return false;
  }

  // Check if userStories is empty
  if (prd.userStories.length === 0) {
    logWarn('PRD has no user stories');
    console.error(`${colors.YELLOW}Warning: prd.json has no user stories${colors.NC}`);
    return false;
  }

  // Validate each user story has required fields
  const storyRequiredFields = ['id', 'title', 'description', 'acceptanceCriteria', 'priority', 'passes'];
  let hasInvalid = false;

  for (let i = 0; i < prd.userStories.length; i++) {
    const story = prd.userStories[i];
    for (const field of storyRequiredFields) {
      if (!(field in story)) {
        logError(`User story at index ${i} missing field: ${field}`);
        console.error(`${colors.RED}Error: User story at index ${i} missing field: ${field}${colors.NC}`);
        hasInvalid = true;
      }
    }
  }

  if (hasInvalid) {
    return false;
  }

  logInfo(`PRD validation successful: ${prd.userStories.length} user stories found`);
  console.error(`${colors.GREEN}✓ PRD validation passed${colors.NC} (${prd.userStories.length} stories)`);
  return true;
}

// ---- YAML Validation ----------------------------------------------

/**
 * Validate a YAML file exists and contains valid YAML
 */
export function validateYamlFile(file, fileType) {
  if (!existsSync(file)) {
    logError(`${fileType} not found: ${file}`);
    console.error(`${colors.RED}Error: ${fileType} not found: ${file}${colors.NC}`);
    return false;
  }

  logDebug(`Validating YAML file: ${file}`);

  try {
    const content = readFileSync(file, 'utf8');
    YAML.parse(content);
    logDebug(`YAML syntax valid: ${file}`);
    return true;
  } catch (err) {
    logError(`${fileType} contains invalid YAML: ${file}`);
    console.error(`${colors.RED}Error: ${fileType} contains invalid YAML${colors.NC}`);
    console.error(`${colors.YELLOW}Error: ${err.message}${colors.NC}`);
    return false;
  }
}

/**
 * Validate agent YAML configuration
 */
export function validateAgentYaml(agentFile) {
  logInfo(`Validating agent configuration: ${agentFile}`);

  // First check basic YAML validity
  if (!validateYamlFile(agentFile, 'agent.yaml')) {
    return false;
  }

  let config;
  try {
    config = YAML.parse(readFileSync(agentFile, 'utf8'));
  } catch (err) {
    return false;
  }

  // Check required fields
  if (!config?.agent?.primary) {
    logError('agent.yaml missing required field: agent.primary');
    console.error(`${colors.RED}Error: agent.yaml missing required field: agent.primary${colors.NC}`);
    return false;
  }

  const primaryAgent = config.agent.primary;
  const validAgents = ['claude-code', 'codex', 'github-copilot', 'gemini'];

  // Validate primary agent is a known type
  if (!validAgents.includes(primaryAgent)) {
    logError(`Unknown primary agent: ${primaryAgent}`);
    console.error(`${colors.RED}Error: Unknown primary agent: ${primaryAgent}${colors.NC}`);
    console.error(`${colors.YELLOW}Valid options: ${validAgents.join(', ')}${colors.NC}`);
    return false;
  }

  logDebug(`Primary agent is valid: ${primaryAgent}`);

  // Validate fallback agent if present
  const fallbackAgent = config.agent.fallback;
  if (fallbackAgent) {
    if (!validAgents.includes(fallbackAgent)) {
      logError(`Unknown fallback agent: ${fallbackAgent}`);
      console.error(`${colors.RED}Error: Unknown fallback agent: ${fallbackAgent}${colors.NC}`);
      console.error(`${colors.YELLOW}Valid options: ${validAgents.join(', ')}${colors.NC}`);
      return false;
    }
    logDebug(`Fallback agent is valid: ${fallbackAgent}`);
  }

  logInfo('Agent configuration validation successful');
  console.error(`${colors.GREEN}✓ Agent configuration valid${colors.NC} (primary: ${primaryAgent})`);
  return true;
}

// ---- Git Validation -----------------------------------------------

/**
 * Check if current directory is a git repository
 */
export function isGitRepo() {
  try {
    execSync('git rev-parse --git-dir', { stdio: 'ignore' });
    return true;
  } catch {
    return false;
  }
}

/**
 * Get current git branch
 */
export function getCurrentBranch() {
  try {
    return execSync('git rev-parse --abbrev-ref HEAD', { encoding: 'utf8' }).trim();
  } catch {
    return null;
  }
}

/**
 * Check if there are uncommitted changes
 */
export function hasUncommittedChanges() {
  try {
    execSync('git diff-index --quiet HEAD --', { stdio: 'ignore' });
    return false;
  } catch {
    return true;
  }
}

/**
 * Validate git status
 */
export async function validateGitStatus(allowUncommitted = false) {
  logInfo('Checking git repository status');

  // Check if we're in a git repository
  if (!isGitRepo()) {
    logError('Not in a git repository');
    console.error(`${colors.RED}Error: Not in a git repository${colors.NC}`);
    console.error(`${colors.YELLOW}Initialize git with: git init${colors.NC}`);
    return false;
  }

  // Check if there are uncommitted changes
  if (hasUncommittedChanges()) {
    if (!allowUncommitted) {
      logWarn('Git repository has uncommitted changes');
      console.error(`${colors.YELLOW}Warning: You have uncommitted changes${colors.NC}`);
      console.error(`${colors.YELLOW}Ralph will commit automatically, but you may want to commit or stash first.${colors.NC}`);
      console.error('');

      try {
        const status = execSync('git status --short', { encoding: 'utf8' });
        console.error(status);
      } catch {}

      const answer = await confirm('Continue anyway?');
      if (!answer) {
        logInfo('User cancelled due to uncommitted changes');
        return false;
      }
    } else {
      logDebug('Uncommitted changes present (allowed)');
    }
  } else {
    logDebug('Git working directory is clean');
  }

  // Check if we're on a branch
  const currentBranch = getCurrentBranch();
  if (currentBranch === 'HEAD') {
    logError('Currently in detached HEAD state');
    console.error(`${colors.RED}Error: Git is in detached HEAD state${colors.NC}`);
    console.error(`${colors.YELLOW}Checkout a branch first${colors.NC}`);
    return false;
  }

  logInfo(`Git status check passed (branch: ${currentBranch})`);
  return true;
}

// ---- Process Utilities --------------------------------------------

/**
 * Run a command with timeout
 * @param {number} timeout - Timeout in seconds
 * @param {string} command - Command to run
 * @param {string[]} args - Command arguments
 * @returns {Promise<{code: number, stdout: string, stderr: string}>}
 */
export function runWithTimeout(timeout, command, args = []) {
  return new Promise((resolve, reject) => {
    logDebug(`Running command with timeout ${timeout}s: ${command} ${args.join(' ')}`);

    let stdout = '';
    let stderr = '';
    let timedOut = false;

    const proc = spawn(command, args, {
      stdio: ['inherit', 'pipe', 'pipe'],
      shell: process.platform === 'win32'
    });

    proc.stdout?.on('data', (data) => {
      const str = data.toString();
      stdout += str;
      process.stdout.write(str);
    });

    proc.stderr?.on('data', (data) => {
      const str = data.toString();
      stderr += str;
      process.stderr.write(str);
    });

    const timer = timeout > 0 ? setTimeout(() => {
      timedOut = true;
      logError(`Command timed out after ${timeout}s, killing process`);
      proc.kill('SIGTERM');
      setTimeout(() => {
        if (!proc.killed) {
          proc.kill('SIGKILL');
        }
      }, 2000);
    }, timeout * 1000) : null;

    proc.on('close', (code) => {
      if (timer) clearTimeout(timer);
      resolve({
        code: timedOut ? 124 : (code || 0),
        stdout,
        stderr
      });
    });

    proc.on('error', (err) => {
      if (timer) clearTimeout(timer);
      reject(err);
    });
  });
}

/**
 * Execute a command synchronously and return output
 */
export function execCommand(command, options = {}) {
  try {
    return execSync(command, {
      encoding: 'utf8',
      stdio: options.silent ? 'pipe' : 'inherit',
      ...options
    });
  } catch (err) {
    if (options.ignoreError) {
      return err.stdout || '';
    }
    throw err;
  }
}

// ---- Utility Functions --------------------------------------------

/**
 * Format duration in human-readable format
 */
export function formatDuration(seconds) {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  } else if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  } else {
    return `${secs}s`;
  }
}

/**
 * Prompt user for confirmation
 */
export function confirm(prompt, defaultValue = false) {
  return new Promise((resolve) => {
    const rl = createInterface({
      input: process.stdin,
      output: process.stdout
    });

    const suffix = defaultValue ? ' [Y/n] ' : ' [y/N] ';
    rl.question(prompt + suffix, (answer) => {
      rl.close();
      const normalized = answer.toLowerCase().trim();
      if (normalized === '') {
        resolve(defaultValue);
      } else {
        resolve(normalized === 'y' || normalized === 'yes');
      }
    });
  });
}

/**
 * Read a line from user input
 */
export function readLine(prompt) {
  return new Promise((resolve) => {
    const rl = createInterface({
      input: process.stdin,
      output: process.stdout
    });

    rl.question(prompt, (answer) => {
      rl.close();
      resolve(answer);
    });
  });
}

/**
 * Read and parse YAML file
 */
export function readYaml(filePath) {
  const content = readFileSync(filePath, 'utf8');
  return YAML.parse(content);
}

/**
 * Write YAML file
 */
export function writeYaml(filePath, data) {
  writeFileSync(filePath, YAML.stringify(data));
}

/**
 * Read and parse JSON file
 */
export function readJson(filePath) {
  const content = readFileSync(filePath, 'utf8');
  return JSON.parse(content);
}

/**
 * Write JSON file
 */
export function writeJson(filePath, data) {
  writeFileSync(filePath, JSON.stringify(data, null, 2));
}

/**
 * Sleep for a given number of milliseconds
 */
export function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Get the script directory (equivalent to SCRIPT_DIR in bash)
 */
export function getScriptDir(importMetaUrl) {
  const __filename = new URL(importMetaUrl).pathname;
  // Handle Windows paths
  const filename = process.platform === 'win32'
    ? __filename.substring(1) // Remove leading /
    : __filename;
  return path.dirname(filename);
}

// ---- Platform Utilities -------------------------------------------

/**
 * Get the current platform
 */
export function getPlatform() {
  const platform = process.platform;
  if (platform === 'darwin') return 'macos';
  if (platform === 'win32') return 'windows';
  return 'linux';
}

/**
 * Check if running on Windows
 */
export function isWindows() {
  return process.platform === 'win32';
}

/**
 * Check if running on macOS
 */
export function isMacOS() {
  return process.platform === 'darwin';
}

/**
 * Check if running on Linux
 */
export function isLinux() {
  return process.platform === 'linux';
}

// ---- Initialization -----------------------------------------------

// Ensure log file exists
try {
  if (!existsSync(LOG_FILE)) {
    writeFileSync(LOG_FILE, '');
  }
} catch {
  // Silently ignore
}

logDebug('Common library loaded');
