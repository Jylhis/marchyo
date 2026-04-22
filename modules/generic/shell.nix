{ options, ... }:
let
  # Shared aliases for bash and zsh. Both NixOS and Home Manager expose
  # programs.{bash,zsh}.shellAliases, so this file stays platform-agnostic.
  # nix-darwin does not have these options, so we guard with option checks.
  shellAliases = {
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
  hasBashAliases = options ? programs && options.programs ? bash && options.programs.bash ? shellAliases;
  hasZshAliases = options ? programs && options.programs ? zsh && options.programs.zsh ? shellAliases;
in
{
  programs =
    (if hasBashAliases then { bash = { inherit shellAliases; }; } else { })
    // (if hasZshAliases then { zsh = { inherit shellAliases; }; } else { });
}
