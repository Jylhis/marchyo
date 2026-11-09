{
  lib,
  pkgs,
  options,
  ...
}:
let
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
  # Copy-on-write (reflink) where the filesystem supports it; `=auto` falls
  # back to a full copy elsewhere. GNU coreutils only.
  cpAlias = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
    cp = "cp --reflink=auto";
  };
  shellAliases = baseAliases // cpAlias;
  hasBashAliases =
    options ? programs && options.programs ? bash && options.programs.bash ? shellAliases;
in
{
  programs = lib.optionalAttrs hasBashAliases { bash = { inherit shellAliases; }; };
}
