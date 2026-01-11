#!/usr/bin/env node
/**
 * Install Ralph setup script globally
 * Cross-platform Node.js implementation
 *
 * Usage: node install.js
 */

import { existsSync, writeFileSync, chmodSync, accessSync, constants } from 'fs';
import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

import { isWindows, colors } from './lib/common.js';

// ---- Script Directory ------------------------------------------------

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const RALPH_DIR = __dirname;

// ---- Configuration --------------------------------------------------

let INSTALL_DIR;
let SCRIPT_NAME = 'ralph-setup';
let USE_SUDO = false;

if (isWindows()) {
  // On Windows, use npm global bin or a common location
  try {
    INSTALL_DIR = execSync('npm config get prefix', { encoding: 'utf8' }).trim();
    INSTALL_DIR = path.join(INSTALL_DIR, 'bin');
  } catch {
    INSTALL_DIR = path.join(process.env.APPDATA || '', 'npm');
  }
} else {
  INSTALL_DIR = '/usr/local/bin';
}

// Check if we have write permissions
try {
  accessSync(INSTALL_DIR, constants.W_OK);
} catch {
  if (!isWindows()) {
    console.log('Installing Ralph globally requires sudo access...');
    try {
      execSync('sudo -v', { stdio: 'inherit' });
      USE_SUDO = true;
    } catch {
      console.log(`${colors.RED}Error: Could not obtain sudo access${colors.NC}`);
      process.exit(1);
    }
  } else {
    console.log(`${colors.YELLOW}Warning: May not have write access to ${INSTALL_DIR}${colors.NC}`);
    console.log('You may need to run this as Administrator.');
  }
}

// Create a wrapper script that knows where Ralph lives
console.log('Creating global ralph-setup command...');

const scriptPath = path.join(INSTALL_DIR, SCRIPT_NAME);

if (isWindows()) {
  // On Windows, create a batch file and a Node.js wrapper
  const batchContent = `@echo off
node "${path.join(RALPH_DIR, 'setup-ralph.js')}" %*
`;

  const batchPath = scriptPath + '.cmd';
  try {
    writeFileSync(batchPath, batchContent);
    console.log(`Created: ${batchPath}`);
  } catch (err) {
    console.log(`${colors.RED}Error writing batch file: ${err.message}${colors.NC}`);
    process.exit(1);
  }

  // Also create a shell script for Git Bash / WSL
  const shContent = `#!/bin/sh
node "${path.join(RALPH_DIR, 'setup-ralph.js').replace(/\\/g, '/')}" "$@"
`;

  try {
    writeFileSync(scriptPath, shContent);
    console.log(`Created: ${scriptPath}`);
  } catch (err) {
    // Non-fatal on Windows
    console.log(`${colors.YELLOW}Note: Could not create shell script (Git Bash)${colors.NC}`);
  }

} else {
  // On Unix-like systems, create a shell script
  const wrapperContent = `#!/bin/bash
# Ralph global setup wrapper
RALPH_SOURCE="${RALPH_DIR}"
exec node "\$RALPH_SOURCE/setup-ralph.js" "$@"
`;

  if (USE_SUDO) {
    try {
      // Write to temp file first, then sudo move
      const tempPath = `/tmp/ralph-setup-${Date.now()}`;
      writeFileSync(tempPath, wrapperContent);
      execSync(`sudo mv "${tempPath}" "${scriptPath}"`, { stdio: 'inherit' });
      execSync(`sudo chmod +x "${scriptPath}"`, { stdio: 'inherit' });
    } catch (err) {
      console.log(`${colors.RED}Error installing with sudo: ${err.message}${colors.NC}`);
      process.exit(1);
    }
  } else {
    try {
      writeFileSync(scriptPath, wrapperContent);
      chmodSync(scriptPath, 0o755);
    } catch (err) {
      console.log(`${colors.RED}Error writing script: ${err.message}${colors.NC}`);
      process.exit(1);
    }
  }
}

console.log('');
console.log('✓ Ralph installed globally!');
console.log('');
console.log('You can now run from anywhere:');
console.log(`  ${SCRIPT_NAME} /path/to/your/project`);
console.log('');
if (isWindows()) {
  console.log('To uninstall:');
  console.log(`  del "${scriptPath}.cmd"`);
} else {
  console.log('To uninstall:');
  console.log(`  ${USE_SUDO ? 'sudo ' : ''}rm ${scriptPath}`);
}
console.log('');

// Also provide npm link instructions
console.log('Alternative: You can also use npm link for a cleaner installation:');
console.log(`  cd ${RALPH_DIR}`);
console.log('  npm link');
console.log('');
console.log('This will make these commands available globally:');
console.log('  ralph, ralph-setup, ralph-models, create-prd');
console.log('');
