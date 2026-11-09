{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser hyprHasBind hyprEntriesText;

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
  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  # Substring search over every rendered bind, for "no bind mentions X" checks.
  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));

  # Mirror the browser default from modules/nixos/defaults.nix: google-chrome is
  # x86_64-only on Linux, so non-x86_64 platforms fall back to chromium. The
  # webapps launch command follows marchyo.defaults.browser, so the expected
  # bind string is arch-dependent.
  browser = if pkgs.stdenv.hostPlatform.isx86_64 then "google-chrome" else "chromium";
in
{
  # Webapps ride the desktop cascade (default-on): a plain desktop config gets a
  # .desktop entry per app, launching the browser in --app mode, and apps with a
  # `key` also get a Hyprland bind (default set: ChatGPT on SUPER+SHIFT+A).
  eval-webapps-enabled =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
      chatgpt = (entries hm)."marchyo-webapp-chatgpt" or null;
    in
    pkgs.writeText "eval-webapps-enabled" (
      if
        chatgpt != null
        && lib.hasInfix "--app=https://chatgpt.com/" chatgpt.exec
        && hasBind hm "SUPER + SHIFT + A" "ChatGPT"
        && hasBind hm "SUPER + SHIFT + A" "${browser} --app=https://chatgpt.com/"
        # Discord declares no key -> .desktop entry present but no bind.
        && (entries hm) ? "marchyo-webapp-discord"
        && !(hasBindText hm "Discord")
        # Parity round-out: X and Google Photos ship with binds...
        && (entries hm) ? "marchyo-webapp-x"
        && hasBind hm "SUPER + SHIFT + X" "${browser} --app=https://x.com/"
        && hasBind hm "SUPER + SHIFT + P" "${browser} --app=https://photos.google.com/"
        # ...Google Calendar and Gmail are entries only (no key).
        && (entries hm) ? "marchyo-webapp-google-calendar"
        && (entries hm) ? "marchyo-webapp-gmail"
        && !(hasBindText hm "Gmail")
        && !(hasBindText hm "Google Calendar")
      then
        "pass"
      else
        throw "FAIL: desktop default webapps set is missing an entry/bind, or a keyless app leaked a bind"
    );

  # Explicit opt-out overrides the desktop cascade: no webapp desktop entries
  # and no launch binds.
  eval-webapps-disabled =
    let
      hm = (evalWith { marchyo.webapps.enable = false; }).config.home-manager.users.testuser;
      keys = builtins.attrNames (entries hm);
    in
    pkgs.writeText "eval-webapps-disabled" (
      if
        !(lib.any (k: lib.hasPrefix "marchyo-webapp-" k) keys)
        && !(hasBindText hm "--app=https://chatgpt.com/")
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
      if hasBind hm "SUPER + SHIFT + A" "chromium --app=https://chatgpt.com/" then
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

  # Presets are off by default: no Microsoft 365 or Notion entries, no native
  # Notion package.
  eval-webapps-presets-off =
    let
      hm = (evalWith { }).config.home-manager.users.testuser;
    in
    pkgs.writeText "eval-webapps-presets-off" (
      if
        !((entries hm) ? "marchyo-webapp-outlook")
        && !((entries hm) ? "marchyo-webapp-notion")
        && !((entries hm) ? "marchyo-webapp-google-drive")
        && !(lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages)
      then
        "pass"
      else
        throw "FAIL: webapp presets are off by default but a preset entry or package is present"
    );

  # m365 adds six app-mode entries that carry no launch bind.
  eval-webapps-presets-m365 =
    let
      hm = (evalWith { marchyo.webapps.presets.m365.enable = true; }).config.home-manager.users.testuser;
      expected = {
        marchyo-webapp-outlook = "https://outlook.office.com/mail/";
        marchyo-webapp-word = "https://word.cloud.microsoft/";
        marchyo-webapp-excel = "https://excel.cloud.microsoft/";
        marchyo-webapp-powerpoint = "https://powerpoint.cloud.microsoft/";
        marchyo-webapp-teams = "https://teams.cloud.microsoft/";
        marchyo-webapp-onedrive = "https://www.office.com/launch/onedrive";
      };
      entryOk =
        name: url: (entries hm) ? ${name} && lib.hasInfix "--app=${url}" (entries hm).${name}.exec;
    in
    pkgs.writeText "eval-webapps-presets-m365" (
      if
        lib.all (n: entryOk n expected.${n}) (builtins.attrNames expected)
        && !(hasBindText hm "outlook.office.com")
        && !(hasBindText hm "onedrive")
      then
        "pass"
      else
        throw "FAIL: m365 preset entries missing, mis-targeted, or carrying a launch bind"
    );

  # The selected web email client is registered without a preset.
  eval-webapps-email-client =
    let
      hmOf = e: (evalWith { marchyo.defaults.email = e; }).config.home-manager.users.testuser;
      outlook = hmOf "outlook";
      aerc = hmOf "aerc";
    in
    pkgs.writeText "eval-webapps-email-client" (
      if
        (entries outlook) ? "marchyo-webapp-outlook"
        && lib.hasInfix "--app=https://outlook.office.com/mail/" (entries outlook).marchyo-webapp-outlook.exec
        && (entries (hmOf "gmail")) ? "marchyo-webapp-gmail"
        && !((entries aerc) ? "marchyo-webapp-outlook")
      then
        "pass"
      else
        throw "FAIL: defaults.email did not register its web app (or aerc registered Outlook)"
    );

  # google adds thirteen app-mode entries that carry no launch bind.
  eval-webapps-presets-google =
    let
      hm =
        (evalWith { marchyo.webapps.presets.google.enable = true; }).config.home-manager.users.testuser;
      expected = {
        marchyo-webapp-gmail = "https://mail.google.com/";
        marchyo-webapp-google-calendar = "https://calendar.google.com/";
        marchyo-webapp-google-drive = "https://drive.google.com/";
        marchyo-webapp-google-docs = "https://docs.google.com/document/";
        marchyo-webapp-google-sheets = "https://docs.google.com/spreadsheets/";
        marchyo-webapp-google-slides = "https://docs.google.com/presentation/";
        marchyo-webapp-google-meet = "https://meet.google.com/";
        marchyo-webapp-google-chat = "https://chat.google.com/";
        marchyo-webapp-google-keep = "https://keep.google.com/";
        marchyo-webapp-google-forms = "https://docs.google.com/forms/";
        marchyo-webapp-google-sites = "https://sites.google.com/";
        marchyo-webapp-google-contacts = "https://contacts.google.com/";
        marchyo-webapp-google-tasks = "https://tasks.google.com/";
      };
      entryOk =
        name: url: (entries hm) ? ${name} && lib.hasInfix "--app=${url}" (entries hm).${name}.exec;
    in
    pkgs.writeText "eval-webapps-presets-google" (
      if
        lib.all (n: entryOk n expected.${n}) (builtins.attrNames expected)
        && !(hasBindText hm "drive.google.com")
        && !(hasBindText hm "docs.google.com")
      then
        "pass"
      else
        throw "FAIL: google preset entries missing, mis-targeted, or carrying a launch bind"
    );

  # notion without unfree (the default) falls back to a web app and installs no
  # package.
  eval-webapps-presets-notion-webapp =
    let
      hm =
        (evalWith {
          marchyo.webapps.presets.notion.enable = true;
          nixpkgs.config.allowUnfree = lib.mkForce false;
        }).config.home-manager.users.testuser;
      entry = (entries hm)."marchyo-webapp-notion" or null;
    in
    pkgs.writeText "eval-webapps-presets-notion-webapp" (
      if
        entry != null
        && lib.hasInfix "--app=https://www.notion.so/" entry.exec
        && !(lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages)
      then
        "pass"
      else
        throw "FAIL: notion preset without unfree did not produce the Notion web app"
    );

  # With unfree allowed on x86_64-linux, notion installs the native app and no
  # web app entry. Other platforms keep the web app.
  eval-webapps-presets-notion-native =
    let
      hm =
        (evalWith {
          marchyo.webapps.presets.notion.enable = true;
          nixpkgs.config.allowUnfree = true;
        }).config.home-manager.users.testuser;
      native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      hasNative = lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages;
      hasWebapp = (entries hm) ? "marchyo-webapp-notion";
    in
    pkgs.writeText "eval-webapps-presets-notion-native" (
      if hasNative == native && hasWebapp == !native then
        "pass"
      else
        throw "FAIL: notion preset with unfree picked the wrong branch for this platform"
    );
}
