#!/usr/bin/env bash
#
# Marchyo System Health Check
# Verify system health and identify potential issues
#
# Usage: ./scripts/health-check.sh [--verbose]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERBOSE=false
ISSUES=0

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Marchyo System Health Check       ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Helper functions
check_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
  ((ISSUES++))
}

check_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

check_info() {
  if [[ "$VERBOSE" == true ]]; then
    echo -e "${BLUE}ℹ${NC} $1"
  fi
}

# System Information
echo -e "${BLUE}System Information:${NC}"
HOSTNAME=$(hostname)
CURRENT_GEN=$(readlink -f /run/current-system | grep -oP '(?<=system-)\\d+' || echo "unknown")
KERNEL=$(uname -r)
UPTIME=$(uptime -p)

check_info "Hostname: $HOSTNAME"
check_info "Generation: $CURRENT_GEN"
check_info "Kernel: $KERNEL"
check_info "Uptime: $UPTIME"
echo ""

# Check systemd services
echo -e "${BLUE}Systemd Services:${NC}"
FAILED_SERVICES=$(systemctl --failed --no-legend | wc -l)

if [[ $FAILED_SERVICES -eq 0 ]]; then
  check_pass "No failed services"
else
  check_fail "$FAILED_SERVICES failed service(s)"
  if [[ "$VERBOSE" == true ]]; then
    systemctl --failed
  fi
fi
echo ""

# Check disk space
echo -e "${BLUE}Disk Space:${NC}"
while IFS= read -r line; do
  MOUNTPOINT=$(echo "$line" | awk '{print $6}')
  USAGE=$(echo "$line" | awk '{print $5}' | tr -d '%')

  if [[ "$MOUNTPOINT" == "/" ]] || [[ "$MOUNTPOINT" == "/boot" ]] || [[ "$MOUNTPOINT" == "/home" ]]; then
    if [[ $USAGE -gt 90 ]]; then
      check_fail "$MOUNTPOINT is ${USAGE}% full"
    elif [[ $USAGE -gt 80 ]]; then
      check_warn "$MOUNTPOINT is ${USAGE}% full"
    else
      check_pass "$MOUNTPOINT is ${USAGE}% full"
    fi
  fi
done < <(df -h | grep -E '^/dev/')
echo ""

# Check Nix store
echo -e "${BLUE}Nix Store:${NC}"
NIX_STORE_SIZE=$(du -sh /nix/store 2>/dev/null | awk '{print $1}' || echo "unknown")
check_info "Nix store size: $NIX_STORE_SIZE"

# Count generations
GEN_COUNT=$(sudo nix-env --list-generations --profile /nix/var/nix/profiles/system | wc -l)
if [[ $GEN_COUNT -gt 20 ]]; then
  check_warn "$GEN_COUNT system generations (consider cleanup)"
else
  check_pass "$GEN_COUNT system generations"
fi
echo ""

# Check memory
echo -e "${BLUE}Memory Usage:${NC}"
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
USED_MEM=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')

if [[ $MEM_PERCENT -gt 90 ]]; then
  check_warn "Memory ${MEM_PERCENT}% used ($USED_MEM / $TOTAL_MEM)"
else
  check_pass "Memory ${MEM_PERCENT}% used ($USED_MEM / $TOTAL_MEM)"
fi
echo ""

# Check swap
echo -e "${BLUE}Swap Usage:${NC}"
SWAP_TOTAL=$(free -h | awk '/^Swap:/ {print $2}')
if [[ "$SWAP_TOTAL" == "0B" ]] || [[ -z "$SWAP_TOTAL" ]]; then
  check_info "No swap configured"
else
  SWAP_USED=$(free -h | awk '/^Swap:/ {print $3}')
  SWAP_PERCENT=$(free | awk '/^Swap:/ { if ($2 > 0) printf "%.0f", $3/$2 * 100; else print "0" }')
  if [[ $SWAP_PERCENT -gt 50 ]]; then
    check_warn "Swap ${SWAP_PERCENT}% used ($SWAP_USED / $SWAP_TOTAL)"
  else
    check_pass "Swap ${SWAP_PERCENT}% used ($SWAP_USED / $SWAP_TOTAL)"
  fi
fi
echo ""

# Check journal errors
echo -e "${BLUE}Recent Errors:${NC}"
ERROR_COUNT=$(journalctl -b -p err --no-pager | wc -l)
if [[ $ERROR_COUNT -eq 0 ]]; then
  check_pass "No errors in current boot"
elif [[ $ERROR_COUNT -lt 10 ]]; then
  check_warn "$ERROR_COUNT error(s) in journal"
else
  check_fail "$ERROR_COUNT error(s) in journal"
fi

if [[ "$VERBOSE" == true ]] && [[ $ERROR_COUNT -gt 0 ]]; then
  echo ""
  journalctl -b -p err --no-pager | tail -10
fi
echo ""

# Check network
echo -e "${BLUE}Network:${NC}"
if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
  check_pass "Internet connectivity"
else
  check_fail "No internet connectivity"
fi
echo ""

# Check NixOS configuration
echo -e "${BLUE}NixOS Configuration:${NC}"
if [[ -f /etc/nixos/flake.nix ]]; then
  check_pass "Flake configuration found"

  cd /etc/nixos
  if [[ -d .git ]]; then
    if git diff --quiet && git diff --cached --quiet; then
      check_pass "Configuration is clean (no uncommitted changes)"
    else
      check_warn "Uncommitted changes in configuration"
      if [[ "$VERBOSE" == true ]]; then
        git status --short
      fi
    fi
  else
    check_info "Configuration not in git"
  fi
else
  check_warn "No flake.nix found in /etc/nixos"
fi
echo ""

# Check Hyprland (if running)
if pgrep -x Hyprland &> /dev/null; then
  echo -e "${BLUE}Hyprland:${NC}"
  check_pass "Hyprland is running"
  echo ""
fi

# Summary
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
if [[ $ISSUES -eq 0 ]]; then
  echo -e "${GREEN}║        All Checks Passed ✓            ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
  exit 0
else
  echo -e "${YELLOW}║      Found $ISSUES Issue(s) ⚠             ║${NC}"
  echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
  echo ""
  echo -e "${YELLOW}Recommendations:${NC}"
  echo "  - Fix failed systemd services"
  echo "  - Free up disk space if needed"
  echo "  - Run 'sudo nix-collect-garbage' to clean old generations"
  echo "  - Check journal for errors: 'journalctl -b -p err'"
  exit 1
fi
