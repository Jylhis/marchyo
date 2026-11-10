{
  helpers,
  lib,
  pkgs,
  ...
}:
let
  inherit (helpers)
    hyprHasBind
    hyprEntriesText
    expect
    ;
  inherit (helpers) ref;

  mkVerifyConfig =
    name: eval:
    let
      hyprlandConfig = eval.config.home-manager.users.testuser.xdg.configFile."hypr/hyprland.lua".source;
      hyprland = eval.config.home-manager.users.testuser.wayland.windowManager.hyprland.package;
    in
    pkgs.runCommand name
      {
        nativeBuildInputs = [ hyprland ];
      }
      ''
        export XDG_RUNTIME_DIR="$(mktemp -d)"
        log=$(mktemp)
        ${hyprland}/bin/hyprland --verify-config --config ${hyprlandConfig} 2>&1 | tee "$log"

        # A clean run prints "config ok"; require it explicitly rather than
        # trusting the exit code, which is 0 even when errors are printed.
        if ! grep -q -F 'config ok' "$log"; then
          echo "FAIL: hyprland --verify-config did not report 'config ok'" >&2
          exit 1
        fi

        # Also grep for error markers. The Lua renderer makes this much
        # stronger than the old hyprlang path: a typo'd `hl.*` name is a nil
        # call that aborts the whole config load instead of being skipped.
        # Keep the patterns specific - the debug preamble legitimately says
        # "Config is lua, loading lua mgr", so a bare /lua/ would false-positive.
        if grep -E -i \
             -e 'invalid dispatcher' \
             -e 'config option <[^>]+> does not exist' \
             -e '^\s*error' \
             -e 'parse error' \
             -e 'attempt to (call|index) a nil value' \
             -e 'lua error' \
             -e 'error loading' \
             "$log"; then
          echo "FAIL: hyprland --verify-config reported config errors (see above)" >&2
          exit 1
        fi

        echo "DONE"
        touch $out
      '';

  settingsOf = c: c.home-manager.users.testuser.wayland.windowManager.hyprland.settings;
  hmOf = c: c.home-manager.users.testuser;
