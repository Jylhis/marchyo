# Key-only OpenSSH server. The key check looks at option values only: key
# files are paths and are never read during evaluation.
{ config, lib, ... }:
let
  cfg = config.marchyo.security.ssh;
  sshd = config.services.openssh;

  shellPath =
    shell:
    if shell == null then
      ""
    else if lib.isDerivation shell then
      shell.shellPath or ""
    else
      toString shell;

  hasLoginShell =
    user:
    let
      path = shellPath user.shell;
    in
    user.shell != null && !(lib.hasSuffix "/nologin" path) && !(lib.hasSuffix "/false" path);

  wheelMembers = config.users.groups.wheel.members or [ ];

  admitted =
    name: user:
    (user.enable or true)
    && user.isNormalUser
    && hasLoginShell user
    && (
      user.group == "wheel"
      || builtins.elem "wheel" user.extraGroups
      || builtins.elem name wheelMembers
      || builtins.elem name cfg.users
    );

  hasKeys =
    user: user.openssh.authorizedKeys.keys != [ ] || user.openssh.authorizedKeys.keyFiles != [ ];

  keylessUsers = lib.attrNames (
    lib.filterAttrs (name: user: admitted name user && !hasKeys user) config.users.users
  );

  # "none" switches the source off in sshd_config.
  configured =
    value:
    !builtins.elem value [
      null
      "none"
    ];

  centralAuth =
    configured (sshd.settings.TrustedUserCAKeys or null)
    || configured (sshd.settings.AuthorizedKeysCommand or null)
    || configured sshd.authorizedKeysCommand;
in
{
  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
      };
    };

    assertions = [
      {
        assertion = !sshd.enable || cfg.allowNoKeys || centralAuth || keylessUsers == [ ];
        message = ''
          marchyo.security.ssh: password login is off, but these login users have no
          authorized SSH key: ${lib.concatStringsSep ", " keylessUsers}.
          Set users.users.<name>.openssh.authorizedKeys.keys or .keyFiles, configure
          services.openssh.settings.TrustedUserCAKeys or an AuthorizedKeysCommand, or
          set marchyo.security.ssh.allowNoKeys = true.
        '';
      }
    ];
  };
}
