{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  hasLocalsend = cfg: builtins.any (p: lib.getName p == "localsend") cfg.environment.systemPackages;
  tcpOpen = cfg: builtins.elem 53317 cfg.networking.firewall.allowedTCPPorts;
  udpOpen = cfg: builtins.elem 53317 cfg.networking.firewall.allowedUDPPorts;

  dconfPath = "com/github/stunkymonkey/nautilus-open-any-terminal";
  scriptPath = ".local/share/nautilus/scripts/Send with LocalSend";
in
{
  refs = {
    desktop = {
      # Desktop default: localsend ships through programs.localsend and its port
      # is open (TCP + UDP).
      eval-localsend-desktop-default =
        cfg: cfg.programs.localsend.enable && hasLocalsend cfg && tcpOpen cfg && udpOpen cfg;

      # Nautilus (the default file manager) gets the ghostty open-terminal dconf
      # key and the "Send with LocalSend" script.
      eval-nautilus-integration =
        cfg:
        let
          hm = cfg.home-manager.users.testuser;
          terminal = (hm.dconf.settings.${dconfPath} or { }).terminal or null;
          # The dconf module's gvariant type may keep plain strings or wrap them;
          # require the key to be set, and when it is a bare string, be "ghostty".
          terminalOk = terminal != null && (!lib.isString terminal || terminal == "ghostty");
        in
        helpers.expect (
          terminalOk && hm.home.file ? ${scriptPath}
        ) "nautilus integration missing the ghostty dconf key or the LocalSend script";
    };

    # openFirewall = false keeps the app (send-only) and closes the port
    # (desktop-tweaks).
    desktop-tweaks.eval-localsend-firewall-closed =
      cfg: hasLocalsend cfg && !(tcpOpen cfg) && !(udpOpen cfg);

    # Opting out keeps the desktop but drops the package and the open port
    # (desktop-off: programs.localsend.enable = false).
    desktop-off.eval-localsend-disabled = cfg: !(hasLocalsend cfg) && !(tcpOpen cfg) && !(udpOpen cfg);

    # Headless host: without the desktop nothing installs and no port opens.
    headless.eval-localsend-headless = cfg: !(hasLocalsend cfg) && !(tcpOpen cfg) && !(udpOpen cfg);

    # A non-nautilus file manager (desktop-tweaks-3: fileManager = "thunar")
    # gets neither the dconf key nor the script.
    desktop-tweaks-3.eval-nautilus-disabled =
      cfg:
      let
        hm = cfg.home-manager.users.testuser;
      in
      helpers.expect (
        !(hm.dconf.settings ? ${dconfPath}) && !(hm.home.file ? ${scriptPath})
      ) "nautilus integration leaked into a thunar desktop";
  };

  refConfig = {
    desktop-tweaks.programs.localsend.openFirewall = false;
    desktop-off.programs.localsend.enable = false;
  };

  # The "Send with LocalSend" script launches the real LocalSend binary
  # (localsend_app, the package's mainProgram). Reading the script means
  # building it, so this is a heavy check.
  heavy.eval-nautilus-localsend-exe =
    let
      script = (helpers.ref "desktop").config.home-manager.users.testuser.home.file.${scriptPath}.source;
      exe = lib.getExe pkgs.localsend;
    in
    pkgs.runCommand "eval-nautilus-localsend-exe" { } ''
      if grep -qF '${exe}' '${script}'; then
        echo pass > "$out"
      else
        echo "FAIL: ${scriptPath} does not run ${exe}" >&2
        exit 1
      fi
    '';
}