in
{
  # Hyprland config verification (heavy: builds the config and runs Hyprland).
  heavy = {
    # The marchyo.shell.enable = false fallback config.
    check-home-hyprland-config = mkVerifyConfig "check-hyprland-config" (ref "desktop-shell-off");

    # Global workspace numbering (marchyo.workspaces.perMonitor = false, set on
    # desktop-tweaks-3): the per-monitor Lua module is not loaded and the
    # workspace rule returns.
    check-home-hyprland-config-global-workspaces = mkVerifyConfig "check-hyprland-config-global-ws" (
      ref "desktop-tweaks-3"
    );

    # Same verification with the shell on (the desktop default), which adds the
    # curve, animation leaves and per-namespace layer rules.
    check-home-hyprland-config-shell = mkVerifyConfig "check-hyprland-config-shell" (ref "desktop");

    # Appearance options (glassy windows, rounded corners, forced animations
    # plus the pop-out window hook, all set on desktop-tweaks-2) render a config
    # Hyprland accepts.
    check-home-hyprland-config-appearance = mkVerifyConfig "check-hyprland-config-appearance" (
      ref "desktop-tweaks-2"
    );
  };

  refs = {
    desktop = {
      # Shell on: animations run on the popin bezier and the shell namespaces get
      # their per-surface layer rules.
      eval-hyprland-shell-effects =
        c:
        let
          settings = settingsOf c;
          layerRules = hyprEntriesText (settings.layer_rule or [ ]);
          curves = hyprEntriesText (settings.curve or [ ]);
          animations = settings.animation or [ ];
          leaf = name: lib.findFirst (a: (a.leaf or "") == name) { } animations;
          expectedRules = [
            "marchyo:(panel|launcher|osd)"
            "popin 90%"
            "marchyo:bar"
            "marchyo:(notifs|tooltip)"
            "no_anim=true"
            "selection|hyprpicker"
          ];
          missingRules = lib.filter (n: !lib.hasInfix n layerRules) expectedRules;
        in
        if !(settings.config.animations.enabled or false) then
          "shell on should enable Hyprland animations"
        else if !lib.hasInfix "popin" curves then
          "shell on should define the popin bezier curve"
        else if (leaf "windows").bezier or "" != "popin" || (leaf "layers").bezier or "" != "popin" then
          "windows/layers animations should use the popin bezier"
        else if (leaf "workspaces").enabled or true then
          "workspace animations should stay disabled"
        else if missingRules != [ ] then
          "missing shell layer rules: ${toString missingRules}"
        else
          true;

      eval-hyprland-keybindings-cheatsheet =
        c:
        let
          hm = hmOf c;
          hasBind = lib.hasInfix "marchyo:launcher.keys" (
            hyprEntriesText hm.wayland.windowManager.hyprland.settings.bind
          );
          hasPkg = lib.any (p: lib.hasInfix "fzf" (p.name or "")) hm.home.packages;
        in
        expect (hasBind && hasPkg) "keybindings cheat sheet bind or package missing when desktop enabled";

      # The omarchy-style window-management + toggle binds land on desktop and are
      # backed by the window-toggles.nix wrappers.
      eval-hyprland-window-management-binds =
        c:
        let
          hm = hmOf c;
          bind = hm.wayland.windowManager.hyprland.settings.bind;
          bindText = hyprEntriesText bind;
          hasBindText = needle: lib.hasInfix needle bindText;
          hasPkg = name: lib.any (p: lib.hasInfix name (p.name or "")) hm.home.packages;

          # New window-management dispatchers are present, in their Lua spellings.
          newBinds = [
            "hl.dsp.group.toggle()"
            "into_group"
            # Per-monitor workspaces (the default): silent move and workspace move.
            "move_window(1, false)"
            "move_to_monitor("
            "hl.dsp.window.resize({ x = -100"
            "marchyo zoom in"
            "marchyo toggle idle"
            "marchyo toggle caffeine"
            "marchyo capture record"
            "marchyo theme next"
          ];
          missingBinds = lib.filter (n: !hasBindText n) newBinds;

          # All former wrapper scripts are absorbed into the marchyo CLI; the
          # recorder tool closure remains.
          wrappers = [
            "gpu-screen-recorder"
          ];
          missingPkgs = lib.filter (n: !hasPkg n) wrappers;

          # Monitor focus relocated: no SUPER+comma/period focusmonitor bind remains,
          # the CTRL+ALT+Tab focus bind exists, and comma drives notifications.
          focusmonitorMoved = !(hyprHasBind bind "SUPER + comma" "hl.dsp.focus({ monitor");
          hasCtrlAltMonitor = hyprHasBind bind "CTRL + ALT + TAB" ''hl.dsp.focus({ monitor = "+1" })'';
          hasEmoji = hasBindText "Emoji picker";
        in
        if missingBinds != [ ] then
          "missing window-management binds: ${toString missingBinds}"
        else if missingPkgs != [ ] then
          "missing toggle wrapper packages: ${toString missingPkgs}"
        else if !focusmonitorMoved then
          "SUPER+comma focusmonitor bind should have been relocated"
        else if !hasCtrlAltMonitor then
          "CTRL+ALT+Tab monitor-focus bind missing"
        else if !hasEmoji then
          "emoji picker bind missing"
        else
          true;

      # The Super+E editor bind resolves through the `editor` Lua local, which is
      # derived from marchyo.defaults.editor (emacs -> emacsclient by default,
      # and vscode -> code when reselected, as desktop-tweaks-3 does).
      eval-hyprland-editor-bind =
        c:
        let
          defaultSettings = settingsOf c;
          hasEditorBind = hyprHasBind defaultSettings.bind "SUPER + E" "hl.dsp.exec_cmd(editor)";
          defaultEditorVar = defaultSettings.editor._var;
        in
        if !hasEditorBind then
          "Super+E bind should exec the editor local"
        else if defaultEditorVar != "emacsclient -c -a emacs" then
          "default editor local should be emacsclient -c -a emacs, got ${toString defaultEditorVar}"
        else
          true;

      eval-hyprland-wallpaper-enabled =
        c:
        expect (lib.hasInfix "awww-daemon --format xrgb" (hyprEntriesText (settingsOf c).on)) "Hyprland wallpaper startup did not include awww-daemon";
    };

    # Shell off: the fallback stack keeps animations off and gets no curve,
    # animation leaves or shell layer rules.
    desktop-shell-off.eval-hyprland-shell-effects-off =
      c:
      let
        settings = settingsOf c;
        layerRules = hyprEntriesText (settings.layer_rule or [ ]);
      in
      if settings.config.animations.enabled or true then
        "shell off should keep Hyprland animations disabled"
      else if (settings.curve or [ ]) != [ ] || (settings.animation or [ ]) != [ ] then
        "shell off should register no curve or animation leaves"
      else if lib.hasInfix "marchyo:" layerRules || lib.hasInfix "no_anim" layerRules then
        "shell off should register no shell layer rules"
      else
        true;

    desktop-off = {
      # home-manager.users.testuser.marchyo.keybindingsHelp.enable = false.
      eval-hyprland-keybindings-cheatsheet-disabled =
        c:
        expect (
          !(lib.hasInfix "marchyo:launcher.keys" (hyprEntriesText (settingsOf c).bind))
        ) "keybindings cheat sheet bind present when disabled";

      # marchyo.theme.wallpaper.enable = false.
      eval-hyprland-wallpaper-disabled =
        c:
        expect (
          !(lib.hasInfix "awww-daemon" (hyprEntriesText (settingsOf c).on))
        ) "Hyprland wallpaper included awww-daemon when disabled";
    };

    # settings.env entries must render as two-argument hl.env(name, value) calls:
    # a single-table hl.env({...}) call aborts Hyprland's Lua chunk on load and
    # silently drops every setting after it (monitors, window rules, autostarts).
    # A consumer entry in the `_args` shape (desktop-tweaks) must render
    # correctly next to the module defaults, and no env call anywhere in the
    # file may take a table.
    desktop-tweaks.eval-hyprland-env-two-arg-calls =
      c:
      let
        lua = (hmOf c).xdg.configFile."hypr/hyprland.lua".text;
      in
      if !lib.hasInfix ''hl.env("MARCHYO_TEST_ENV", "eval-test")'' lua then
        "consumer env entry did not render as hl.env(\"MARCHYO_TEST_ENV\", \"eval-test\")"
      else if lib.hasInfix "hl.env({" lua then
        "rendered Hyprland config contains a single-table hl.env({...}) call"
      else
        true;

    # ... and vscode -> code (desktop-tweaks-3: editor = "vscode").
    desktop-tweaks-3.eval-hyprland-editor-bind-vscode =
      c:
      let
        var = (settingsOf c).editor._var;
      in
      expect (var == "code") "editor local for vscode should be code, got ${toString var}";
  };

  refConfig = {
    desktop-off = {
      home-manager.users.testuser.marchyo.keybindingsHelp.enable = false;
      marchyo.theme.wallpaper.enable = false;
    };
    desktop-tweaks.home-manager.users.testuser.wayland.windowManager.hyprland.settings.env = [
      {
        _args = [
          "MARCHYO_TEST_ENV"
          "eval-test"
        ];
      }
    ];
  };

  # The legacy hyprlang `{ n, v }` env shape is rejected at eval time by the
  # assertion in modules/home/hyprland.nix instead of aborting the Lua chunk
  # at runtime. Home Manager propagates the user assertion to the system
  # level, so this is the failure a consumer sees from nixos-rebuild.
  failing.eval-hyprland-env-legacy-shape-rejected = {
    on = "misconfigured";
    expect = "settings.env entries must be two-argument calls";
  };

  failingConfig.misconfigured.home-manager.users.testuser.wayland.windowManager.hyprland.settings.env =
    [
      {
        n = "AQ_DRM_DEVICES";
        v = "/dev/dri/by-path/pci-0000:03:00.0-card";
      }
    ];
}
