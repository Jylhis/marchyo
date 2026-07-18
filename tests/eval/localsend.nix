{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) testNixOSCheck withTestUser;

  hasLocalsend = cfg: builtins.any (p: lib.getName p == "localsend") cfg.environment.systemPackages;
  tcpOpen = cfg: builtins.elem 53317 cfg.networking.firewall.allowedTCPPorts;
  udpOpen = cfg: builtins.elem 53317 cfg.networking.firewall.allowedUDPPorts;

  dconfPath = "com/github/stunkymonkey/nautilus-open-any-terminal";
  scriptPath = ".local/share/nautilus/scripts/Send with LocalSend";

  # Full desktop eval with the Home-Manager modules wired, for inspecting the
  # per-user nautilus integration (same pattern as tests/eval/webapps.nix).
  evalHome =
    extra:
    (lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    }).config.home-manager.users.testuser;
in
{
  # Desktop default: localsend ships and its port is open (TCP + UDP).
  eval-localsend-desktop-default =
    testNixOSCheck "localsend-desktop-default" (cfg: hasLocalsend cfg && tcpOpen cfg && udpOpen cfg)
      (withTestUser {
        marchyo.desktop.enable = true;
      });

  # Opting out keeps the desktop but drops the package and the open port.
  eval-localsend-disabled =
    testNixOSCheck "localsend-disabled" (cfg: !(hasLocalsend cfg) && !(tcpOpen cfg) && !(udpOpen cfg))
      (withTestUser {
        marchyo.desktop.enable = true;
        marchyo.services.localsend.enable = false;
      });

  # Headless host: the sub-toggle defaults to true, but without the desktop
  # nothing installs and no port opens.
  eval-localsend-headless = testNixOSCheck "localsend-headless" (
    cfg: !(hasLocalsend cfg) && !(tcpOpen cfg) && !(udpOpen cfg)
  ) (withTestUser { });

  # Nautilus (the default file manager) gets the ghostty open-terminal dconf
  # key and the "Send with LocalSend" script.
  eval-nautilus-integration =
    let
      hm = evalHome { };
      terminal = (hm.dconf.settings.${dconfPath} or { }).terminal or null;
      # The dconf module's gvariant type may keep plain strings or wrap them;
      # require the key to be set, and when it is a bare string, be "ghostty".
      terminalOk = terminal != null && (!lib.isString terminal || terminal == "ghostty");
    in
    pkgs.writeText "eval-nautilus-integration" (
      if terminalOk && hm.home.file ? ${scriptPath} then
        "pass"
      else
        throw "FAIL: nautilus integration missing the ghostty dconf key or the LocalSend script"
    );

  # A non-nautilus file manager gets neither the dconf key nor the script.
  eval-nautilus-disabled =
    let
      hm = evalHome { marchyo.defaults.fileManager = "thunar"; };
    in
    pkgs.writeText "eval-nautilus-disabled" (
      if !(hm.dconf.settings ? ${dconfPath}) && !(hm.home.file ? ${scriptPath}) then
        "pass"
      else
        throw "FAIL: nautilus integration leaked into a thunar desktop"
    );
}
