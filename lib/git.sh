#!/bin/bash
# Ralph Git Library - Git operations for branch management, merging, pushing, and PRs
# Source this file from ralph.sh: source "$SCRIPT_DIR/lib/git.sh"

# ---- Git Configuration Getters -----------------------------------

# Get git.auto-checkout-branch setting (default: true)
get_git_auto_checkout_branch() {
  local value=$(yq '.git.auto-checkout-branch // true' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.base-branch setting (default: main)
get_git_base_branch() {
  yq '.git.base-branch // "main"' "$AGENT_CONFIG" 2>/dev/null
}

# Get git.push.enabled setting (default: false)
get_git_push_enabled() {
  local value=$(yq '.git.push.enabled // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.push.timing setting (default: iteration)
get_git_push_timing() {
  yq '.git.push.timing // "iteration"' "$AGENT_CONFIG" 2>/dev/null
}

# Get git.pr.enabled setting (default: false)
get_git_pr_enabled() {
  local value=$(yq '.git.pr.enabled // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# Get git.pr.draft setting (default: false)
get_git_pr_draft() {
  local value=$(yq '.git.pr.draft // false' "$AGENT_CONFIG" 2>/dev/null)
  [ "$value" = "true" ]
}

# ---- Branch Management Functions ---------------------------------

# Ensure the feature branch exists and we're on it
# Usage: ensure_feature_branch <branch_name>
# Creates from base-branch if it doesn't exist
# Returns 0 on success, 1 on failure
ensure_feature_branch() {
  local branch_name="$1"
  local base_branch=$(get_git_base_branch)

  if [ -z "$branch_name" ]; then
    log_error "No branch name provided to ensure_feature_branch"
    return 1
  fi

  log_info "Ensuring feature branch: $branch_name"

  # Stash any uncommitted changes to allow branch switching
  local stash_needed=false
  if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    log_info "Stashing uncommitted changes before branch switch"
    if git stash push -m "Ralph auto-stash before switching to $branch_name"; then
      stash_needed=true
    else
      log_error "Failed to stash changes, attempting checkout anyway"
    fi
  fi

  local checkout_success=false

  # Check if branch exists locally
  if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    log_debug "Branch $branch_name exists locally"
    if git checkout "$branch_name" 2>/dev/null; then
      checkout_success=true
    fi
  # Check if branch exists on remote
  elif git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
    log_debug "Branch $branch_name exists on remote, checking out"
    git fetch origin "$branch_name"
    if git checkout -b "$branch_name" "origin/$branch_name" 2>/dev/null; then
      checkout_success=true
    fi
  else
    # Create new branch from base
    log_info "Creating new branch $branch_name from $base_branch"

    # Make sure we have the latest base branch
    if git ls-remote --exit-code --heads origin "$base_branch" >/dev/null 2>&1; then
      git fetch origin "$base_branch"
      if git checkout -b "$branch_name" "origin/$base_branch" 2>/dev/null; then
        checkout_success=true
      fi
    else
      # No remote, create from local base or current HEAD
      if git show-ref --verify --quiet "refs/heads/$base_branch" 2>/dev/null; then
        if git checkout -b "$branch_name" "$base_branch" 2>/dev/null; then
          checkout_success=true
        fi
      else
        if git checkout -b "$branch_name" 2>/dev/null; then
          checkout_success=true
        fi
      fi
    fi
  fi

  # Restore stashed changes if we stashed them
  if [ "$stash_needed" = true ]; then
    log_info "Restoring stashed changes"
    git stash pop 2>/dev/null || log_warn "Could not restore stashed changes"
  fi

  # Verify we're on the correct branch
  local current_branch=$(git branch --show-current 2>/dev/null)
  if [ "$current_branch" = "$branch_name" ]; then
    log_info "Now on branch: $current_branch"
    return 0
  else
    log_error "Failed to switch to branch $branch_name (currently on: $current_branch)"
    echo -e "${RED}✗ Failed to switch to feature branch ${branch_name}${NC}"
    echo -e "${YELLOW}  Current branch: ${current_branch}${NC}"
    echo -e "${YELLOW}  Try: git stash && git checkout $branch_name${NC}"
    return 1
  fi
}

# Get the sub-branch name for a story
# Usage: get_story_branch_name <feature_branch> <story_id>
get_story_branch_name() {
  local feature_branch="$1"
  local story_id="$2"
  echo "${feature_branch}/${story_id}"
}

# Check if a story sub-branch exists
# Usage: story_branch_exists <branch_name>
story_branch_exists() {
  local branch_name="$1"
  git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null
}

# Find a story sub-branch even if agent used wrong naming
# Usage: found_branch=$(find_story_branch <feature_branch> <story_id>)
# Returns: The actual branch name if found, empty if not
find_story_branch() {
  local feature_branch="$1"
  local story_id="$2"

  # First, check the expected name
  local expected_branch="${feature_branch}/${story_id}"
  if story_branch_exists "$expected_branch"; then
    echo "$expected_branch"
    return 0
  fi

  # Search for branches ending with the story ID
  # This catches cases like: ralph/wrong-name/US-003, wrong-prefix/US-003, etc.
  local found_branch
  found_branch=$(git branch --list "*/${story_id}" 2>/dev/null | sed 's/^[* ]*//' | head -1)

  if [ -n "$found_branch" ]; then
    echo "$found_branch"
    return 0
  fi

  # Also try with hyphen separator (e.g., feature-branch-US-003)
  found_branch=$(git branch --list "*-${story_id}" 2>/dev/null | sed 's/^[* ]*//' | head -1)

  if [ -n "$found_branch" ]; then
    echo "$found_branch"
    return 0
  fi

  return 1
}

# Validate and report branch naming issues
# Usage: validate_story_branch <feature_branch> <story_id>
# Returns: 0 if valid branch found, 1 if no branch, 2 if misnamed branch found
validate_story_branch() {
  local feature_branch="$1"
  local story_id="$2"

  local expected_branch="${feature_branch}/${story_id}"
  local found_branch

  # Check expected name first
  if story_branch_exists "$expected_branch"; then
    return 0
  fi

  # Try to find misnamed branch
  found_branch=$(find_story_branch "$feature_branch" "$story_id")

  if [ -n "$found_branch" ]; then
    log_warn "Branch naming mismatch for $story_id"
    log_warn "  Expected: $expected_branch"
    log_warn "  Found:    $found_branch"
    echo -e "${YELLOW}⚠ Branch naming mismatch for ${story_id}${NC}"
    echo -e "  Expected: ${CYAN}$expected_branch${NC}"
    echo -e "  Found:    ${CYAN}$found_branch${NC}"
    return 2
  fi

  return 1
}

# ---- PRD State Functions -----------------------------------------

# Get story passes status from a branch's prd.json
# Usage: status=$(get_story_passes_from_branch <branch_name> <story_id>)
# Returns: "true" or "false" (or empty if not found)
get_story_passes_from_branch() {
  local branch="$1"
  local story_id="$2"
  local prd_file="${PRD_FILE:-prd.json}"

  # Get prd.json content from specified branch without switching
  git show "$branch:$prd_file" 2>/dev/null | \
    jq -r --arg id "$story_id" \
      '.userStories[] | select(.id == $id) | .passes // false'
}

# Preserve story completion status after merge conflict
# Usage: preserve_story_completion <story_id>
# Updates prd.json on current branch to mark story as complete
preserve_story_completion() {
  local story_id="$1"
  local prd_file="${PRD_FILE:-prd.json}"

  if [ ! -f "$prd_file" ]; then
    log_error "PRD file not found: $prd_file"
    return 1
  fi

  # Update prd.json on current branch to mark story as complete
  local temp_file=$(mktemp)
  if jq --arg id "$story_id" \
    '(.userStories[] | select(.id == $id)).passes = true' \
    "$prd_file" > "$temp_file"; then
    mv "$temp_file" "$prd_file"
  else
    rm -f "$temp_file"
    log_error "Failed to update prd.json for $story_id"
    return 1
  fi

  # Commit the prd.json update
  git add "$prd_file"
  git commit -m "chore: Preserve $story_id completion after merge conflict"

  log_info "Preserved completion status for $story_id"
  echo -e "${GREEN}✓ Preserved ${story_id} completion status${NC}"
  return 0
}

# ---- Merge Functions ---------------------------------------------

# Merge a story sub-branch into the feature branch
# Usage: merge_story_branch <feature_branch> <story_branch> <story_id> [story_title]
# Returns:
#   0 = merge succeeded
#   1 = merge failed, story was NOT marked complete on sub-branch
#   2 = merge failed, story WAS marked complete on sub-branch (needs preservation)
merge_story_branch() {
  local feature_branch="$1"
  local story_branch="$2"
  local story_id="$3"
  local story_title="${4:-$story_id}"

  # BEFORE merge: check if story is marked complete on sub-branch
  local story_passes=$(get_story_passes_from_branch "$story_branch" "$story_id")
  log_debug "Story $story_id passes status on $story_branch: $story_passes"

  log_info "Merging $story_branch into $feature_branch"

  # Ensure we're on the feature branch
  git checkout "$feature_branch"

  # Pull latest changes to feature branch (in case of remote updates)
  git pull origin "$feature_branch" 2>/dev/null || true

  # Merge the story branch with --no-ff for clear merge commit
  local merge_msg="Merge $story_id: $story_title"
  if git merge --no-ff "$story_branch" -m "$merge_msg"; then
    log_info "Successfully merged $story_branch"
    echo -e "${GREEN}✓ Merged ${story_id}${NC}"
    return 0
  else
    log_error "Merge conflict detected for $story_branch"
    echo -e "${RED}✗ Merge conflict for ${story_id}${NC}"
    echo -e "${YELLOW}Attempting to abort merge and continue...${NC}"
    git merge --abort 2>/dev/null || true

    # Return 2 if story was marked complete (needs preservation)
    if [ "$story_passes" = "true" ]; then
      log_info "Story $story_id was complete on sub-branch, needs preservation"
      return 2
    fi
    return 1
  fi
}

# ---- Cleanup Functions -------------------------------------------

# Delete a story sub-branch locally and optionally on remote
# Usage: cleanup_story_branch <branch_name> [delete_remote]
cleanup_story_branch() {
  local branch_name="$1"
  local delete_remote="${2:-false}"

  log_info "Cleaning up branch: $branch_name"

  # Delete local branch
  if git show-ref --verify --quiet "refs/heads/$branch_name" 2>/dev/null; then
    git branch -d "$branch_name" 2>/dev/null || git branch -D "$branch_name" 2>/dev/null || true
    log_debug "Deleted local branch: $branch_name"
  fi

  # Optionally delete remote branch
  if [ "$delete_remote" = "true" ]; then
    if git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
      git push origin --delete "$branch_name" 2>/dev/null || true
      log_debug "Deleted remote branch: $branch_name"
    fi
  fi
}

# ---- Push Functions ----------------------------------------------

# Push a branch to remote with upstream tracking
# Usage: push_branch <branch_name>
push_branch() {
  local branch_name="$1"

  log_info "Pushing branch: $branch_name"

  # Check if remote exists
  if ! git remote get-url origin >/dev/null 2>&1; then
    log_warn "No remote 'origin' configured, skipping push"
    echo -e "${YELLOW}⚠ No remote configured, skipping push${NC}"
    return 1
  fi

  # Push with upstream tracking
  if git push -u origin "$branch_name" 2>&1; then
    log_info "Successfully pushed $branch_name"
    echo -e "${GREEN}✓ Pushed ${branch_name}${NC}"
    return 0
  else
    log_error "Failed to push $branch_name"
    echo -e "${RED}✗ Failed to push ${branch_name}${NC}"
    return 1
  fi
}

# ---- Pull Request Functions --------------------------------------

# Create a pull request using GitHub CLI
# Usage: create_pr <feature_branch> [base_branch] [title] [body]
create_pr() {
  local feature_branch="$1"
  local base_branch="${2:-$(get_git_base_branch)}"
  local title="${3:-}"
  local body="${4:-}"

  log_info "Creating PR: $feature_branch -> $base_branch"

  # Check if gh CLI is available
  if ! command -v gh >/dev/null 2>&1; then
    log_error "GitHub CLI (gh) not found, cannot create PR"
    echo -e "${RED}✗ GitHub CLI not installed. Install: brew install gh${NC}"
    return 1
  fi

  # Check if authenticated
  if ! gh auth status >/dev/null 2>&1; then
    log_error "Not authenticated with GitHub CLI"
    echo -e "${RED}✗ Not authenticated. Run: gh auth login${NC}"
    return 1
  fi

  # Generate title if not provided
  if [ -z "$title" ]; then
    # Extract feature name from branch (ralph/feature-name -> Feature name)
    local feature_name=$(echo "$feature_branch" | sed 's|^ralph/||' | tr '-' ' ')
    title="$feature_name"
  fi

  # Generate body if not provided
  if [ -z "$body" ]; then
    body=$(generate_pr_body)
  fi

  # Build gh pr create command
  local gh_cmd="gh pr create --base \"$base_branch\" --head \"$feature_branch\" --title \"$title\""

  # Add draft flag if configured
  if get_git_pr_draft; then
    gh_cmd="$gh_cmd --draft"
  fi

  # Create PR
  echo -e "${CYAN}Creating pull request...${NC}"

  local pr_url
  if get_git_pr_draft; then
    pr_url=$(gh pr create --base "$base_branch" --head "$feature_branch" --title "$title" --body "$body" --draft 2>&1)
  else
    pr_url=$(gh pr create --base "$base_branch" --head "$feature_branch" --title "$title" --body "$body" 2>&1)
  fi

  if [ $? -eq 0 ]; then
    log_info "PR created: $pr_url"
    echo -e "${GREEN}✓ Pull request created${NC}"
    echo -e "  ${CYAN}$pr_url${NC}"
    return 0
  else
    log_error "Failed to create PR: $pr_url"
    echo -e "${RED}✗ Failed to create pull request${NC}"
    echo "$pr_url"
    return 1
  fi
}

# Generate PR body from prd.json and progress
# Usage: pr_body=$(generate_pr_body)
generate_pr_body() {
  local prd_file="${PRD_FILE:-prd.json}"

  local project_desc=""
  local stories_summary=""

  if [ -f "$prd_file" ]; then
    project_desc=$(jq -r '.description // ""' "$prd_file" 2>/dev/null)

    # Generate stories summary
    stories_summary=$(jq -r '.userStories[] | "- [x] \(.id): \(.title)"' "$prd_file" 2>/dev/null | head -20)
  fi

  cat << EOF
## Summary
${project_desc:-"Feature implementation completed by Ralph"}

## Completed Stories
${stories_summary:-"See prd.json for details"}

## Test Plan
- [ ] Review code changes
- [ ] Run test suite
- [ ] Manual verification

---
*Generated by [Ralph](https://github.com/Moty/ralph)*
EOF
}

# ---- Utility Functions -------------------------------------------

# Get the story ID that was just completed in this iteration
# Usage: story_id=$(get_completed_story_id)
# Returns: The ID of the story that just had passes set to true
get_completed_story_id() {
  local prd_file="${PRD_FILE:-prd.json}"

  # Get the most recently modified story that has passes: true
  # This assumes the agent just set it, so it's the current story
  # We use the story selection logic from get_current_story but inverted

  # Get the highest priority story that was just completed
  # Since agents work on highest priority incomplete story, the most recently
  # completed one is the highest priority one with passes: true
  jq -r '[.userStories[] | select(.passes == true)] | sort_by(.priority) | last | .id // empty' "$prd_file" 2>/dev/null
}

# Check if we're in a git repository
# Usage: is_git_repo && echo "yes"
is_git_repo() {
  git rev-parse --git-dir >/dev/null 2>&1
}

# Get the current branch name
# Usage: branch=$(get_current_branch)
get_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Check if there are uncommitted changes
# Usage: has_uncommitted_changes && echo "dirty"
has_uncommitted_changes() {
  ! git diff-index --quiet HEAD -- 2>/dev/null
}

# Validate that git remote is configured
# Usage: validate_git_remote
validate_git_remote() {
  if ! git remote get-url origin >/dev/null 2>&1; then
    log_warn "No git remote 'origin' configured"
    echo -e "${YELLOW}Warning: No git remote configured${NC}"
    echo -e "${YELLOW}Push and PR features will be disabled${NC}"
    return 1
  fi

  log_debug "Git remote configured: $(git remote get-url origin)"
  return 0
}

# ---- Initialization ----------------------------------------------

log_debug "Git library loaded"
