_:
let
  # Shared aliases for bash and zsh. Both NixOS and Home Manager expose
  # programs.{bash,zsh}.shellAliases, so this file stays platform-agnostic.
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
in
{
  programs = {
    bash = {
      inherit shellAliases;
    };
    zsh = {
      inherit shellAliases;
    };
  };
}
