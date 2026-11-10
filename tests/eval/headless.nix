# Headless / server path: marchyo's NixOS module (with a marchyo user, so the
# full modules/home set is imported) must produce NO Wayland desktop-shell
# config when marchyo.desktop.enable is off. This is what lets a headless host
# build through lib.mkNixosSystem + marchyo.users.* instead of opting out of
# marchyo's HM entirely.
{ helpers, lib, ... }:
let
  inherit (helpers) expect;
  hmOf = c: c.home-manager.users.testuser;
  hyprConfig = c: (hmOf c).wayland.windowManager.hyprland.settings.config;
in
{
  refs = {
    headless = {
      # desktop disabled => the Wayland shell modules are all inert.
      eval-headless-no-wayland =
        c:
        let
          hm = hmOf c;
          offenders =
            lib.optional hm.wayland.windowManager.hyprland.enable "hyprland"
            ++ lib.optional hm.programs.hyprlock.enable "hyprlock"
            ++ lib.optional hm.services.hypridle.enable "hypridle"
            ++ lib.optional (hm.systemd.user.services ? marchyo-shell) "marchyo-shell";
        in
        expect (
          offenders == [ ]
        ) "desktop disabled but these are still enabled in HM: ${lib.concatStringsSep ", " offenders}";

      # The NixOS half of the same contract. The tests above only inspect Home
      # Manager, which is why modules/nixos/{hyprland,printing,hyprlock,_1password}
      # and hardware.nix's bluetooth stanza went on enabling themselves on headless
      # hosts unnoticed.
      eval-headless-no-desktop-services =
        cfg:
        let
          offenders =
            lib.optional cfg.programs.hyprland.enable "programs.hyprland"
            ++ lib.optional cfg.programs.hyprlock.enable "programs.hyprlock"
            ++ lib.optional cfg.xdg.portal.enable "xdg.portal"
            ++ lib.optional cfg.services.printing.enable "services.printing"
            ++ lib.optional cfg.services.colord.enable "services.colord"
            ++ lib.optional cfg.hardware.bluetooth.enable "hardware.bluetooth"
            ++ lib.optional cfg.programs._1password-gui.enable "programs._1password-gui";
        in
        expect (
          offenders == [ ]
        ) "desktop disabled but these are still enabled: ${lib.concatStringsSep ", " offenders}";
    };

    desktop = {
      # desktop enabled => the same modules ARE configured (the guard does not
      # over-gate the normal desktop path): the shell by default, hyprlock as the
      # marchyo.shell.enable = false fallback.
      eval-desktop-enables-wayland =
        c:
        let
          hm = hmOf c;
        in
        expect (
          hm.wayland.windowManager.hyprland.enable && hm.systemd.user.services ? marchyo-shell
        ) "desktop enabled but hyprland/marchyo-shell were not configured";

      # The cursor hides on key press (typing) — and because every screenshot bind
      # is a keyboard bind, this also keeps the cursor out of grimblast captures.
      eval-hyprland-hides-cursor-on-key-press =
        c:
        expect (
          (hyprConfig c).cursor.hide_on_key_press or false == true
        ) "cursor.hide_on_key_press is not true";

      # Non-KMS dmabuf formats stay in the feedback so hotplug keeps Mesa clients connected.
      eval-hyprland-keeps-non-kms-dmabuf-formats =
        c:
        expect (
          ((hyprConfig c).quirks.skip_non_kms_dmabuf_formats or true) == false
        ) "quirks.skip_non_kms_dmabuf_formats is not false";

      # A restarted shell can take back a session lock its predecessor held
      # (Services/Lock.qml stranded-lock recovery).
      eval-hyprland-allows-session-lock-restore =
        c:
        expect (
          (hyprConfig c).misc.allow_session_lock_restore or false == true
        ) "misc.allow_session_lock_restore is not true";

      eval-desktop-enables-services =
        cfg:
        cfg.programs.hyprland.enable
        && cfg.xdg.portal.enable
        && cfg.services.printing.enable
        && cfg.hardware.bluetooth.enable;
    };

    # Overridability: with the desktop on, a consumer must be able to turn an
    # individual service off without lib.mkForce (desktop-off). Before the
    # mkDefault sweep this was a "conflicting definition values" eval error.
    desktop-off.eval-desktop-services-overridable =
      cfg: !cfg.services.printing.enable && !cfg.hardware.bluetooth.enable;

    # The marchyo.shell.enable = false fallback: hyprland with hyprlock.
    desktop-shell-off.eval-desktop-enables-wayland-shell-off =
      c:
      let
        hm = hmOf c;
      in
      expect (
        hm.wayland.windowManager.hyprland.enable && hm.programs.hyprlock.enable
      ) "desktop enabled with the shell off but hyprland/hyprlock were not configured";
  };

  refConfig.desktop-off = {
    services.printing.enable = false;
    hardware.bluetooth.enable = false;
  };
}
