{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprEntriesText;

  evalWith =
    extra:
    lib.nixosSystem {
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
    };

  hmOf = eval: eval.config.home-manager.users.testuser;
  connectivity = eval: eval.config.networking.networkmanager.settings.connectivity or null;
  ruleText = hm: hyprEntriesText (hm.wayland.windowManager.hyprland.settings.window_rule or [ ]);
  hasRule = hm: lib.hasInfix "nmcheck[.]gnome[.]org__" (ruleText hm);
  portalConfig = hm: hm.xdg.configFile."marchyo/captive-portal.json".text or null;
in
{
  # Default-on with desktop: NetworkManager polls the GNOME endpoint, and the
  # sign-in window class floats at 900x760.
  eval-captive-portal-default =
    let
      eval = evalWith { };
      c = connectivity eval;
      hm = hmOf eval;
    in
    pkgs.writeText "eval-captive-portal-default" (
      if
        c != null
        && c.uri == "http://nmcheck.gnome.org/check_network_status.txt"
        && c.response == "NetworkManager is online"
        && c.interval == "300"
        && hasRule hm
        && lib.hasInfix "900" (ruleText hm)
        && lib.hasInfix "760" (ruleText hm)
        && lib.hasInfix "nmcheck.gnome.org" (portalConfig hm)
      then
        "pass"
      else
        throw "FAIL: captive-portal defaults: NM connectivity settings, window rule, or config file are wrong"
    );

  # Custom endpoint: settings and the window class follow the option values.
  eval-captive-portal-custom =
    let
      eval = evalWith {
        marchyo.network.connectivityCheck = {
          uri = "http://ping.example.org/nm-check.txt";
          response = "";
          interval = 60;
        };
      };
      c = connectivity eval;
    in
    pkgs.writeText "eval-captive-portal-custom" (
      if
        c.uri == "http://ping.example.org/nm-check.txt"
        && c.response == ""
        && c.interval == "60"
        && lib.hasInfix "ping[.]example[.]org__" (ruleText (hmOf eval))
        && !(hasRule (hmOf eval))
      then
        "pass"
      else
        throw "FAIL: captive-portal custom uri/response/interval not applied"
    );

  # Opt-out: no NM connectivity block, no window rule, no config file.
  eval-captive-portal-disabled =
    let
      eval = evalWith { marchyo.network.connectivityCheck.enable = false; };
      hm = hmOf eval;
    in
    pkgs.writeText "eval-captive-portal-disabled" (
      if connectivity eval == null && !(hasRule hm) && portalConfig hm == null then
        "pass"
      else
        throw "FAIL: captive-portal disabled but NM settings, window rule, or config file remain"
    );

  # Headless host: the check is off without the desktop.
  eval-captive-portal-headless =
    let
      eval = lib.nixosSystem {
        inherit (pkgs.stdenv.hostPlatform) system;
        modules = [
          nixosModules
          (withTestUser { })
        ];
      };
    in
    pkgs.writeText "eval-captive-portal-headless" (
      if connectivity eval == null then
        "pass"
      else
        throw "FAIL: connectivity check enabled without marchyo.desktop.enable"
    );
}
