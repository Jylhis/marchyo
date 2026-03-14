# Run nix evaluation checks
test:
    nix flake check

# Build the full NixOS system toplevel
build:
    nix build .#nixosConfigurations.default.config.system.build.toplevel

# Run the default configuration in a QEMU VM
run:
    nix run
