#!/usr/bin/env bash
#
# create-usb.sh - Create bootable Marchyo USB installers
#
# Usage:
#   sudo ./scripts/create-usb.sh --iso path/to/marchyo.iso --device /dev/sdb
#   sudo ./scripts/create-usb.sh --type minimal --device /dev/sdb --verify
#   sudo ./scripts/create-usb.sh --type graphical --device /dev/sdc --label MARCHYO

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
ISO_PATH=""
ISO_TYPE=""
DEVICE=""
VERIFY=false
LABEL="MARCHYO"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLAKE_DIR="$(dirname "$SCRIPT_DIR")"

# Helper functions
print_error() {
    echo -e "${RED}ERROR:${NC} $1" >&2
}

print_success() {
    echo -e "${GREEN}SUCCESS:${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${NC} $1"
}

print_info() {
    echo -e "${BLUE}INFO:${NC} $1"
}

print_header() {
    echo -e "${BOLD}${BLUE}$1${NC}"
}

usage() {
    cat <<EOF
${BOLD}Usage:${NC}
  $0 --iso <path> --device <device> [options]
  $0 --type <minimal|graphical> --device <device> [options]

${BOLD}Required (choose one):${NC}
  --iso <path>              Path to existing ISO file
  --type <minimal|graphical> Build ISO first (minimal or graphical)

${BOLD}Required:${NC}
  --device <device>         Target USB device (e.g., /dev/sdb)

${BOLD}Optional:${NC}
  --verify                  Verify write integrity after writing
  --label <label>           Volume label (default: MARCHYO)
  -h, --help                Show this help message

${BOLD}Examples:${NC}
  # Use existing ISO
  sudo $0 --iso ./result/iso/nixos.iso --device /dev/sdb

  # Build minimal ISO and write to USB
  sudo $0 --type minimal --device /dev/sdb --verify

  # Build graphical ISO with custom label
  sudo $0 --type graphical --device /dev/sdc --label MARCHYO_INSTALL

${BOLD}Safety:${NC}
  - Script must be run as root
  - Requires explicit confirmation before writing
  - Prevents writing to system disks
  - Verifies device is removable
  - Warns about existing partitions
EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Use: sudo $0 $*"
        exit 1
    fi
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --iso)
                ISO_PATH="$2"
                shift 2
                ;;
            --type)
                ISO_TYPE="$2"
                if [[ "$ISO_TYPE" != "minimal" && "$ISO_TYPE" != "graphical" ]]; then
                    print_error "Invalid type: $ISO_TYPE (must be 'minimal' or 'graphical')"
                    exit 1
                fi
                shift 2
                ;;
            --device)
                DEVICE="$2"
                shift 2
                ;;
            --verify)
                VERIFY=true
                shift
                ;;
            --label)
                LABEL="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Validate arguments
validate_args() {
    if [[ -z "$ISO_PATH" && -z "$ISO_TYPE" ]]; then
        print_error "Either --iso or --type must be specified"
        usage
        exit 1
    fi

    if [[ -n "$ISO_PATH" && -n "$ISO_TYPE" ]]; then
        print_error "Cannot specify both --iso and --type"
        usage
        exit 1
    fi

    if [[ -z "$DEVICE" ]]; then
        print_error "Device must be specified with --device"
        usage
        exit 1
    fi
}

# Build ISO if --type was specified
build_iso() {
    local type=$1
    print_header "Building ${type} ISO..."

    cd "$FLAKE_DIR"

    local target=".#nixosConfigurations.iso-${type}.config.system.build.isoImage"
    print_info "Running: nix build ${target}"

    if ! nix build "$target"; then
        print_error "Failed to build ISO"
        exit 1
    fi

    # Find the ISO in the result
    local iso_file
    iso_file=$(find ./result -name "*.iso" -type f | head -n 1)

    if [[ -z "$iso_file" || ! -f "$iso_file" ]]; then
        print_error "ISO file not found in build result"
        exit 1
    fi

    ISO_PATH="$iso_file"
    print_success "ISO built: $ISO_PATH"
}

