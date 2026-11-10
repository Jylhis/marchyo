# The screensaver: default-on with the desktop, opt-out (desktop-off:
# marchyo.screensaver.enable = false), and its lock guard with the shell on and off.
{ helpers, lib, ... }:
let
  inherit (helpers) hyprEntriesText;
  hmOf = c: c.home-manager.users.testuser;
  hasPkg = hm: n: lib.any (p: (p.name or "") == n) hm.home.packages;
  listeners = hm: hm.services.hypridle.settings.listener or [ ];
  hasListener = hm: lib.any (l: (l.on-timeout or "") == "marchyo-screensaver-launch") (listeners hm);
  hasRule =
    hm:
    lib.hasInfix "org.omarchy.screensaver" (
      hyprEntriesText (hm.wayland.windowManager.hyprland.settings.window_rule or [ ])
    );
in
{
  refs = {
    desktop = {
      # Default-on with desktop: both scripts installed, the hypridle idle
      # listener wired, and the fullscreen window rule contributed.
      eval-screensaver-enabled =
        c:
        let
          hm = hmOf c;
        in
        if
          hasPkg hm "marchyo-screensaver"
          && hasPkg hm "marchyo-screensaver-launch"
          && hasListener hm
          && hasRule hm
        then
          true
        else
          "screensaver default-on with desktop but its scripts, hypridle listener, or window rule are missing";

      # Phase 4: with the unified shell on, the launcher must guard against the
      # in-shell lock the same way it guards against hyprlock — visible as the
      # `marchyo shell lock-state` probe inside the launcher script (read from the derivation's
      # eval-visible `text` attr; the flake disables import-from-derivation).
      eval-screensaver-shell-lock-guard =
        c:
        let
          hm = hmOf c;
          launcher = lib.findFirst (p: (p.name or "") == "marchyo-screensaver-launch") null hm.home.packages;
          text = if launcher == null then "" else (launcher.text or "");
        in
        if launcher != null && lib.hasInfix "marchyo shell lock-state" text then
          true
        else
          "marchyo.shell is on but the screensaver launcher does not probe the shell lock state";
    };

    desktop-off = {
      # Opt-out: no screensaver scripts and no idle listener, while the other
      # hypridle listeners (dim/lock/dpms) stay in place.
      eval-screensaver-disabled =
        c:
        let
          hm = hmOf c;
        in
        if
          !(hasPkg hm "marchyo-screensaver") && !(hasListener hm) && !(hasRule hm) && listeners hm != [ ]
        then
          true
        else
          "screensaver disabled but its script, window rule, or hypridle listener is still present";
    };

    desktop-shell-off = {
      # Shell off: the launcher keeps its plain hyprlock guard only (no CLI
      # dependency, no shell lock-state probe).
      eval-screensaver-shell-off-no-ipc-probe =
        c:
        let
          hm = hmOf c;
          launcher = lib.findFirst (p: (p.name or "") == "marchyo-screensaver-launch") null hm.home.packages;
          text = if launcher == null then "" else (launcher.text or "");
        in
        if launcher != null && !(lib.hasInfix "lock-state" text) then
          true
        else
          "marchyo.shell is off but the screensaver launcher still probes (or misses) the shell lock state";
    };
  };

  refConfig.desktop-off.marchyo.screensaver.enable = false;
}
