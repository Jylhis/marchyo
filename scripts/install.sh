#!/usr/bin/env bash
#
# Marchyo NixOS Installation Script
# Automated installation using nixos-anywhere or nixos-install
#
# Usage Examples:
#   Remote install with LUKS encryption:
#     sudo ./install.sh --host myserver --target 192.168.1.100 --disko luks-btrfs --ssh-key ~/.ssh/id_ed25519
#
#   Local install with simple UEFI:
#     sudo ./install.sh --host mylaptop --target localhost --disko simple-uefi --disk /dev/nvme0n1
#
#   Dry run to test configuration:
#     sudo ./install.sh --host test --target 192.168.1.50 --disko zfs --dry-run
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DISK="/dev/sda"
FLAKE_REPO="github:Jylhis/marchyo"
DRY_RUN=false
YES=false
HOST=""
TARGET=""
DISKO=""
SSH_KEY=""

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_usage() {
    cat << EOF
Marchyo NixOS Installation Script

USAGE:
    $(basename "$0") [OPTIONS]

REQUIRED OPTIONS:
    --host <hostname>           Hostname for the system
    --target <IP|hostname>      Target machine (use 'localhost' for local install)
    --disko <type>              Disk configuration type:
                                  - simple-uefi: Basic UEFI setup
                                  - luks-btrfs: Encrypted Btrfs
                                  - zfs: ZFS filesystem

OPTIONAL:
    --disk <device>             Target disk device (default: /dev/sda)
    --flake-repo <url>          Flake repository URL (default: github:Jylhis/marchyo)
    --ssh-key <path>            SSH key for remote access (required for remote installs)
    --dry-run                   Show what would be done without executing
    --yes                       Skip confirmation prompt
    -h, --help                  Show this help message

EXAMPLES:
    # Remote install with LUKS encryption
    sudo $0 --host server --target 192.168.1.100 --disko luks-btrfs --ssh-key ~/.ssh/id_ed25519

    # Local install with simple UEFI
    sudo $0 --host laptop --target localhost --disko simple-uefi --disk /dev/nvme0n1

    # Dry run
    sudo $0 --host test --target 192.168.1.50 --disko zfs --dry-run

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --host)
            HOST="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            shift 2
            ;;
        --disko)
            DISKO="$2"
            shift 2
            ;;
        --disk)
            DISK="$2"
            shift 2
            ;;
        --flake-repo)
            FLAKE_REPO="$2"
            shift 2
            ;;
        --ssh-key)
            SSH_KEY="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --yes)
            YES=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Check root privileges
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root"
    exit 1
fi

# Validate required parameters
if [[ -z "$HOST" ]]; then
    log_error "Missing required parameter: --host"
    print_usage
    exit 1
fi

if [[ -z "$TARGET" ]]; then
    log_error "Missing required parameter: --target"
    print_usage
    exit 1
fi

if [[ -z "$DISKO" ]]; then
    log_error "Missing required parameter: --disko"
    print_usage
    exit 1
fi

# Validate disko type
case "$DISKO" in
    simple-uefi|luks-btrfs|zfs)
        ;;
    *)
        log_error "Invalid disko type: $DISKO"
        log_error "Valid types: simple-uefi, luks-btrfs, zfs"
        exit 1
        ;;
esac

# Determine if this is a local or remote install
IS_LOCAL=false
if [[ "$TARGET" == "localhost" || "$TARGET" == "127.0.0.1" ]]; then
    IS_LOCAL=true
    log_info "Detected local installation"
else
    log_info "Detected remote installation to $TARGET"

    # Validate SSH key for remote installs
    if [[ -z "$SSH_KEY" ]]; then
        log_error "SSH key is required for remote installations (--ssh-key)"
        exit 1
    fi

    if [[ ! -f "$SSH_KEY" ]]; then
        log_error "SSH key not found: $SSH_KEY"
        exit 1
    fi
fi

# Validate disk device exists (for local installs)
if [[ "$IS_LOCAL" == true && ! -b "$DISK" ]]; then
    log_error "Disk device not found: $DISK"
    exit 1
fi

# Check nixos-anywhere availability for remote installs
if [[ "$IS_LOCAL" == false ]]; then
    log_info "Checking nixos-anywhere availability..."
    if ! command -v nixos-anywhere &> /dev/null; then
        log_warning "nixos-anywhere not found in PATH, will use nix-shell"
        NIXOS_ANYWHERE="nix-shell -p nixos-anywhere --run nixos-anywhere"
    else
        NIXOS_ANYWHERE="nixos-anywhere"
    fi
fi

# Display configuration summary
echo ""
log_info "Installation Configuration:"
echo "  Hostname:        $HOST"
echo "  Target:          $TARGET"
echo "  Disko Config:    $DISKO"
echo "  Disk Device:     $DISK"
echo "  Flake Repo:      $FLAKE_REPO"
echo "  Install Type:    $([ "$IS_LOCAL" == true ] && echo "Local" || echo "Remote")"
if [[ "$IS_LOCAL" == false ]]; then
    echo "  SSH Key:         $SSH_KEY"