# Check if device exists
check_device_exists() {
    if [[ ! -b "$DEVICE" ]]; then
        print_error "Device $DEVICE does not exist or is not a block device"
        exit 1
    fi
    print_success "Device $DEVICE exists"
}

# Check if device is removable
check_device_removable() {
    local device_name
    device_name=$(basename "$DEVICE")

    # Remove partition number if present (e.g., sdb1 -> sdb)
    device_name=${device_name%%[0-9]*}

    local removable_file="/sys/block/${device_name}/removable"

    if [[ -f "$removable_file" ]]; then
        local removable
        removable=$(cat "$removable_file")
        if [[ "$removable" != "1" ]]; then
            print_warning "Device $DEVICE does not appear to be removable"
            read -p "Continue anyway? [y/N] " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Aborted by user"
                exit 1
            fi
        else
            print_success "Device is removable"
        fi
    else
        print_warning "Cannot determine if device is removable"
    fi
}

# Prevent writing to system disk
check_system_disk() {
    # Check if device or any of its partitions are mounted
    if mount | grep -q "^${DEVICE}"; then
        local mount_points
        mount_points=$(mount | grep "^${DEVICE}" | awk '{print $3}')

        # Check for critical mount points
        while IFS= read -r mount_point; do
            if [[ "$mount_point" == "/" || "$mount_point" == "/home" || "$mount_point" == "/boot" || "$mount_point" == "/nix" ]]; then
                print_error "Device $DEVICE is mounted as $mount_point (system disk)"
                print_error "Refusing to write to system disk"
                exit 1
            fi
        done <<< "$mount_points"

        print_warning "Device $DEVICE has mounted partitions:"
        echo "$mount_points"
        print_info "These will be unmounted"
    fi
}

# Check for existing partitions
check_partitions() {
    if [[ -b "${DEVICE}1" ]] || [[ -b "${DEVICE}p1" ]]; then
        print_warning "Device $DEVICE contains existing partitions"
        print_info "All data will be DESTROYED"

        # Try to show partition info
        if command -v lsblk &> /dev/null; then
            echo
            lsblk "$DEVICE" 2>/dev/null || true
            echo
        fi
    fi
}

# Get device size
get_device_size() {
    local size_bytes
    size_bytes=$(blockdev --getsize64 "$DEVICE" 2>/dev/null || echo "0")

    if [[ "$size_bytes" -eq 0 ]]; then
        print_warning "Cannot determine device size"
        return
    fi

    local size_gb
    size_gb=$((size_bytes / 1024 / 1024 / 1024))
    print_info "Device size: ${size_gb}GB"
}

# Confirm before writing
confirm_write() {
    echo
    print_header "FINAL CONFIRMATION"
    echo -e "  ${BOLD}ISO:${NC}    $ISO_PATH"
    echo -e "  ${BOLD}Device:${NC} $DEVICE"
    echo -e "  ${BOLD}Label:${NC}  $LABEL"
    echo -e "  ${BOLD}Verify:${NC} $VERIFY"
    echo
    print_warning "ALL DATA ON $DEVICE WILL BE DESTROYED"
    echo
    read -p "Type 'YES' in capital letters to continue: " -r

    if [[ "$REPLY" != "YES" ]]; then
        print_info "Aborted by user"
        exit 0
    fi
}

# Unmount device partitions
unmount_device() {
    print_info "Unmounting any mounted partitions..."

    # Unmount all partitions
    for part in "${DEVICE}"* "${DEVICE}p"*; do
        if [[ -b "$part" ]] && mount | grep -q "^${part} "; then
            print_info "Unmounting $part"
            umount "$part" 2>/dev/null || true
        fi
    done

    print_success "Device unmounted"
}

