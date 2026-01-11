#!/usr/bin/env node
/**
 * ralph-models.js - List available models for each agent
 * Cross-platform Node.js implementation
 *
 * Usage: node ralph-models.js [agent-name] [--refresh]
 *
 * Options:
 *   --refresh, -r    Force refresh of available models from CLIs
 */

import { existsSync, readFileSync } from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

import {
  colors,
  commandExists,
  getClaudeCmd,
  readYaml
} from './lib/common.js';

import {
  refreshModels,
  getClaudeModels,
  getCodexModels,
  getGeminiModels,
  getCacheInfo,
  getCacheFilePath
} from './lib/model-refresh.js';

// ---- Script Directory ------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SCRIPT_DIR = __dirname;
const AGENT_CONFIG = path.join(SCRIPT_DIR, 'agent.yaml');

// ---- Helper Functions -----------------------------------------------

function getAgentConfig() {
  if (existsSync(AGENT_CONFIG)) {
    return readYaml(AGENT_CONFIG);
  }
  return {};
}

// ---- Show Models Functions ------------------------------------------

function showClaudeModels() {
  const config = getAgentConfig();
  const currentModel = config?.['claude-code']?.model || 'claude-sonnet-4-20250514';

  console.log(`${colors.BLUE}Claude Code${colors.NC} (via claude CLI)`);
  console.log(`  ${colors.YELLOW}Current:${colors.NC} ${currentModel}`);
  console.log('');

  console.log(`  ${colors.GREEN}Available models (auto-detected):${colors.NC}`);

  const models = getClaudeModels({ baseDir: SCRIPT_DIR });

  if (models && models.length > 0) {
    for (const model of models) {
      // Annotate recommended models
      if (model.includes('claude-sonnet-4') || model.includes('claude-sonnet-4-5')) {
        console.log(`    • ${model} ${colors.CYAN}(recommended, fast)${colors.NC}`);
      } else if (model.includes('claude-opus-4')) {
        console.log(`    • ${model} ${colors.CYAN}(powerful, slower)${colors.NC}`);
      } else {
        console.log(`    • ${model}`);
      }
    }
  } else {
    console.log(`    ${colors.YELLOW}No models detected, showing defaults:${colors.NC}`);
    console.log('    • claude-sonnet-4-20250514 (recommended, fast)');
    console.log('    • claude-opus-4-20250514   (powerful, slower)');
    console.log('    • claude-3-5-sonnet-20241022');
    console.log('    • claude-3-5-haiku-20241022');
  }
  console.log('');

  const claudeCmd = getClaudeCmd();
  if (claudeCmd) {
    try {
      const version = execSync(`"${claudeCmd}" --version 2>/dev/null`, { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} ${version}`);
    } catch {
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} unknown version`);
    }
  } else {
    console.log(`  ${colors.RED}CLI not found${colors.NC} - install from https://claude.ai/download`);
  }
  console.log('');
}

function showCodexModels() {
  const config = getAgentConfig();
  const currentModel = config?.codex?.model || 'gpt-5.2-codex';

  console.log(`${colors.BLUE}Codex${colors.NC} (via codex CLI)`);
  console.log(`  ${colors.YELLOW}Current:${colors.NC} ${currentModel}`);
  console.log('');

  console.log(`  ${colors.GREEN}Available models (auto-detected):${colors.NC}`);

  const models = getCodexModels({ baseDir: SCRIPT_DIR });

  if (models && models.length > 0) {
    for (const model of models) {
      // Annotate recommended models
      switch (model) {
        case 'gpt-5.2-codex':
          console.log(`    • ${model} ${colors.CYAN}(latest frontier agentic coding)${colors.NC}`);
          break;
        case 'gpt-5.1-codex-max':
          console.log(`    • ${model} ${colors.CYAN}(flagship deep reasoning)${colors.NC}`);
          break;
        case 'gpt-5.1-codex-mini':
          console.log(`    • ${model} ${colors.CYAN}(faster, cheaper)${colors.NC}`);
          break;
        case 'gpt-5.2':
          console.log(`    • ${model} ${colors.CYAN}(frontier with reasoning/coding)${colors.NC}`);
          break;
        default:
          if (model.startsWith('o3') || model.startsWith('o4')) {
            console.log(`    • ${model} ${colors.CYAN}(reasoning model)${colors.NC}`);
          } else {
            console.log(`    • ${model}`);
          }
      }
    }
  } else {
    console.log(`    ${colors.YELLOW}No models detected, showing defaults:${colors.NC}`);
    console.log('    • gpt-5.2-codex      (latest frontier agentic coding)');
    console.log('    • gpt-5.1-codex-max  (flagship deep reasoning)');
    console.log('    • gpt-5.1-codex-mini (faster, cheaper)');
    console.log('    • gpt-5.2            (frontier with reasoning/coding)');
    console.log('    • gpt-4o             (legacy, still available)');
  }
  console.log('');

  if (commandExists('codex')) {
    try {
      const version = execSync('codex --version 2>/dev/null', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} ${version}`);
    } catch {
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} unknown version`);
    }
    console.log(`  ${colors.CYAN}Tip:${colors.NC} Run 'codex' then /model to see all available models`);
  } else {
    console.log(`  ${colors.RED}CLI not found${colors.NC} - install with 'npm install -g @openai/codex'`);
  }
  console.log('');
}

