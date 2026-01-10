# UI/UX Automation Testing Plan for Ralph

**Date**: 2026-01-10
**Version**: 1.0
**Status**: Planning Phase

---

## Executive Summary

This document outlines a comprehensive plan to implement UI/UX automation testing for the Ralph project using **Playwright** as the primary testing framework. The plan covers both the React flowchart visualization app and strategies for validating the bash-based CLI tools.

**Key Recommendations**:
- ✅ **Playwright** for end-to-end UI testing (interactive flowchart)
- ✅ **Vitest + Testing Library** for React component unit testing
- ✅ **BATS-core** for bash script integration testing
- ✅ **GitHub Actions CI/CD** integration for automated test execution

---

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Testing Strategy Overview](#testing-strategy-overview)
3. [Playwright Implementation Plan](#playwright-implementation-plan)
4. [Component Testing with Vitest](#component-testing-with-vitest)
5. [Bash Script Testing](#bash-script-testing)
6. [Test Coverage Areas](#test-coverage-areas)
7. [CI/CD Integration](#cicd-integration)
8. [Alternative Tools Comparison](#alternative-tools-comparison)
9. [Implementation Roadmap](#implementation-roadmap)
10. [Success Metrics](#success-metrics)

---

## Current State Analysis

### What We Have

**1. React Flowchart App** (`/flowchart`)
- Built with React 19.2, TypeScript, Vite
- Uses ReactFlow (@xyflow/react) for interactive flowchart
- Interactive features:
  - Step-by-step workflow visualization
  - Next/Previous/Reset navigation buttons
  - Draggable nodes
  - Animated edge transitions
  - 10-step workflow display
  - Context notes that appear with relevant steps

**2. Bash Orchestration Scripts**
- `ralph.sh` - Main autonomous agent loop
- `create-prd.sh` - PRD generation automation
- `ralph-models.sh` - Model management
- `setup-ralph.sh` - Installation/setup
- `lib/common.sh` - Shared utilities and validation

**3. Configuration Files**
- `prd.json` - User stories and task tracking
- `agent.yaml` - Agent configuration
- System instructions for AI agents

### Current Gaps

❌ No automated UI testing
❌ No component tests for React app
❌ No integration tests for bash scripts
❌ No CI/CD test pipeline
❌ No visual regression testing
❌ No accessibility testing

---

## Testing Strategy Overview

### Three-Layer Testing Approach

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: E2E UI Tests (Playwright)                         │
│  - Full user workflows in real browser                      │
│  - Visual regression testing                                │
│  - Accessibility checks                                     │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Component Tests (Vitest + Testing Library)        │
│  - Individual React component behavior                      │
│  - Fast unit tests                                          │
│  - Interaction testing                                      │
└─────────────────────────────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Bash Integration Tests (BATS)                     │
│  - CLI script behavior                                      │
│  - Validation logic                                         │
│  - Error handling                                           │
└─────────────────────────────────────────────────────────────┘
```

### Why Playwright?

**Advantages**:
- ✅ **Multi-browser support**: Chromium, Firefox, WebKit (Safari)
- ✅ **Auto-waiting**: Intelligent waiting for elements (reduces flakiness)
- ✅ **Network interception**: Mock API calls and test edge cases
- ✅ **Screenshots & videos**: Visual debugging and regression testing
- ✅ **Accessibility testing**: Built-in axe-core integration
- ✅ **Component testing**: Can test React components in isolation
- ✅ **Parallelization**: Fast test execution
- ✅ **TypeScript first**: Excellent type safety
- ✅ **Active development**: Microsoft-backed, regular updates

**Perfect for Ralph's Use Case**:
- Interactive flowchart requires real browser testing
- Step-through navigation needs E2E validation
- Visual elements (animations, transitions) benefit from screenshot comparison

---

## Playwright Implementation Plan

### Phase 1: Initial Setup (1-2 hours)

#### 1.1 Install Playwright

```bash
cd /home/user/NewRalph/flowchart

# Install Playwright and browsers
npm install -D @playwright/test
npx playwright install --with-deps
```

#### 1.2 Create Playwright Configuration

**File**: `flowchart/playwright.config.ts`

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',

  // Run tests in files in parallel
  fullyParallel: true,

  // Fail the build on CI if you accidentally left test.only in the source code
  forbidOnly: !!process.env.CI,

  // Retry on CI only
  retries: process.env.CI ? 2 : 0,

  // Opt out of parallel tests on CI
  workers: process.env.CI ? 1 : undefined,

  // Reporter to use
  reporter: [
    ['html'],
    ['list'],
    process.env.CI ? ['github'] : ['list']
  ],

  // Shared settings for all the projects below
  use: {
    // Base URL for app
    baseURL: 'http://localhost:5173',

    // Collect trace when retrying the failed test
    trace: 'on-first-retry',

    // Screenshot on failure
    screenshot: 'only-on-failure',

    // Video on failure
    video: 'retain-on-failure',
  },

  // Configure projects for major browsers
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    // Mobile viewports
    {
      name: 'Mobile Chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'Mobile Safari',
      use: { ...devices['iPhone 13'] },
    },
  ],

  // Run dev server before tests
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    reuseExistingServer: !process.env.CI,
    stdout: 'ignore',
    stderr: 'pipe',
  },
});
```

#### 1.3 Update package.json Scripts

```json
{
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "lint": "eslint .",
    "preview": "vite preview",
    "test": "vitest",
    "test:ui": "vitest --ui",
    "test:e2e": "playwright test",
    "test:e2e:ui": "playwright test --ui",
    "test:e2e:debug": "playwright test --debug",
    "test:e2e:headed": "playwright test --headed",
    "test:all": "npm run test && npm run test:e2e"
  }
}
```

### Phase 2: Core E2E Tests (2-4 hours)

#### 2.1 Test File Structure

```
flowchart/
├── e2e/
│   ├── flowchart-navigation.spec.ts    # Main navigation tests
│   ├── flowchart-interactions.spec.ts  # Drag, click interactions
│   ├── flowchart-visual.spec.ts        # Visual regression
│   ├── accessibility.spec.ts           # A11y tests
│   └── fixtures/
│       └── test-helpers.ts             # Shared test utilities
├── playwright.config.ts
└── playwright-report/                  # Auto-generated reports
```

#### 2.2 Example Test: Navigation Flow

**File**: `e2e/flowchart-navigation.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Ralph Flowchart Navigation', () => {

  test.beforeEach(async ({ page }) => {
    // Navigate to the app before each test
    await page.goto('/');
  });

  test('should display initial state with first step visible', async ({ page }) => {
    // Check header
    await expect(page.getByRole('heading', { name: 'How Ralph Works with Amp' }))
      .toBeVisible();

    // Check first step is visible
    await expect(page.getByText('You write a PRD')).toBeVisible();

    // Check step counter shows 1 of 10
    await expect(page.getByText('Step 1 of 10')).toBeVisible();

    // Previous button should be disabled
    await expect(page.getByRole('button', { name: 'Previous' }))
      .toBeDisabled();

    // Next button should be enabled
    await expect(page.getByRole('button', { name: 'Next' }))
      .toBeEnabled();
  });

  test('should navigate through all steps sequentially', async ({ page }) => {
    const totalSteps = 10;

    for (let step = 1; step < totalSteps; step++) {
      // Verify current step counter
      await expect(page.getByText(`Step ${step} of ${totalSteps}`))
        .toBeVisible();

      // Click Next button
      await page.getByRole('button', { name: 'Next' }).click();

      // Wait for transition
      await page.waitForTimeout(600); // Animation duration

      // Verify new step counter
      await expect(page.getByText(`Step ${step + 1} of ${totalSteps}`))
        .toBeVisible();
    }

    // At last step, Next should be disabled
    await expect(page.getByRole('button', { name: 'Next' }))
      .toBeDisabled();
  });

  test('should navigate backwards through steps', async ({ page }) => {
    // Go to step 5
    for (let i = 0; i < 4; i++) {
      await page.getByRole('button', { name: 'Next' }).click();
      await page.waitForTimeout(100);
    }

    await expect(page.getByText('Step 5 of 10')).toBeVisible();

    // Go back to step 3
    await page.getByRole('button', { name: 'Previous' }).click();
    await page.waitForTimeout(600);
    await expect(page.getByText('Step 4 of 10')).toBeVisible();

    await page.getByRole('button', { name: 'Previous' }).click();
    await page.waitForTimeout(600);
    await expect(page.getByText('Step 3 of 10')).toBeVisible();
  });

  test('should reset to initial state when reset button clicked', async ({ page }) => {
    // Navigate to step 7
    for (let i = 0; i < 6; i++) {
      await page.getByRole('button', { name: 'Next' }).click();
      await page.waitForTimeout(100);
    }

    await expect(page.getByText('Step 7 of 10')).toBeVisible();

    // Click Reset
    await page.getByRole('button', { name: 'Reset' }).click();
    await page.waitForTimeout(600);

    // Should be back to step 1
    await expect(page.getByText('Step 1 of 10')).toBeVisible();
    await expect(page.getByText('You write a PRD')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Previous' }))
      .toBeDisabled();
  });

  test('should show correct step descriptions', async ({ page }) => {
    const expectedSteps = [
      { title: 'You write a PRD', desc: 'Define what you want to build' },
      { title: 'Convert to prd.json', desc: 'Break into small user stories' },
      { title: 'Run ralph.sh', desc: 'Starts the autonomous loop' },
      { title: 'Amp picks a story', desc: 'Finds next passes: false' },
      { title: 'Implements it', desc: 'Writes code, runs tests' },
    ];

    for (let i = 0; i < expectedSteps.length; i++) {
      const step = expectedSteps[i];
      await expect(page.getByText(step.title)).toBeVisible();
      await expect(page.getByText(step.desc)).toBeVisible();

      if (i < expectedSteps.length - 1) {
        await page.getByRole('button', { name: 'Next' }).click();
        await page.waitForTimeout(600);
      }
    }
  });
});
```

#### 2.3 Example Test: Visual Interactions

**File**: `e2e/flowchart-interactions.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Flowchart Interactions', () => {

  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('should show note when reaching step 2', async ({ page }) => {
    // Note appears with step 2
    await page.getByRole('button', { name: 'Next' }).click();
    await page.waitForTimeout(600);

    // Check for PRD JSON note
    await expect(page.getByText('"id": "US-001"')).toBeVisible();
    await expect(page.getByText('"passes": false')).toBeVisible();
  });

  test('should show AGENTS.md note when reaching step 8', async ({ page }) => {
    // Navigate to step 8
    for (let i = 0; i < 7; i++) {
      await page.getByRole('button', { name: 'Next' }).click();
      await page.waitForTimeout(100);
    }

    await expect(page.getByText('Also updates AGENTS.md')).toBeVisible();
  });

  test('should allow panning the flowchart', async ({ page }) => {
    const flowContainer = page.locator('.react-flow');

    // Get initial viewport
    const box = await flowContainer.boundingBox();
    expect(box).toBeTruthy();

    // Pan by dragging
    await flowContainer.hover({ position: { x: box!.width / 2, y: box!.height / 2 } });
    await page.mouse.down();
    await page.mouse.move(box!.x + 100, box!.y + 100);
    await page.mouse.up();

    // Flowchart should still be visible
    await expect(flowContainer).toBeVisible();
  });

  test('should allow zooming with controls', async ({ page }) => {
    // Find zoom controls
    const zoomInButton = page.locator('.react-flow__controls-button').first();

    // Zoom in
    await zoomInButton.click();
    await page.waitForTimeout(200);

    // Flowchart should still be visible and interactive
    await expect(page.getByText('You write a PRD')).toBeVisible();
  });

  test('should support keyboard navigation', async ({ page }) => {
    const nextButton = page.getByRole('button', { name: 'Next' });

    // Focus next button
    await nextButton.focus();

    // Press Enter to activate
    await page.keyboard.press('Enter');
    await page.waitForTimeout(600);

    // Should advance to step 2
    await expect(page.getByText('Step 2 of 10')).toBeVisible();
  });
});
```

#### 2.4 Example Test: Visual Regression

**File**: `e2e/flowchart-visual.spec.ts`

```typescript
import { test, expect } from '@playwright/test';

test.describe('Visual Regression Tests', () => {

  test('should match initial page layout', async ({ page }) => {
    await page.goto('/');

    // Wait for flowchart to render
    await page.waitForSelector('.react-flow');
    await page.waitForTimeout(1000); // Wait for animations

    // Take screenshot
    await expect(page).toHaveScreenshot('initial-state.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('should match step 5 layout', async ({ page }) => {
    await page.goto('/');

    // Navigate to step 5
    for (let i = 0; i < 4; i++) {
      await page.getByRole('button', { name: 'Next' }).click();
      await page.waitForTimeout(100);
    }

    await page.waitForTimeout(1000);

    await expect(page).toHaveScreenshot('step-5-state.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('should match complete flowchart', async ({ page }) => {
    await page.goto('/');

    // Navigate to last step
    for (let i = 0; i < 9; i++) {
      await page.getByRole('button', { name: 'Next' }).click();
      await page.waitForTimeout(100);
    }

    await page.waitForTimeout(1000);

    await expect(page).toHaveScreenshot('complete-flowchart.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });

  test('should render correctly on mobile viewport', async ({ page }) => {
    // Set mobile viewport
    await page.setViewportSize({ width: 375, height: 667 });
    await page.goto('/');

    await page.waitForTimeout(1000);

    await expect(page).toHaveScreenshot('mobile-initial.png', {
      fullPage: true,
      animations: 'disabled',
    });
  });
});
```

#### 2.5 Example Test: Accessibility

**File**: `e2e/accessibility.spec.ts`

```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility Tests', () => {

  test('should not have any automatically detectable accessibility issues', async ({ page }) => {
    await page.goto('/');

    const accessibilityScanResults = await new AxeBuilder({ page }).analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });

  test('should have proper heading hierarchy', async ({ page }) => {
    await page.goto('/');

    // Check for h1
    const h1 = page.getByRole('heading', { level: 1 });
    await expect(h1).toHaveText('How Ralph Works with Amp');
  });

  test('should have accessible button labels', async ({ page }) => {
    await page.goto('/');

    // All buttons should have accessible names
    await expect(page.getByRole('button', { name: 'Next' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Previous' })).toBeVisible();
    await expect(page.getByRole('button', { name: 'Reset' })).toBeVisible();
  });

  test('should support keyboard-only navigation', async ({ page }) => {
    await page.goto('/');

    // Tab to first button (Previous - disabled)
    await page.keyboard.press('Tab');

    // Tab to Next button
    await page.keyboard.press('Tab');
    await page.keyboard.press('Tab');

    const nextButton = page.getByRole('button', { name: 'Next' });
    await expect(nextButton).toBeFocused();

    // Activate with keyboard
    await page.keyboard.press('Enter');
    await page.waitForTimeout(600);

    await expect(page.getByText('Step 2 of 10')).toBeVisible();
  });

  test('should have sufficient color contrast', async ({ page }) => {
    await page.goto('/');

    // Run axe with specific rules
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();

    expect(accessibilityScanResults.violations).toEqual([]);
  });
});
```

### Phase 3: Component Testing (2-3 hours)

While Playwright can test the full app, component tests are faster for unit-level validation.

#### 3.1 Install Vitest & Testing Library

```bash
npm install -D vitest @testing-library/react @testing-library/jest-dom \
  @testing-library/user-event jsdom @vitejs/plugin-react
```

#### 3.2 Configure Vitest

**File**: `flowchart/vite.config.ts` (update)

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    globals: true,
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'src/test/',
      ],
    },
  },
});
```

#### 3.3 Test Setup File

**File**: `flowchart/src/test/setup.ts`

```typescript
import { expect, afterEach } from 'vitest';
import { cleanup } from '@testing-library/react';
import '@testing-library/jest-dom/vitest';

// Cleanup after each test
afterEach(() => {
  cleanup();
});
```

#### 3.4 Example Component Test

**File**: `flowchart/src/App.test.tsx`

```typescript
import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import App from './App';

describe('App', () => {
  it('renders main heading', () => {
    render(<App />);
    expect(screen.getByText('How Ralph Works with Amp')).toBeInTheDocument();
  });

  it('starts at step 1', () => {
    render(<App />);
    expect(screen.getByText('Step 1 of 10')).toBeInTheDocument();
  });

  it('disables Previous button at first step', () => {
    render(<App />);
    const prevButton = screen.getByRole('button', { name: /previous/i });
    expect(prevButton).toBeDisabled();
  });

  it('advances to next step when Next is clicked', async () => {
    const user = userEvent.setup();
    render(<App />);

    const nextButton = screen.getByRole('button', { name: /next/i });
    await user.click(nextButton);

    await waitFor(() => {
      expect(screen.getByText('Step 2 of 10')).toBeInTheDocument();
    });
  });

  it('resets to step 1 when Reset is clicked', async () => {
    const user = userEvent.setup();
    render(<App />);

    // Go to step 3
    const nextButton = screen.getByRole('button', { name: /next/i });
    await user.click(nextButton);
    await user.click(nextButton);

    await waitFor(() => {
      expect(screen.getByText('Step 3 of 10')).toBeInTheDocument();
    });

    // Reset
    const resetButton = screen.getByRole('button', { name: /reset/i });
    await user.click(resetButton);

    await waitFor(() => {
      expect(screen.getByText('Step 1 of 10')).toBeInTheDocument();
    });
  });
});
```

---

## Bash Script Testing

### BATS-core for Bash Testing

**BATS** (Bash Automated Testing System) is the standard for testing bash scripts.

#### Installation

```bash
# Install BATS
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

#### Test Structure

```
NewRalph/
├── tests/
│   ├── ralph.bats              # Tests for ralph.sh
│   ├── validation.bats         # Tests for lib/common.sh validation
│   ├── setup.bats              # Tests for setup-ralph.sh
│   └── helpers/
│       └── test_helper.bash    # Shared test utilities
```

#### Example: Validation Tests

**File**: `tests/validation.bats`

```bash
#!/usr/bin/env bats

# Load common library
load '../lib/common'

setup() {
  # Create temporary test directory
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR"
}

teardown() {
  # Cleanup
  rm -rf "$TEST_DIR"
}

@test "validate_json_file detects invalid JSON" {
  echo '{"invalid": json}' > test.json

  run validate_json_file test.json
  [ "$status" -eq 1 ]
}

@test "validate_json_file accepts valid JSON" {
  echo '{"valid": "json"}' > test.json

  run validate_json_file test.json
  [ "$status" -eq 0 ]
}

@test "validate_prd_json detects missing branchName" {
  cat > prd.json <<EOF
{
  "project": "Test",
  "userStories": []
}
EOF

  run validate_prd_json prd.json
  [ "$status" -eq 1 ]
  [[ "$output" =~ "branchName" ]]
}

@test "validate_prd_json accepts valid PRD" {
  cat > prd.json <<EOF
{
  "project": "Test",
  "branchName": "test-branch",
  "userStories": [
    {
      "id": "US-001",
      "title": "Test story",
      "description": "Test",
      "acceptanceCriteria": ["Test"],
      "priority": 1,
      "passes": false
    }
  ]
}
EOF

  run validate_prd_json prd.json
  [ "$status" -eq 0 ]
}

@test "validate_agent_yaml detects missing primary agent" {
  cat > agent.yaml <<EOF
claude-code:
  model: test-model
EOF

  run validate_agent_yaml agent.yaml
  [ "$status" -eq 1 ]
}

@test "validate_agent_yaml accepts valid config" {
  cat > agent.yaml <<EOF
agent:
  primary: claude-code
claude-code:
  model: test-model
EOF

  run validate_agent_yaml agent.yaml
  [ "$status" -eq 0 ]
}
```

---

## Test Coverage Areas

### Critical User Journeys

#### 1. **Flowchart Visualization**
- ✅ Initial render with step 1 visible
- ✅ Step-by-step navigation (1 → 10)
- ✅ Backward navigation
- ✅ Reset functionality
- ✅ Button state management (enabled/disabled)
- ✅ Step counter accuracy
- ✅ Note appearance timing

#### 2. **Interactive Features**
- ✅ Node dragging
- ✅ Pan/zoom controls
- ✅ Edge animations
- ✅ Responsive layout (mobile/desktop)
- ✅ Keyboard navigation

#### 3. **Visual Elements**
- ✅ Color coding by phase (setup, loop, decision, done)
- ✅ Fade-in/fade-out transitions
- ✅ Background grid rendering
- ✅ Edge arrow markers
- ✅ Note box styling

#### 4. **Accessibility**
- ✅ Screen reader compatibility
- ✅ Keyboard-only navigation
- ✅ Color contrast ratios
- ✅ ARIA labels
- ✅ Focus indicators

#### 5. **Bash Script Validation**
- ✅ PRD JSON structure validation
- ✅ Agent YAML validation
- ✅ Git status checks
- ✅ Timeout handling
- ✅ Error message clarity

---

## CI/CD Integration

### GitHub Actions Workflow

**File**: `.github/workflows/test.yml`

```yaml
name: UI Automation Tests

on:
  push:
    branches: [ main, claude/* ]
  pull_request:
    branches: [ main ]

jobs:
  test-flowchart:
    runs-on: ubuntu-latest
    timeout-minutes: 10

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: flowchart/package-lock.json

      - name: Install dependencies
        working-directory: ./flowchart
        run: npm ci

      - name: Run Vitest unit tests
        working-directory: ./flowchart
        run: npm run test -- --coverage

      - name: Install Playwright Browsers
        working-directory: ./flowchart
        run: npx playwright install --with-deps

      - name: Run Playwright E2E tests
        working-directory: ./flowchart
        run: npm run test:e2e

      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: playwright-report
          path: flowchart/playwright-report/
          retention-days: 30

      - name: Upload coverage
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: flowchart/coverage/
          retention-days: 30

  test-bash-scripts:
    runs-on: ubuntu-latest
    timeout-minutes: 5

    steps:
      - uses: actions/checkout@v4

      - name: Install BATS
        run: |
          git clone https://github.com/bats-core/bats-core.git
          cd bats-core
          sudo ./install.sh /usr/local

      - name: Install dependencies (jq, yq)
        run: |
          sudo apt-get update
          sudo apt-get install -y jq
          sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq
          sudo chmod +x /usr/bin/yq

      - name: Run BATS tests
        run: bats tests/

      - name: Upload BATS results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: bats-report
          path: tests/*.tap
          retention-days: 30
```

---

## Alternative Tools Comparison

### E2E Testing Options

| Tool | Pros | Cons | Verdict |
|------|------|------|---------|
| **Playwright** | Multi-browser, fast, TypeScript-first, auto-wait, screenshots | Learning curve | ✅ **Recommended** |
| **Cypress** | Great DX, time-travel debugging, visual testing | Only Chromium-based browsers, slower | ⚠️ Alternative |
| **Selenium** | Industry standard, multi-language | Slow, flaky, complex setup | ❌ Not recommended |
| **Puppeteer** | Lightweight, Chrome DevTools Protocol | Chrome-only | ⚠️ Limited scope |

### Component Testing Options

| Tool | Pros | Cons | Verdict |
|------|------|------|---------|
| **Vitest + Testing Library** | Fast, Vite integration, modern | Newer tool | ✅ **Recommended** |
| **Jest + Testing Library** | Mature, widespread | Slower, config complexity | ⚠️ Alternative |
| **Playwright Component Testing** | Same tool for E2E + components | Newer feature | ⚠️ Experimental |

### Bash Testing Options

| Tool | Pros | Cons | Verdict |
|------|------|------|---------|
| **BATS** | Purpose-built, TAP output, simple | Bash-only | ✅ **Recommended** |
| **shUnit2** | xUnit-style | Less maintained | ⚠️ Alternative |
| **Manual scripts** | No dependencies | Hard to maintain | ❌ Not scalable |

---

## Implementation Roadmap

### Week 1: Foundation (8-10 hours)

**Day 1-2: Playwright Setup**
- [ ] Install Playwright in flowchart directory
- [ ] Create playwright.config.ts
- [ ] Set up test directory structure
- [ ] Write first navigation test
- [ ] Verify test runs locally

**Day 3-4: Core E2E Tests**
- [ ] Write navigation test suite (5-7 tests)
- [ ] Write interaction test suite (4-6 tests)
- [ ] Write visual regression tests (3-4 tests)
- [ ] Write accessibility tests (3-5 tests)

**Day 5: Component Tests**
- [ ] Install Vitest and Testing Library
- [ ] Configure Vitest in vite.config.ts
- [ ] Write App component tests (5-7 tests)
- [ ] Write CustomNode component tests (3-5 tests)

### Week 2: Bash Testing & CI (6-8 hours)

**Day 1-2: BATS Setup**
- [ ] Install BATS locally
- [ ] Create test directory structure
- [ ] Write validation function tests
- [ ] Write ralph.sh integration tests

**Day 3-4: CI/CD Integration**
- [ ] Create GitHub Actions workflow
- [ ] Configure test running in CI
- [ ] Set up artifact uploads
- [ ] Add status badges to README

**Day 5: Documentation**
- [ ] Document test commands in README
- [ ] Create testing guide
- [ ] Add troubleshooting section
- [ ] Update ENHANCEMENTS.md

### Week 3: Polish & Maintenance (4-6 hours)

- [ ] Review test coverage gaps
- [ ] Add missing edge case tests
- [ ] Optimize test performance
- [ ] Set up visual regression baselines
- [ ] Create test maintenance guide

---

## Success Metrics

### Coverage Targets

- **E2E Tests**: 90%+ of user workflows covered
- **Component Tests**: 80%+ statement coverage
- **Bash Tests**: 100% of validation functions tested
- **Accessibility**: 0 critical violations

### Quality Metrics

- **Flakiness Rate**: < 1% (tests should be reliable)
- **Execution Time**:
  - Vitest unit tests: < 10 seconds
  - Playwright E2E: < 2 minutes (all browsers)
  - BATS tests: < 30 seconds
- **CI Success Rate**: > 95%

### Maintenance Metrics

- **Test Update Frequency**: Tests updated with every feature change
- **Documentation**: All test commands documented
- **Developer Adoption**: Team runs tests locally before commits

---

## Next Steps

### Immediate Actions (This Week)

1. **Install Playwright** in flowchart directory
2. **Write 3-5 critical E2E tests** (navigation, interactions)
3. **Set up CI workflow** for automated test runs

### Short-term (Next 2 Weeks)

4. **Add component tests** with Vitest
5. **Implement BATS tests** for bash scripts
6. **Enable visual regression testing**

### Long-term (Next Month)

7. **Expand accessibility testing**
8. **Add performance benchmarks**
9. **Create testing documentation**
10. **Train team on test writing**

---

## Resources & References

### Official Documentation

- **Playwright**: https://playwright.dev/
- **Vitest**: https://vitest.dev/
- **Testing Library**: https://testing-library.com/
- **BATS**: https://bats-core.readthedocs.io/
- **Axe Accessibility**: https://www.deque.com/axe/

### Tutorials

- Playwright with React: https://playwright.dev/docs/test-components
- Testing Library Best Practices: https://kentcdodds.com/blog/common-mistakes-with-react-testing-library
- BATS Tutorial: https://github.com/bats-core/bats-core#writing-tests

### Example Projects

- Playwright React Demo: https://github.com/microsoft/playwright/tree/main/examples/react
- Vitest React Template: https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts

---

## Appendix: Complete File Checklist

### Files to Create

```
flowchart/
├── playwright.config.ts                     # Playwright config
├── e2e/
│   ├── flowchart-navigation.spec.ts         # Navigation tests
│   ├── flowchart-interactions.spec.ts       # Interaction tests
│   ├── flowchart-visual.spec.ts             # Visual regression
│   ├── accessibility.spec.ts                # A11y tests
│   └── fixtures/
│       └── test-helpers.ts                  # Shared utilities
├── src/
│   ├── App.test.tsx                         # Component tests
│   └── test/
│       └── setup.ts                         # Vitest setup
└── vite.config.ts                           # Updated with test config

NewRalph/
├── tests/
│   ├── ralph.bats                           # Ralph script tests
│   ├── validation.bats                      # Validation tests
│   ├── setup.bats                           # Setup script tests
│   └── helpers/
│       └── test_helper.bash                 # BATS helpers
└── .github/
    └── workflows/
        └── test.yml                         # CI workflow
```

### Files to Update

```
flowchart/package.json                       # Add test scripts
NewRalph/README.md                           # Document testing
NewRalph/ENHANCEMENTS.md                     # Add testing section
```

---

## Summary

This comprehensive plan provides a roadmap for implementing world-class UI/UX automation testing for Ralph using:

1. **Playwright** for E2E browser testing
2. **Vitest + Testing Library** for React component tests
3. **BATS** for bash script validation
4. **GitHub Actions** for CI/CD automation

**Estimated Total Effort**: 18-24 hours spread over 2-3 weeks

**Key Benefits**:
- 🎯 Catch UI regressions before deployment
- 🚀 Faster development with confident refactoring
- 📊 Automated quality checks in CI/CD
- ♿ Improved accessibility compliance
- 📱 Multi-browser and mobile testing
- 🛡️ Bash script validation safety net

**Ready to proceed?** Start with Phase 1 (Playwright setup) and build incrementally from there.
