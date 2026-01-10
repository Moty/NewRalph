# GitHub Copilot Agent Integration - Testing Guide

This document outlines how to test the GitHub Copilot CLI integration with Ralph.

## Prerequisites

1. Install GitHub Copilot CLI:
   ```bash
   npm install -g @github/copilot
   ```

2. Authenticate with GitHub:
   ```bash
   copilot
   # Use /login in the interactive session
   ```

3. Verify installation:
   ```bash
   copilot --version
   ```

## Configuration Tests

### Test 1: YAML Validation

Verify that agent.yaml accepts github-copilot as a valid agent:

```bash
# Test validation with github-copilot as primary
cat > /tmp/test-copilot.yaml << 'EOF'
agent:
  primary: github-copilot
  fallback: claude-code

github-copilot:
  tool-approval: allow-all
  deny-tools:
    - "shell (rm)"
    - "fetch"
EOF

# Run validation
source lib/common.sh
validate_agent_yaml /tmp/test-copilot.yaml
```

Expected output: `✓ Agent configuration valid (primary: github-copilot)`

### Test 2: Helper Functions

Test that Ralph can read GitHub Copilot configuration:

```bash
export AGENT_CONFIG=/tmp/test-copilot.yaml

# Define helper functions
get_copilot_tool_approval() { yq '.github-copilot.tool-approval // "allow-all"' "$AGENT_CONFIG"; }
get_copilot_deny_tools() { yq '.github-copilot.deny-tools[]? // ""' "$AGENT_CONFIG"; }

# Test
echo "Tool approval: $(get_copilot_tool_approval)"
echo "Deny tools: $(get_copilot_deny_tools)"
```

Expected output:
```
Tool approval: allow-all
Deny tools: shell (rm)
fetch
```

### Test 3: Command Construction

Verify the copilot CLI command is constructed correctly:

```bash
TOOL_APPROVAL="allow-all"
TOOL_FLAGS="--allow-all-tools"

# Add deny tools
DENY_TOOLS=$(get_copilot_deny_tools)
while IFS= read -r tool; do
  [ -n "$tool" ] && TOOL_FLAGS="$TOOL_FLAGS --deny-tool '$tool'"
done <<< "$DENY_TOOLS"

echo "Command flags: $TOOL_FLAGS"
```

Expected output:
```
Command flags: --allow-all-tools --deny-tool 'shell (rm)' --deny-tool 'fetch'
```

## Integration Tests

### Test 4: Setup Script Detection

Run the setup script to verify Copilot CLI is detected:

```bash
./setup-ralph.sh /tmp/ralph-test
```

Expected output should include:
```
✓ GitHub Copilot CLI found
```

And during agent configuration, GitHub Copilot should appear as an option.

### Test 5: System Instructions

Verify the system instructions file exists and is valid:

```bash
ls -la system_instructions/system_instructions_copilot.md
head -20 system_instructions/system_instructions_copilot.md
```

Expected: File exists and contains instructions for GitHub Copilot CLI.

## Manual Execution Test

### Test 6: Single Agent Run (Simulated)

To test without actually running Ralph's full loop, you can simulate a single iteration:

```bash
# Create a minimal prd.json for testing
cat > /tmp/test-prd.json << 'EOF'
{
  "project": "TestProject",
  "branchName": "ralph/test-feature",
  "description": "Test project for GitHub Copilot integration",
  "userStories": [
    {
      "id": "US-001",
      "title": "Create README",
      "description": "Add a README.md file to the project",
      "acceptanceCriteria": ["README.md exists", "Contains project description"],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
EOF

# Test the copilot command (with --help to avoid actual execution)
copilot --help
```

### Test 7: Validation in Ralph Context

Test that Ralph's validation accepts the configuration:

```bash
# Copy the test config to agent.yaml
cp /tmp/test-copilot.yaml agent.yaml

# Source ralph.sh functions (without running the loop)
export AGENT_CONFIG=agent.yaml
source lib/common.sh

# Run validation
validate_agent_yaml "$AGENT_CONFIG"
```

## Full Integration Test

### Test 8: Run Ralph with GitHub Copilot

**Important**: Only run this if you have:
1. GitHub Copilot CLI installed and authenticated
2. A valid prd.json with small, testable stories
3. A git repository initialized

```bash
# Configure GitHub Copilot as primary
yq -i '.agent.primary = "github-copilot"' agent.yaml
yq -i 'del(.agent.fallback)' agent.yaml

# Run Ralph for 1 iteration
./ralph.sh 1 --verbose

# Check the logs
cat ralph.log
```

Expected: Ralph should invoke the GitHub Copilot CLI with proper flags.

## Troubleshooting

### Issue: Copilot CLI not found

**Solution**: Ensure GitHub Copilot CLI is installed and in PATH:
```bash
which copilot
npm install -g @github/copilot
```

### Issue: Authentication required

**Solution**: Run copilot interactively and login:
```bash
copilot
# Then use /login command
```

### Issue: Tool approval prompts

**Solution**: Ensure `tool-approval: allow-all` is set in agent.yaml:
```yaml
github-copilot:
  tool-approval: allow-all
```

### Issue: Unknown agent error

**Solution**: Verify lib/common.sh includes github-copilot in validation:
```bash
grep "github-copilot" lib/common.sh
```

Should show github-copilot in the case statement for agent validation.

## Success Criteria

The integration is successful if:

1. ✅ `validate_agent_yaml` accepts github-copilot as valid agent
2. ✅ `get_copilot_tool_approval()` returns configured value
3. ✅ `get_copilot_deny_tools()` returns deny list correctly
4. ✅ Setup script detects GitHub Copilot CLI when installed
5. ✅ System instructions file exists for Copilot
6. ✅ Ralph can run with github-copilot as primary agent
7. ✅ Fallback works if Copilot CLI is not available

## Security Notes

When using GitHub Copilot CLI in automated mode:

1. **Tool Permissions**: The `allow-all-tools` flag grants broad permissions. Use `deny-tools` to restrict dangerous operations.

2. **Recommended Deny List**:
   ```yaml
   deny-tools:
     - "shell (rm)"      # Prevent file deletion
     - "fetch"           # Prevent network requests
   ```

3. **Review Mode**: For sensitive projects, set `tool-approval: selective` to review each tool usage (not recommended for Ralph automation).

## Next Steps

After validating the integration:

1. Document any discovered issues in AGENTS.md
2. Update prd.json with real project stories
3. Run Ralph with GitHub Copilot on a test branch
4. Compare results with Claude Code and Codex
5. Optimize tool-approval settings based on project needs
