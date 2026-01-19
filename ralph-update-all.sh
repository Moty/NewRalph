#!/bin/bash
# Ralph Bulk Update Script
# Finds and updates all Ralph installations in specified directories
# Usage: ./ralph-update-all.sh [search_paths...]

set -e

RALPH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default search paths if none provided
if [ $# -eq 0 ]; then
  SEARCH_PATHS=(
    "$HOME/Projects"
    "/Volumes/MMMACSSD/Projects"
  )
  echo -e "${CYAN}No paths specified, searching default locations:${NC}"
  for p in "${SEARCH_PATHS[@]}"; do
    echo "  • $p"
  done
  echo ""
else
  SEARCH_PATHS=("$@")
fi

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  Ralph Bulk Updater${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Find all ralph.sh files (excluding the source repo)
FOUND_PROJECTS=()
for search_path in "${SEARCH_PATHS[@]}"; do
  if [ -d "$search_path" ]; then
    while IFS= read -r ralph_file; do
      project_dir=$(dirname "$ralph_file")
      # Skip the source Ralph repo
      if [ "$project_dir" != "$RALPH_DIR" ]; then
        FOUND_PROJECTS+=("$project_dir")
      fi
    done < <(find "$search_path" -name "ralph.sh" -type f 2>/dev/null | grep -v node_modules | grep -v .ralph-backup)
  fi
done

if [ ${#FOUND_PROJECTS[@]} -eq 0 ]; then
  echo -e "${YELLOW}No Ralph installations found.${NC}"
  exit 0
fi

echo -e "Found ${GREEN}${#FOUND_PROJECTS[@]}${NC} Ralph installation(s):"
echo ""

for project in "${FOUND_PROJECTS[@]}"; do
  version="unknown"
  if [ -f "$project/.ralph-version" ]; then
    version=$(grep '^version=' "$project/.ralph-version" 2>/dev/null | sed 's/version=//' || echo "unknown")
  elif [ -f "$project/ralph.sh" ]; then
    version="pre-1.0"
  fi
  echo "  • $project (v$version)"
done

echo ""
read -p "Update all projects? (Y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Nn]$ ]]; then
  echo "Cancelled."
  exit 0
fi

echo ""
echo -e "${CYAN}Starting bulk update...${NC}"
echo ""

UPDATED=0
FAILED=0

for project in "${FOUND_PROJECTS[@]}"; do
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Updating: ${YELLOW}$project${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  
  if "$RALPH_DIR/setup-ralph.sh" --update "$project"; then
    ((UPDATED++))
    echo -e "${GREEN}✓ Updated successfully${NC}"
  else
    ((FAILED++))
    echo -e "${RED}✗ Update failed${NC}"
  fi
  echo ""
done

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Bulk update complete!${NC}"
echo -e "  Updated: ${GREEN}$UPDATED${NC}"
if [ $FAILED -gt 0 ]; then
  echo -e "  Failed:  ${RED}$FAILED${NC}"
fi
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "All projects can now self-update with: ./ralph.sh --update"
