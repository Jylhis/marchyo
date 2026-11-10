# Web apps: the default set, the opt-out, browser fallback, custom lists,
# presets and the default email client. The reference systems' settings are in
# refConfig at the bottom; the notion-without-unfree case is a variant
# because it turns allowUnfree off for the whole system.
{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers) hyprHasBind hyprEntriesText;

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
  refs = {
    desktop = {
      # Webapps ride the desktop cascade (default-on): a plain desktop config gets a
      # .desktop entry per app, launching the browser in --app mode, and apps with a
      # `key` also get a Hyprland bind (default set: ChatGPT on SUPER+SHIFT+A).
      eval-webapps-enabled =
        c:
        let
          hm = c.home-manager.users.testuser;
          chatgpt = (entries hm)."marchyo-webapp-chatgpt" or null;
        in
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
          true
        else
          "desktop default webapps set is missing an entry/bind, or a keyless app leaked a bind";

      # Presets are off by default: no Microsoft 365 or Notion entries, no native
      # Notion package.
      eval-webapps-presets-off =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if
          !((entries hm) ? "marchyo-webapp-outlook")
          && !((entries hm) ? "marchyo-webapp-notion")
          && !((entries hm) ? "marchyo-webapp-google-drive")
          && !(lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages)
        then
          true
        else
          "webapp presets are off by default but a preset entry or package is present";
    };

    desktop-off = {
      # Explicit opt-out overrides the desktop cascade: no webapp desktop entries
      # and no launch binds.
      eval-webapps-disabled =
        c:
        let
          hm = c.home-manager.users.testuser;
          keys = builtins.attrNames (entries hm);
        in
        if
          !(lib.any (k: lib.hasPrefix "marchyo-webapp-" k) keys)
          && !(hasBindText hm "--app=https://chatgpt.com/")
        then
          true
        else
          "webapps disabled but a marchyo-webapp-* desktop entry or launch bind is present";
    };

    desktop-tweaks-3 = {
      # Firefox default browser: the module falls back to chromium for --app mode, so
      # the bind and entry both use `chromium --app=`.
      eval-webapps-firefox-fallback =
        c:
        let
          hm = c.home-manager.users.testuser;
        in
        if hasBind hm "SUPER + SHIFT + A" "chromium --app=https://chatgpt.com/" then
          true
        else
          "firefox browser but the ChatGPT bind did not fall back to chromium --app";
    };

    desktop-tweaks-2 = {
      # Custom list: overriding apps replaces the default set.
      eval-webapps-custom =
        c:
        let
          hm = c.home-manager.users.testuser;
          keys = builtins.attrNames (entries hm);
          mine = (entries hm)."marchyo-webapp-my-site" or null;
        in
        if
          mine != null
          && lib.hasInfix "--app=https://example.com/" mine.exec
          && !(builtins.elem "marchyo-webapp-chatgpt" keys)
        then
          true
        else
          "custom webapps list did not replace the default entries";

      # m365 adds six app-mode entries that carry no launch bind.
      eval-webapps-presets-m365 =
        c:
        let
          hm = c.home-manager.users.testuser;
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
        if
          lib.all (n: entryOk n expected.${n}) (builtins.attrNames expected)
          && !(hasBindText hm "outlook.office.com")
          && !(hasBindText hm "onedrive")
        then
          true
        else
          "m365 preset entries missing, wrongly targeted, or carrying a launch bind";

      # With unfree allowed on x86_64-linux, notion installs the native app and no
      # web app entry. Other platforms keep the web app.
      eval-webapps-presets-notion-native =
        c:
        let
          hm = c.home-manager.users.testuser;
          native = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
          hasNative = lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages;
          hasWebapp = (entries hm) ? "marchyo-webapp-notion";
        in
        if hasNative == native && hasWebapp == !native then
          true
        else
          "notion preset with unfree picked the wrong branch for this platform";
    };

    desktop-tweaks-4 = {
      # The selected web email client is registered without a preset.
      eval-webapps-email-client =
        c:
        let
          # desktop-tweaks-4: email = "outlook".
          outlook = c.home-manager.users.testuser;
        in
        if
          (entries outlook) ? "marchyo-webapp-outlook"
          && lib.hasInfix "--app=https://outlook.office.com/mail/" (entries outlook)
          .marchyo-webapp-outlook.exec
        then
          true
        else
          "defaults.email = outlook did not register its web app";

      # google adds thirteen app-mode entries that carry no launch bind.
      eval-webapps-presets-google =
        c:
        let
          hm = c.home-manager.users.testuser;
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
        if
          lib.all (n: entryOk n expected.${n}) (builtins.attrNames expected)
          && !(hasBindText hm "drive.google.com")
          && !(hasBindText hm "docs.google.com")
        then
          true
        else
          "google preset entries missing, wrongly targeted, or carrying a launch bind";
    };

    # The other email clients: gmail (desktop-tweaks-3) registers its web app,
    # aerc (desktop-tweaks) registers none.
    desktop-tweaks-3.eval-webapps-email-client-gmail =
      c: (entries c.home-manager.users.testuser) ? "marchyo-webapp-gmail";
    desktop-tweaks.eval-webapps-email-client-aerc =
      c: !((entries c.home-manager.users.testuser) ? "marchyo-webapp-outlook");
  };

  refConfig = {
    desktop-off.marchyo.webapps.enable = false;
    desktop-tweaks-2.marchyo.webapps = {
      apps = [
        {
          name = "My Site";
          url = "https://example.com/";
        }
      ];
      presets.m365.enable = true;
      presets.notion.enable = true;
    };
    desktop-tweaks-4 = {
      marchyo.defaults.email = "outlook";
      marchyo.webapps.presets.google.enable = true;
    };
  };

  # notion without unfree (the default) falls back to a web app and installs
  # no package.
  variants.webapps-notion-no-unfree = {
    config = helpers.desktopWith {
      marchyo.webapps.presets.notion.enable = true;
      nixpkgs.config.allowUnfree = lib.mkForce false;
    };
    predicates.eval-webapps-presets-notion-webapp =
      c:
      let
        hm = c.home-manager.users.testuser;
        entry = (entries hm)."marchyo-webapp-notion" or null;
      in
      if
        entry != null
        && lib.hasInfix "--app=https://www.notion.so/" entry.exec
        && !(lib.any (p: (p.pname or "") == "notion-app-enhanced") hm.home.packages)
      then
        true
      else
        "notion preset without unfree did not produce the Notion web app";
  };
}
