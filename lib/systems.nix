# Single source of truth for the system list.
# Imported by flake.nix and outputs.nix so adding/removing a system is
# a one-file change.
rec {
  linux = [
    "x86_64-linux"
    "aarch64-linux"
  ];
  darwin = [
    "aarch64-darwin"
    "x86_64-darwin"
  ];
  all = linux ++ darwin;
}
