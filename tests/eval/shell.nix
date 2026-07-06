# Shell configuration tests: bash-by-default, modern tooling, and the
# SSH/terminfo wiring for interactive TUI applications.
{ helpers, lib, ... }:
let
  inherit (helpers)
    testNixOSCheck
    testDarwinCheck
    testDarwinCheckFor
    withTestUser
    withDarwinTestUser
    ;
in
{
  # Bash (bashInteractive, 5.x) is the explicit default login shell on NixOS.
  eval-shell-default-bash = testNixOSCheck "shell-default-bash" (
    cfg: lib.hasPrefix "bash" (lib.getName cfg.users.defaultUserShell)
  ) (withTestUser { });

  # Ghostty opts into the ssh-env + ssh-terminfo integration features so SSH
  # sessions get a working TERM (xterm-ghostty installed remotely, or the
  # xterm-256color fallback) instead of broken TUI apps.
  eval-shell-ghostty-ssh-features = testNixOSCheck "shell-ghostty-ssh-features" (
    cfg:
    let
      features = cfg.home-manager.users.testuser.programs.ghostty.settings.shell-integration-features;
    in
    lib.hasInfix "ssh-env" features && lib.hasInfix "ssh-terminfo" features
  ) (withTestUser { });

  # The xterm-ghostty terminfo is available system-wide for inbound SSH.
  eval-shell-ghostty-terminfo = testNixOSCheck "shell-ghostty-terminfo" (
    cfg: builtins.any (p: lib.getName p == "ghostty") cfg.environment.systemPackages
  ) (withTestUser { });

  # Marchyo users get the modern interactive bash stack: bash enabled with the
  # shared aliases (generic/shell.nix) and the starship prompt.
  eval-shell-bash-experience = testNixOSCheck "shell-bash-experience" (
    cfg:
    let
      hm = cfg.home-manager.users.testuser;
    in
    hm.programs.bash.enable && (hm.programs.bash.shellAliases ? g) && hm.programs.starship.enable
  ) (withTestUser { });

  # marchyo.users.<name>.uid flows into users.users.<name>.uid on NixOS.
  eval-shell-user-uid =
    testNixOSCheck "shell-user-uid" (cfg: cfg.users.users.seconduser.uid == 1501)
      (withTestUser {
        marchyo.users.seconduser = {
          enable = true;
          fullname = "Second User";
          email = "second@example.com";
          uid = 1501;
        };
      });

  # Darwin: bash 5.x registered in /etc/shells and the curated HM subset wired
  # for marchyo users (bash + aliases + starship + ghostty ssh features).
  eval-shell-darwin-bash = testDarwinCheck "shell-darwin-bash" (
    cfg:
    let
      hm = cfg.home-manager.users.testuser;
    in
    builtins.any (s: lib.hasInfix "bash-interactive" (toString s)) cfg.environment.shells
    && hm.programs.bash.enable
    && (hm.programs.bash.shellAliases ? g)
    && hm.programs.starship.enable
    && lib.hasInfix "ssh-terminfo" hm.programs.ghostty.settings.shell-integration-features
  ) (withDarwinTestUser { });

  # x86_64-darwin rides the stable trio (nixpkgs 26.05 + home-manager
  # release-26.05 + nix-darwin 26.05); prove the curated HM subset in
  # modules/darwin/home.nix also resolves against the stable Home Manager.
  eval-shell-darwin-stable-hm = testDarwinCheckFor "x86_64-darwin" "shell-darwin-stable-hm" (
    cfg:
    let
      hm = cfg.home-manager.users.testuser;
    in
    hm.programs.bash.enable && (hm.programs.bash.shellAliases ? g) && hm.programs.git.enable
  ) (withDarwinTestUser { });

  # Darwin: providing a uid opts the user into users.knownUsers and switches
  # the login shell to bash declaratively.
  eval-shell-darwin-known-user =
    testDarwinCheck "shell-darwin-known-user"
      (
        cfg:
        builtins.elem "testuser" cfg.users.knownUsers
        && lib.hasInfix "bash-interactive" (toString cfg.users.users.testuser.shell)
      )
      (withDarwinTestUser {
        marchyo.users.testuser.uid = 501;
      });
}
