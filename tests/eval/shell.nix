# Shell configuration tests: bash-by-default, modern tooling, and the
# SSH/terminfo wiring for interactive TUI applications.
{ lib, pkgs, ... }:
{
  refs.headless = {
    # Bash (bashInteractive, 5.x) is the explicit default login shell on NixOS.
    eval-shell-default-bash = cfg: lib.hasPrefix "bash" (lib.getName cfg.users.defaultUserShell);

    # Ghostty opts into the ssh-env + ssh-terminfo integration features so SSH
    # sessions get a working TERM (xterm-ghostty installed remotely, or the
    # xterm-256color fallback) instead of broken TUI apps.
    eval-shell-ghostty-ssh-features =
      cfg:
      let
        # The HM ghostty settings type merges values into a list (duplicate-key
        # semantics); normalize before matching.
        features = lib.concatStringsSep "," (
          lib.toList cfg.home-manager.users.testuser.programs.ghostty.settings.shell-integration-features
        );
      in
      lib.hasInfix "ssh-env" features && lib.hasInfix "ssh-terminfo" features;

    # The xterm-ghostty terminfo is available system-wide for inbound SSH.
    # Matches by prefix: the terminfo derivation may be named ghostty-terminfo.
    eval-shell-ghostty-terminfo =
      cfg: builtins.any (p: lib.hasPrefix "ghostty" (lib.getName p)) cfg.environment.systemPackages;

    # Marchyo users get the modern interactive bash stack: bash enabled with the
    # marchyo aliases (modules/home/shell.nix) and the starship prompt.
    eval-shell-bash-experience =
      cfg:
      let
        hm = cfg.home-manager.users.testuser;
      in
      hm.programs.bash.enable && (hm.programs.bash.shellAliases ? g) && hm.programs.starship.enable;

    # The aliases default `cp` to reflink (copy-on-write) copies via GNU
    # coreutils' --reflink=auto (modules/home/shell.nix).
    eval-shell-cp-reflink =
      cfg:
      let
        hm = cfg.home-manager.users.testuser;
      in
      (hm.programs.bash.shellAliases.cp or "") == "cp --reflink=auto";

    # User-facing shell and git setup lives in Home Manager only; the system
    # level keeps just what needs root (trippy's capability wrapper) or serves
    # non-user processes (fontconfig role mapping).
    eval-shell-user-level-only =
      cfg:
      let
        hm = cfg.home-manager.users.testuser;
      in
      !(cfg.environment.shellAliases ? g)
      && !cfg.programs.zoxide.enable
      && hm.programs.zoxide.enable
      && hm.programs.git.enable
      && hm.programs.git.lfs.enable
      && hm.programs.git.package.drvPath == pkgs.gitFull.drvPath
      && cfg.programs.trippy.enable
      && cfg.fonts.fontconfig.defaultFonts.monospace != [ ]
      && hm.fonts.fontconfig.enable
      && hm.fonts.fontconfig.defaultFonts.monospace == [ ];
  };
}