fi
echo "  Dry Run:         $([ "$DRY_RUN" == true ] && echo "Yes" || echo "No")"
echo ""

# Build the flake path
FLAKE_PATH="${FLAKE_REPO}#nixosConfigurations.${HOST}"

# Display what will be executed
log_info "Command to be executed:"
if [[ "$IS_LOCAL" == true ]]; then
    cat << EOF
  1. Apply disko configuration: nix run ${FLAKE_REPO}#disko-${DISKO} -- --mode disko ${DISK}
  2. Generate hardware config: nixos-generate-config --root /mnt
  3. Install system: nixos-install --flake ${FLAKE_PATH}
EOF
else
    cat << EOF
  ${NIXOS_ANYWHERE} --flake ${FLAKE_PATH} --disk-encryption-keys ${DISKO} ${SSH_KEY} ${TARGET}
EOF
fi
echo ""

# Confirmation prompt
if [[ "$YES" == false && "$DRY_RUN" == false ]]; then
    log_warning "This will ERASE ALL DATA on ${DISK} and install NixOS"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
fi

# Execute installation
if [[ "$DRY_RUN" == true ]]; then
    log_success "Dry run completed - no changes made"
    exit 0
fi

# Perform installation
if [[ "$IS_LOCAL" == true ]]; then
    log_info "Starting local installation..."

    # Step 1: Apply disko configuration
    log_info "Step 1/3: Applying disko configuration..."
    if nix run "${FLAKE_REPO}#disko-${DISKO}" -- --mode disko "${DISK}"; then
        log_success "Disko configuration applied"
    else
        log_error "Failed to apply disko configuration"
        exit 1
    fi

    # Step 2: Generate hardware configuration
    log_info "Step 2/3: Generating hardware configuration..."
    if nixos-generate-config --root /mnt; then
        log_success "Hardware configuration generated at /mnt/etc/nixos/hardware-configuration.nix"
        log_warning "Review and move this file to your flake configuration"
    else
        log_error "Failed to generate hardware configuration"
        exit 1
    fi

    # Step 3: Install NixOS
    log_info "Step 3/3: Installing NixOS system..."
    if nixos-install --flake "${FLAKE_PATH}"; then
        log_success "NixOS installation completed"
    else
        log_error "NixOS installation failed"
        log_warning "You may need to manually unmount /mnt before retrying"
        exit 1
    fi

else
    log_info "Starting remote installation..."

    # Build nixos-anywhere command
    NIXOS_ANYWHERE_CMD="${NIXOS_ANYWHERE} --flake ${FLAKE_PATH}"

    # Add SSH key
    NIXOS_ANYWHERE_CMD="${NIXOS_ANYWHERE_CMD} -i ${SSH_KEY}"

    # Add target
    NIXOS_ANYWHERE_CMD="${NIXOS_ANYWHERE_CMD} ${TARGET}"

    log_info "Executing: ${NIXOS_ANYWHERE_CMD}"

    if eval "${NIXOS_ANYWHERE_CMD}"; then
        log_success "Remote installation completed"
    else
        log_error "Remote installation failed"
        exit 1
    fi
fi

# Display post-installation instructions
echo ""
log_success "Installation completed successfully!"
echo ""
log_info "Post-Installation Steps:"
echo ""

if [[ "$IS_LOCAL" == true ]]; then
    cat << EOF
  1. Reboot into the new system:
     ${GREEN}reboot${NC}

  2. After reboot, set the root password:
     ${GREEN}sudo passwd root${NC}

  3. Create user accounts as defined in your configuration

  4. If you generated hardware-configuration.nix, integrate it into your flake:
     - Copy /etc/nixos/hardware-configuration.nix to your flake repository
     - Import it in your host configuration
     - Rebuild: ${GREEN}sudo nixos-rebuild switch --flake ${FLAKE_REPO}${NC}

  5. Update your configuration:
     ${GREEN}sudo nixos-rebuild switch --flake ${FLAKE_REPO}${NC}
EOF
else
    cat << EOF
  1. SSH into the new system:
     ${GREEN}ssh root@${TARGET}${NC}

  2. Set the root password:
     ${GREEN}passwd${NC}

  3. Create user accounts as defined in your configuration

  4. Copy the generated hardware-configuration.nix to your flake:
     ${GREEN}scp root@${TARGET}:/etc/nixos/hardware-configuration.nix ./hosts/${HOST}/${NC}

  5. Update your flake configuration and rebuild:
     ${GREEN}git add hosts/${HOST}/hardware-configuration.nix${NC}
     ${GREEN}git commit -m "Add hardware config for ${HOST}"${NC}
     ${GREEN}git push${NC}
     ${GREEN}nixos-rebuild switch --flake ${FLAKE_REPO}#${HOST} --target-host root@${TARGET}${NC}
EOF
fi

echo ""
log_info "For issues or rollback instructions, see:"
echo "  - NixOS manual: https://nixos.org/manual/nixos/stable/"
echo "  - Disko documentation: https://github.com/nix-community/disko"
echo "  - nixos-anywhere: https://github.com/nix-community/nixos-anywhere"
echo ""

exit 0
