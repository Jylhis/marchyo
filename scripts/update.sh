#!/usr/bin/env bash
#
# Marchyo Update Script
# Safely update your Marchyo-based NixOS system with previews and confirmation
#
# Usage: ./scripts/update.sh [--auto]
#   --auto: Skip confirmation prompts (use with caution)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
FLAKE_DIR="${FLAKE_DIR:-/etc/nixos}"
AUTO_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --auto)
      AUTO_MODE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Marchyo System Update Script     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}✗ Don't run this script as root${NC}"
  echo "Run as normal user - sudo will be used when needed"
  exit 1
fi

# Check if in flake directory
if [[ ! -f "$FLAKE_DIR/flake.nix" ]]; then
  echo -e "${RED}✗ flake.nix not found in $FLAKE_DIR${NC}"
  exit 1
fi

cd "$FLAKE_DIR"

echo -e "${BLUE}📍 Working directory: $FLAKE_DIR${NC}"
echo ""

# Step 1: Check for uncommitted changes
echo -e "${YELLOW}→ Checking for uncommitted changes...${NC}"
if [[ -d .git ]]; then
  if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}⚠ Warning: Uncommitted changes detected${NC}"
    if [[ "$AUTO_MODE" == false ]]; then
      git status --short
      read -p "Continue anyway? [y/N] " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}✗ Update cancelled${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${GREEN}✓ Working directory clean${NC}"
  fi
fi
echo ""

# Step 2: Update flake inputs
echo -e "${YELLOW}→ Updating flake inputs...${NC}"
if sudo nix flake update; then
  echo -e "${GREEN}✓ Flake inputs updated${NC}"
else
  echo -e "${RED}✗ Failed to update flake inputs${NC}"
  exit 1
fi
echo ""

# Step 3: Show what changed
echo -e "${YELLOW}→ Flake input changes:${NC}"
git diff flake.lock
echo ""

# Step 4: Build new configuration
echo -e "${YELLOW}→ Building new configuration...${NC}"
if sudo nixos-rebuild build --flake .; then
  echo -e "${GREEN}✓ Build successful${NC}"
else
  echo -e "${RED}✗ Build failed${NC}"
  exit 1
fi
echo ""

# Step 5: Show what will change
echo -e "${YELLOW}→ Changes to be applied:${NC}"
if command -v nvd &> /dev/null; then
  sudo nvd diff /run/current-system ./result
else
  nix store diff-closures /run/current-system ./result
fi
echo ""

# Step 6: Confirm before applying
if [[ "$AUTO_MODE" == false ]]; then
  echo -e "${YELLOW}❓ Apply these changes?${NC}"
  read -p "Continue with system switch? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Update cancelled - keeping current system${NC}"
    echo -e "${BLUE}Note: New configuration built as ./result${NC}"
    exit 0
  fi
fi

# Step 7: Switch to new configuration
echo ""
echo -e "${YELLOW}→ Switching to new configuration...${NC}"
if sudo nixos-rebuild switch --flake .; then
  echo -e "${GREEN}✓ Successfully switched to new configuration${NC}"
else
  echo -e "${RED}✗ Switch failed${NC}"
  echo -e "${YELLOW}You can rollback with: sudo nixos-rebuild switch --rollback${NC}"
  exit 1
fi
echo ""

# Step 8: Show new generation
CURRENT_GEN=$(readlink -f /run/current-system | grep -oP '(?<=system-)\\d+')
echo -e "${GREEN}✓ Now running generation $CURRENT_GEN${NC}"
echo ""

# Step 9: Commit flake.lock if in git
if [[ -d .git ]] && [[ "$AUTO_MODE" == false ]]; then
  echo -e "${YELLOW}→ Commit flake.lock changes?${NC}"
  read -p "Commit updated flake.lock? [Y/n] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    git add flake.lock
    git commit -m "flake: Update inputs (generation $CURRENT_GEN)"
    echo -e "${GREEN}✓ Committed flake.lock${NC}"
  fi
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      Update Completed Successfully    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  - Reboot to apply kernel/boot changes (if any)"
echo "  - Run 'sudo nix-collect-garbage' to clean old generations"
echo "  - Monitor system logs: 'journalctl -b -p err'"
echo ""
