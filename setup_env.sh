#!/usr/bin/env bash
set -e

echo "Setting up environment for Jules..."

# 1. Pre-configure Nix to disable sandboxing/syscall-filtering
# This prevents the "seccomp bpf" error by telling Nix not to use those kernel features.
NIX_CONF_DIR="$HOME/.config/nix"
NIX_CONF_FILE="$NIX_CONF_DIR/nix.conf"

mkdir -p "$NIX_CONF_DIR"
touch "$NIX_CONF_FILE"

echo "Ensuring Nix configuration in $NIX_CONF_FILE..."

# Add settings only if the key is not already present.
if ! grep -qE '^\s*sandbox\s*=' "$NIX_CONF_FILE"; then
    echo 'sandbox = false' >> "$NIX_CONF_FILE"
fi
if ! grep -qE '^\s*filter-syscalls\s*=' "$NIX_CONF_FILE"; then
    echo 'filter-syscalls = false' >> "$NIX_CONF_FILE"
fi
if ! grep -qE '^\s*experimental-features\s*=' "$NIX_CONF_FILE"; then
    echo 'experimental-features = nix-command flakes' >> "$NIX_CONF_FILE"
elif ! grep -q 'flakes' "$NIX_CONF_FILE"; then
    echo "WARNING: 'experimental-features' in $NIX_CONF_FILE is missing 'flakes'. Please add it manually."
fi

# 2. Install Nix (Single-User Mode)
if ! command -v nix &> /dev/null; then
    echo "Installing Nix..."
    INSTALL_SCRIPT=$(mktemp)
    # Downloading to a file first is safer than piping curl to sh.
    curl -L -o "$INSTALL_SCRIPT" https://nixos.org/nix/install
    sh "$INSTALL_SCRIPT" --no-daemon --yes
    rm "$INSTALL_SCRIPT"
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
echo "If Nix was installed, you may need to open a new terminal for the 'nix' command to be available."
echo "To start the development shell with all required tools (git, nixfmt, etc.), run:"
echo "  nix develop"
echo ""
echo "If you have direnv installed, run:"
echo "  direnv allow"
