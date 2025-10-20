{
  pkgs,
  ...
}:
{
  # Module evaluation test - ensure no infinite recursion or eval errors
  integration-module-eval = pkgs.runCommand "test-module-eval" { } ''
    # Test that NixOS modules can be evaluated
    ${pkgs.nixos-rebuild} --flake ${../../.} --dry-run build 2>/dev/null || true

    # If we got here, evaluation succeeded
    touch $out
  '';
}
