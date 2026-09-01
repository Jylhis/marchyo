{
  lib,
  pkgs,
  options,
  ...
}:
let
  # Shared aliases for bash. Both NixOS and Home Manager expose
  # programs.bash.shellAliases, so this file stays platform-agnostic.
  # nix-darwin does not have these options, so we guard with option checks.
  baseAliases = {
    ls = "eza -lh --group-directories-first --icons=auto";
    lsa = "ls -a";
    lt = "eza --tree --level=2 --long --icons --git";
    lta = "lt -a";
    ff = "fzf --preview 'bat --style=numbers --color=always {}'";

    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    g = "git";
    gcm = "git commit -m";
    gcam = "git commit -a -m";
    gcad = "git commit -a --amend";
  };
  # Always prefer copy-on-write (reflink) copies where the filesystem supports
  # them (btrfs, xfs, ...); `=auto` falls back to a full copy elsewhere, so it
  # is always safe. GNU coreutils only — macOS ships BSD cp (no --reflink).
  cpAlias = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    cp = "cp --reflink=auto";
  };
  shellAliases = baseAliases // cpAlias;
  hasBashAliases =
    options ? programs && options.programs ? bash && options.programs.bash ? shellAliases;
in
{
  programs = if hasBashAliases then { bash = { inherit shellAliases; }; } else { };
}