# Write ISO to device
write_iso() {
    print_header "Writing ISO to USB device..."

    local iso_size
    iso_size=$(stat -c%s "$ISO_PATH")
    local iso_size_mb=$((iso_size / 1024 / 1024))

    print_info "ISO size: ${iso_size_mb}MB"

    # Check if pv (pipe viewer) is available
    if command -v pv &> /dev/null; then
        print_info "Using pv for progress display"
        pv -s "$iso_size" "$ISO_PATH" | dd of="$DEVICE" bs=4M oflag=direct,sync status=none
    else
        print_info "Using dd with progress (pv not available for better progress display)"
        dd if="$ISO_PATH" of="$DEVICE" bs=4M oflag=direct,sync status=progress
    fi

    print_info "Syncing writes to disk..."
    sync

    print_success "ISO written to $DEVICE"
}

# Verify write integrity
verify_write() {
    if [[ "$VERIFY" != true ]]; then
        return
    fi

    print_header "Verifying write integrity..."

    local iso_size
    iso_size=$(stat -c%s "$ISO_PATH")

    print_info "Computing ISO checksum..."
    local iso_checksum
    iso_checksum=$(sha256sum "$ISO_PATH" | awk '{print $1}')

    print_info "Computing device checksum (this may take a while)..."
    local device_checksum
    device_checksum=$(dd if="$DEVICE" bs=4M count=$((iso_size / 4194304 + 1)) 2>/dev/null | head -c "$iso_size" | sha256sum | awk '{print $1}')

    if [[ "$iso_checksum" == "$device_checksum" ]]; then
        print_success "Verification passed - checksums match"
    else
        print_error "Verification failed - checksums do not match"
        print_error "ISO:    $iso_checksum"
        print_error "Device: $device_checksum"
        exit 1
    fi
}

# Eject device
eject_device() {
    print_info "Ejecting device..."

    if command -v eject &> /dev/null; then
        eject "$DEVICE" 2>/dev/null || print_warning "Could not eject device (may require manual removal)"
    else
        print_warning "eject command not available - please remove device manually"
    fi
}

# Display success message
show_success() {
    echo
    print_header "USB INSTALLER CREATED SUCCESSFULLY"
    echo
    echo -e "${GREEN}${BOLD}The USB device is ready to boot!${NC}"
    echo
    echo "Boot Instructions:"
    echo "  1. Insert the USB drive into target computer"
    echo "  2. Restart and enter BIOS/UEFI settings (usually F2, F12, or DEL)"
    echo "  3. Change boot order to boot from USB first"
    echo "  4. Save and exit BIOS/UEFI"
    echo "  5. Follow the Marchyo installation prompts"
    echo
    echo "Troubleshooting:"
    echo "  - Ensure Secure Boot is disabled in BIOS/UEFI"
    echo "  - Try different USB ports (prefer USB 2.0 for compatibility)"
    echo "  - Some systems require 'Legacy' or 'CSM' boot mode"
    echo
}

# Cleanup on error
cleanup() {
    if [[ $? -ne 0 ]]; then
        print_error "Script failed"
        unmount_device 2>/dev/null || true
    fi
}

trap cleanup EXIT

# Main execution
main() {
    print_header "Marchyo USB Installer Creator"
    echo

    parse_args "$@"
    validate_args
    check_root "$@"

    # Build ISO if needed
    if [[ -n "$ISO_TYPE" ]]; then
        build_iso "$ISO_TYPE"
    fi

    # Verify ISO exists
    if [[ ! -f "$ISO_PATH" ]]; then
        print_error "ISO file not found: $ISO_PATH"
        exit 1
    fi

    print_success "Using ISO: $ISO_PATH"

    # Safety checks
    print_header "Performing Safety Checks"
    check_device_exists
    check_device_removable
    check_system_disk
    check_partitions
    get_device_size

    # Confirm
    confirm_write

    # Start time
    local start_time
    start_time=$(date +%s)

    # Execute
    unmount_device
    write_iso
    verify_write
    eject_device

    # Calculate elapsed time
    local end_time
    end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))

    print_info "Time elapsed: ${minutes}m ${seconds}s"

    # Success
    show_success
}

main "$@"
