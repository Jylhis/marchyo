#!/usr/bin/env bash
#
# Marchyo Rollback Script
# Quickly rollback to a previous system generation
#
# Usage: ./scripts/rollback.sh [generation_number]
#   If no generation number provided, shows interactive list

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Marchyo System Rollback Script    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
  echo -e "${RED}✗ Don't run this script as root${NC}"
  echo "Run as normal user - sudo will be used when needed"
  exit 1
fi

# Get current generation
CURRENT_GEN=$(readlink -f /run/current-system | grep -oP '(?<=system-)\d+')
echo -e "${GREEN}Current generation: $CURRENT_GEN${NC}"
echo ""

# List available generations
echo -e "${YELLOW}→ Available system generations:${NC}"
echo ""

# Parse nix-env output and format nicely
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | while read -r line; do
  GEN=$(echo "$line" | awk '{print $1}')
  DATE=$(echo "$line" | awk '{print $2, $3}')
  CURRENT=$(echo "$line" | grep -o "(current)" || echo "")

  if [[ -n "$CURRENT" ]]; then
    echo -e "  ${GREEN}→ $GEN${NC}  $DATE  ${GREEN}(current)${NC}"
  else
    echo -e "    $GEN  $DATE"
  fi
done

echo ""

# If generation number provided as argument
if [[ $# -eq 1 ]]; then
  TARGET_GEN=$1
else
  # Interactive mode
  read -r -p "Enter generation number to rollback to (or 'q' to quit): " TARGET_GEN

  if [[ "$TARGET_GEN" == "q" ]] || [[ -z "$TARGET_GEN" ]]; then
    echo -e "${YELLOW}Rollback cancelled${NC}"
    exit 0
  fi
fi

# Validate generation number
if ! [[ "$TARGET_GEN" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}✗ Invalid generation number: $TARGET_GEN${NC}"
  exit 1
fi

# Check if generation exists
if ! sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | grep -q "^\\s*$TARGET_GEN\\s"; then
  echo -e "${RED}✗ Generation $TARGET_GEN does not exist${NC}"
  exit 1
fi

# Check if trying to rollback to current
if [[ "$TARGET_GEN" == "$CURRENT_GEN" ]]; then
  echo -e "${YELLOW}⚠ Already on generation $TARGET_GEN${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}→ Rolling back from generation $CURRENT_GEN to $TARGET_GEN${NC}"
echo ""

# Show differences if nvd is available
if command -v nvd &> /dev/null; then
  echo -e "${YELLOW}→ Changes:${NC}"
  sudo nvd diff /run/current-system "/nix/var/nix/profiles/system-${TARGET_GEN}-link" || true
  echo ""
fi

# Confirm
read -p "Proceed with rollback? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo -e "${YELLOW}Rollback cancelled${NC}"
  exit 0
fi

echo ""
echo -e "${YELLOW}→ Switching to generation $TARGET_GEN...${NC}"

# Switch to target generation
if sudo "/nix/var/nix/profiles/system-${TARGET_GEN}-link/bin/switch-to-configuration" switch; then
  echo ""
  echo -e "${GREEN}✓ Successfully rolled back to generation $TARGET_GEN${NC}"
  echo ""
  echo -e "${BLUE}Note:${NC} This generation is now active but not the latest."
  echo "Run 'sudo nixos-rebuild switch' to return to the latest generation."
else
  echo -e "${RED}✗ Rollback failed${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Rollback Completed Successfully   ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  - Reboot to ensure all services use rolled-back configuration"
echo "  - Check system logs: 'journalctl -b -p err'"
echo "  - If issues persist, try an earlier generation"
echo ""