function showGeminiModels() {
  const config = getAgentConfig();
  const currentModel = config?.gemini?.model || 'gemini-3-pro';

  console.log(`${colors.BLUE}Gemini${colors.NC} (via gemini CLI)`);
  console.log(`  ${colors.YELLOW}Current:${colors.NC} ${currentModel}`);
  console.log('');

  console.log(`  ${colors.GREEN}Available models (auto-detected):${colors.NC}`);

  const models = getGeminiModels({ baseDir: SCRIPT_DIR });

  if (models && models.length > 0) {
    for (const model of models) {
      // Annotate recommended models
      switch (model) {
        case 'gemini-3-pro':
          console.log(`    • ${model} ${colors.CYAN}(Gemini 3, powerful)${colors.NC}`);
          break;
        case 'gemini-3-flash':
          console.log(`    • ${model} ${colors.CYAN}(Gemini 3, fast)${colors.NC}`);
          break;
        case 'gemini-2.5-pro':
          console.log(`    • ${model} ${colors.CYAN}(Gemini 2.5, powerful)${colors.NC}`);
          break;
        case 'gemini-2.5-flash':
          console.log(`    • ${model} ${colors.CYAN}(Gemini 2.5, fast)${colors.NC}`);
          break;
        default:
          console.log(`    • ${model}`);
      }
    }
  } else {
    console.log(`    ${colors.YELLOW}No models detected, showing defaults:${colors.NC}`);
    console.log('    • gemini-3-pro       (Gemini 3, powerful)');
    console.log('    • gemini-3-flash     (Gemini 3, fast)');
    console.log('    • gemini-2.5-pro     (Gemini 2.5, powerful)');
    console.log('    • gemini-2.5-flash   (Gemini 2.5, fast)');
  }
  console.log('');

  if (commandExists('gemini')) {
    try {
      const version = execSync('gemini --version 2>/dev/null', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim();
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} ${version}`);
    } catch {
      console.log(`  ${colors.GREEN}CLI found:${colors.NC} unknown version`);
    }
    console.log(`  ${colors.CYAN}Tip:${colors.NC} Run 'gemini' then /model to see all available models`);
  } else {
    console.log(`  ${colors.RED}CLI not found${colors.NC} - install with 'npm install -g @anthropic/gemini-cli'`);
  }
  console.log('');
}

function showCurrentConfig() {
  console.log(`${colors.YELLOW}Current Configuration${colors.NC} (${AGENT_CONFIG})`);
  console.log('');

  if (existsSync(AGENT_CONFIG)) {
    const content = readFileSync(AGENT_CONFIG, 'utf8');
    const lines = content.split('\n').map(line => `  ${line}`).join('\n');
    console.log(lines);
  } else {
    console.log(`  ${colors.RED}No agent.yaml found${colors.NC}`);
  }
  console.log('');
}

// ---- Parse arguments ------------------------------------------------

let FORCE_REFRESH = false;
let SHOW_MODE = 'all';

const args = process.argv.slice(2);

for (const arg of args) {
  switch (arg) {
    case '--refresh':
    case '-r':
      FORCE_REFRESH = true;
      break;
    case '--help':
    case '-h':
      console.log('Usage: node ralph-models.js [agent-name] [--refresh]');
      console.log('');
      console.log('Agent names:');
      console.log('  all          Show all agents (default)');
      console.log('  claude       Show Claude Code models only');
      console.log('  codex        Show Codex models only');
      console.log('  gemini       Show Gemini models only');
      console.log('  config       Show current configuration');
      console.log('');
      console.log('Options:');
      console.log('  --refresh, -r    Force refresh of available models');
      console.log('  --help, -h       Show this help message');
      process.exit(0);
    case 'claude':
    case 'claude-code':
    case 'codex':
    case 'openai':
    case 'gemini':
    case 'config':
      SHOW_MODE = arg;
      break;
  }
}

// ---- Main -----------------------------------------------------------

console.log('');
console.log(`${colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`${colors.CYAN}  Ralph Available Models${colors.NC}`);
console.log(`${colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log('');

// Force refresh if requested
if (FORCE_REFRESH) {
  console.log(`${colors.YELLOW}Forcing model refresh...${colors.NC}`);
  refreshModels({ force: true, baseDir: SCRIPT_DIR, silent: true });
  console.log(`${colors.GREEN}✓ Models refreshed${colors.NC}`);
  console.log('');
}

// Show cache info
const cacheFile = getCacheFilePath(SCRIPT_DIR);
if (existsSync(cacheFile)) {
  const cacheInfo = getCacheInfo(SCRIPT_DIR);
  console.log(`${colors.CYAN}${cacheInfo}${colors.NC}`);
  console.log('');
}

// Show models based on mode
switch (SHOW_MODE) {
  case 'claude':
  case 'claude-code':
    showClaudeModels();
    break;
  case 'codex':
  case 'openai':
    showCodexModels();
    break;
  case 'gemini':
    showGeminiModels();
    break;
  case 'config':
    showCurrentConfig();
    break;
  case 'all':
  default:
    showClaudeModels();
    console.log(`${colors.CYAN}───────────────────────────────────────────────────────────${colors.NC}`);
    console.log('');
    showCodexModels();
    console.log(`${colors.CYAN}───────────────────────────────────────────────────────────${colors.NC}`);
    console.log('');
    showGeminiModels();
    console.log(`${colors.CYAN}───────────────────────────────────────────────────────────${colors.NC}`);
    console.log('');
    showCurrentConfig();
    break;
}

console.log(`${colors.CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${colors.NC}`);
console.log(`To change model: edit ${colors.BLUE}agent.yaml${colors.NC} and update the model field`);
console.log(`To refresh models: run ${colors.BLUE}node ralph-models.js --refresh${colors.NC}`);
console.log('');
