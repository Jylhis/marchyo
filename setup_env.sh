#!/usr/bin/env bash
set -e

echo "Setting up environment for Jules..."

# 1. Pre-configure Nix to disable sandboxing/syscall-filtering
# This prevents the "seccomp bpf" error by telling Nix not to use those kernel features.
if [ ! -f ~/.config/nix/nix.conf ]; then
    mkdir -p ~/.config/nix
    cat <<CONF > ~/.config/nix/nix.conf
sandbox = false
filter-syscalls = false
experimental-features = nix-command flakes
CONF
    echo "Configured ~/.config/nix/nix.conf"
else
    echo "$HOME/.config/nix/nix.conf already exists, skipping."
fi

# 2. Install Nix (Single-User Mode)
if ! command -v nix &> /dev/null; then
    echo "Installing Nix..."
    sh <(curl -L https://nixos.org/nix/install) --no-daemon --yes
    # Source the environment for this session
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    # shellcheck disable=SC1091
        . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
else
    echo "Nix is already installed."
fi

# 3. Verify it works
echo "Verifying Nix installation..."
nix --version

echo "Environment setup complete."
echo "To start the development shell with all required tools (git, nixfmt, etc.), run:"
echo "  nix develop"
echo ""
echo "If you have direnv installed, run:"
echo "  direnv allow"
