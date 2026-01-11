/**
 * model-refresh.js - Dynamically detect and cache available models
 * Cross-platform Node.js implementation
 */

import { existsSync, readFileSync, writeFileSync } from 'fs';
import path from 'path';
import { commandExists, getClaudeCmd } from './common.js';

// Cache file location (relative to project root)
const CACHE_MAX_AGE_HOURS = 24;

// Default fallback models (used if detection fails)
const DEFAULT_CLAUDE_MODELS = [
  'claude-sonnet-4-20250514',
  'claude-opus-4-20250514',
  'claude-sonnet-4-5-20250929',
  'claude-3-5-sonnet-20241022',
  'claude-3-5-haiku-20241022'
];

const DEFAULT_CODEX_MODELS = [
  'gpt-5.2-codex',
  'gpt-5.1-codex-max',
  'gpt-5.1-codex-mini',
  'gpt-5.2',
  'gpt-4o',
  'o4-mini'
];

const DEFAULT_GEMINI_MODELS = [
  'gemini-3-pro',
  'gemini-3-flash',
  'gemini-2.5-pro',
  'gemini-2.5-flash'
];

/**
 * Get the cache file path
 */
export function getCacheFilePath(baseDir = process.cwd()) {
  return path.join(baseDir, '.ralph-models-cache.json');
}

/**
 * Detect available Claude models
 */
export function detectClaudeModels() {
  // For now, we use curated default lists
  // Future enhancement: Add API integration to fetch live model lists

  const claudeCmd = getClaudeCmd();

  if (!claudeCmd) {
    // CLI not installed, return minimal set
    return ['claude-sonnet-4-20250514'];
  }

  // CLI is installed, return full curated list
  return DEFAULT_CLAUDE_MODELS;
}

/**
 * Detect available Codex/OpenAI models
 */
export function detectCodexModels() {
  // For now, we use curated default lists
  // Future enhancement: Add OpenAI API integration to fetch live model lists

  if (!commandExists('codex')) {
    // CLI not installed, return minimal set
    return ['gpt-4o'];
  }

  // CLI is installed, return full curated list
  return DEFAULT_CODEX_MODELS;
}

/**
 * Detect available Gemini models
 */
export function detectGeminiModels() {
  // Gemini CLI models: Auto (Gemini 3) and Auto (Gemini 2.5)

  if (!commandExists('gemini')) {
    // CLI not installed, return minimal set
    return ['gemini-3-pro'];
  }

  // CLI is installed, return full curated list
  return DEFAULT_GEMINI_MODELS;
}

/**
 * Check if cache is valid and not expired
 */
export function isCacheValid(cacheFile) {
  if (!existsSync(cacheFile)) {
    return false;
  }

  try {
    const cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
    const timestamp = cache.timestamp || 0;

    if (timestamp === 0) {
      return false;
    }

    const currentTimestamp = Math.floor(Date.now() / 1000);
    const ageSeconds = currentTimestamp - timestamp;
    const maxAgeSeconds = CACHE_MAX_AGE_HOURS * 3600;

    return ageSeconds < maxAgeSeconds;
  } catch {
    return false;
  }
}

/**
 * Get cached models
 */
export function getCachedModels(cacheFile) {
  if (existsSync(cacheFile)) {
    try {
      return JSON.parse(readFileSync(cacheFile, 'utf8'));
    } catch {
      return {};
    }
  }
  return {};
}

/**
 * Refresh models and update cache
 */
export function refreshModels(options = {}) {
  const { force = false, baseDir = process.cwd(), silent = false } = options;
  const cacheFile = getCacheFilePath(baseDir);

  // Check if we need to refresh
  if (!force && isCacheValid(cacheFile)) {
    // Cache is valid, return cached data
    return getCachedModels(cacheFile);
  }

  // Perform refresh
  if (!silent) {
    console.error('Refreshing available models...');
  }

  const claudeModels = detectClaudeModels();
  const codexModels = detectCodexModels();
  const geminiModels = detectGeminiModels();

  const currentTimestamp = Math.floor(Date.now() / 1000);
  const refreshedDate = new Date().toISOString().replace('T', ' ').substring(0, 19) + ' UTC';

  const cacheData = {
    timestamp: currentTimestamp,
    refreshed: refreshedDate,
    claude: claudeModels,
    codex: codexModels,
    gemini: geminiModels
  };

  // Write cache
  try {
    writeFileSync(cacheFile, JSON.stringify(cacheData, null, 2));
  } catch (err) {
    if (!silent) {
      console.error(`Warning: Could not write cache file: ${err.message}`);
    }
  }

  if (!silent) {
    console.error('Models refreshed and cached.');
  }

  return cacheData;
}

/**
 * Get models (from cache or refresh)
 */
export function getModels(options = {}) {
  const { force = false, baseDir = process.cwd() } = options;
  const cacheFile = getCacheFilePath(baseDir);

  if (force) {
    return refreshModels({ force: true, baseDir });
  } else if (!isCacheValid(cacheFile)) {
    return refreshModels({ baseDir });
  } else {
    return getCachedModels(cacheFile);
  }
}

/**
 * Get Claude models only
 */
export function getClaudeModels(options = {}) {
  const models = getModels(options);
  return models.claude || DEFAULT_CLAUDE_MODELS;
}

/**
 * Get Codex models only
 */
export function getCodexModels(options = {}) {
  const models = getModels(options);
  return models.codex || DEFAULT_CODEX_MODELS;
}

/**
 * Get Gemini models only
 */
export function getGeminiModels(options = {}) {
  const models = getModels(options);
  return models.gemini || DEFAULT_GEMINI_MODELS;
}

/**
 * Get cache info
 */
export function getCacheInfo(baseDir = process.cwd()) {
  const cacheFile = getCacheFilePath(baseDir);

  if (existsSync(cacheFile)) {
    try {
      const cache = JSON.parse(readFileSync(cacheFile, 'utf8'));
      return `Last refreshed: ${cache.refreshed || 'never'}`;
    } catch {
      return 'Cache file corrupted. Run refresh to regenerate.';
    }
  }

  return "Cache not found. Run 'refresh_models' to detect models.";
}

// CLI interface (if script is executed directly)
const isMainModule = import.meta.url === `file://${process.argv[1]}`;
if (isMainModule) {
  const args = process.argv.slice(2);
  const command = args[0] || 'get';

  switch (command) {
    case 'refresh':
    case '--refresh':
    case '-r':
      refreshModels({ force: true });
      break;
    case 'claude':
      console.log(getClaudeModels().join('\n'));
      break;
    case 'codex':
      console.log(getCodexModels().join('\n'));
      break;
    case 'gemini':
      console.log(getGeminiModels().join('\n'));
      break;
    case 'info':
      console.log(getCacheInfo());
      break;
    case 'get':
    default:
      console.log(JSON.stringify(getModels(), null, 2));
      break;
  }
}
