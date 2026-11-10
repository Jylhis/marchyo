# The captive-portal check: NetworkManager connectivity polling plus the
# sign-in window rule. desktop-tweaks-2 sets a custom endpoint, desktop-off
# turns the check off.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprEntriesText;

  hmOf = c: c.home-manager.users.testuser;
  connectivity = c: c.networking.networkmanager.settings.connectivity or null;
  ruleText = hm: hyprEntriesText (hm.wayland.windowManager.hyprland.settings.window_rule or [ ]);
  hasRule = hm: lib.hasInfix "nmcheck[.]gnome[.]org__" (ruleText hm);
  portalConfig = hm: hm.xdg.configFile."marchyo/captive-portal.json".text or null;
in
{
  refs = {
    desktop = {
      # Default-on with desktop: NetworkManager polls the GNOME endpoint, and the
      # sign-in window class floats at 900x760.
      eval-captive-portal-default =
        cfg:
        let
          eval = cfg;
          c = connectivity eval;
          hm = hmOf eval;
        in
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
          true
        else
          "captive-portal defaults: NM connectivity settings, window rule, or config file are wrong";
    };

    desktop-tweaks-2 = {
      # Custom endpoint: settings and the window class follow the option values.
      eval-captive-portal-custom =
        cfg:
        let
          eval = cfg;
          c = connectivity eval;
        in
        if
          c.uri == "http://ping.example.org/nm-check.txt"
          && c.response == ""
          && c.interval == "60"
          && lib.hasInfix "ping[.]example[.]org__" (ruleText (hmOf eval))
          && !(hasRule (hmOf eval))
        then
          true
        else
          "captive-portal custom uri/response/interval not applied";
    };

    desktop-off = {
      # Opt-out: no NM connectivity block, no window rule, no config file.
      eval-captive-portal-disabled =
        cfg:
        let
          eval = cfg;
          hm = hmOf eval;
        in
        if connectivity eval == null && !(hasRule hm) && portalConfig hm == null then
          true
        else
          "captive-portal disabled but NM settings, window rule, or config file remain";
    };

    headless = {
      # Headless host: the check is off without the desktop.
      eval-captive-portal-headless =
        cfg:
        let
          eval = cfg;
        in
        if connectivity eval == null then
          true
        else
          "connectivity check enabled without marchyo.desktop.enable";
    };
  };

  refConfig = {
    desktop-tweaks-2.marchyo.network.connectivityCheck = {
      uri = "http://ping.example.org/nm-check.txt";
      response = "";
      interval = 60;
    };
    desktop-off.marchyo.network.connectivityCheck.enable = false;
  };
}
