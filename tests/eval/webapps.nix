{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

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

  entries = hm: hm.xdg.desktopEntries or { };
  binds = hm: hm.wayland.windowManager.hyprland.settings.bindd or [ ];
  hasBind = hm: s: lib.any (b: lib.hasInfix s b) (binds hm);
in
{
  # Webapps on: a .desktop entry is generated per app, launching the browser in
  # --app mode, and apps with a `key` also get a Hyprland bind (default set:
  # ChatGPT on SUPER+SHIFT+A).
  eval-webapps-enabled =
    let
      hm = (evalWith { marchyo.webapps.enable = true; }).config.home-manager.users.testuser;
      chatgpt = (entries hm)."marchyo-webapp-chatgpt" or null;
    in
    pkgs.writeText "eval-webapps-enabled" (
      if
        chatgpt != null
        && lib.hasInfix "--app=https://chatgpt.com/" chatgpt.exec
        && hasBind hm "SUPER SHIFT, A, ChatGPT, exec, "
        && hasBind hm "SUPER SHIFT, A, ChatGPT, exec, google-chrome --app=https://chatgpt.com/"
        # Discord declares no key -> .desktop entry present but no bind.
        && (entries hm) ? "marchyo-webapp-discord"
        && !(hasBind hm "Discord")
      then
        "pass"
      else
        throw "FAIL: webapps enabled but the ChatGPT desktop entry/bind is missing/malformed, or Discord (no key) leaked a bind"
    );

  # Webapps off (default) on a desktop: no webapp desktop entries and no binds.
  eval-webapps-disabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
      keys = builtins.attrNames (entries hm);
    in
    pkgs.writeText "eval-webapps-disabled" (
      if
        !(lib.any (k: lib.hasPrefix "marchyo-webapp-" k) keys) && !(hasBind hm "--app=https://chatgpt.com/")
      then
        "pass"
      else
        throw "FAIL: webapps disabled but a marchyo-webapp-* desktop entry or launch bind is present"
    );

  # Firefox default browser: the module falls back to chromium for --app mode, so
  # the bind and entry both use `chromium --app=`.
  eval-webapps-firefox-fallback =
    let
      hm =
        (evalWith {
          marchyo.webapps.enable = true;
          marchyo.defaults.browser = "firefox";
        }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-webapps-firefox-fallback" (
      if hasBind hm "SUPER SHIFT, A, ChatGPT, exec, chromium --app=https://chatgpt.com/" then
        "pass"
      else
        throw "FAIL: firefox browser but the ChatGPT bind did not fall back to chromium --app"
    );

  # Custom list: overriding apps replaces the default set.
  eval-webapps-custom =
    let
      hm =
        (evalWith {
          marchyo.webapps = {
            enable = true;
            apps = [
              {
                name = "My Site";
                url = "https://example.com/";
              }
            ];
          };
        }).config.home-manager.users.testuser;
      keys = builtins.attrNames (entries hm);
      mine = (entries hm)."marchyo-webapp-my-site" or null;
    in
    pkgs.writeText "eval-webapps-custom" (
      if
        mine != null
        && lib.hasInfix "--app=https://example.com/" mine.exec
        && !(builtins.elem "marchyo-webapp-chatgpt" keys)
      then
        "pass"
      else
        throw "FAIL: custom webapps list did not replace the default entries"
    );
}
