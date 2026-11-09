# Evaluation tests for modules/home/omarchy-binds.nix (monitor
# controls, connectivity TUIs, app-launch binds).
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
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  hmFor = eval: eval.config.home-manager.users.testuser;
  binds = hm: hm.wayland.windowManager.hyprland.settings.bind or [ ];
  hasBind = hm: hyprHasBind (binds hm);
  # Substring search over every rendered bind, for "no bind mentions X" checks.
  hasBindText = hm: s: lib.hasInfix s (hyprEntriesText (binds hm));
  hasPackage = hm: n: lib.any (p: lib.getName p == n) hm.home.packages;

  # Chords deliberately bound twice: Hyprland runs every bind for a chord in
  # order, and these pair a window cycle with a raise (lib/keybinds.nix,
  # "Cycle to next window" / "Reveal active window on top"). Anything else
  # bound twice is two features fighting over one chord. Chords compare with
  # modifiers in any order.
  duplicateChords =
    hm:
    helpers.duplicateChords [
      "ALT + Tab"
      "ALT + SHIFT + Tab"
      # Push-to-talk: one bind on press (start), one on release (stop).
      "F9"
    ] (binds hm);
in
{
  # Desktop + development on: monitor-control, connectivity, and app-launch
  # binds are all present, and the backing scripts + tmux land in the profile.
  eval-omarchy-binds-enabled =
    let
      hm = hmFor (evalWith {
        marchyo.desktop.enable = true;
        marchyo.development.enable = true;
      });
    in
    pkgs.writeText "eval-omarchy-binds-enabled" (
      if
        hasBind hm "SUPER + backslash" "marchyo monitor scale-cycle"
        && hasBind hm "SUPER + CTRL + Delete" "marchyo monitor laptop-toggle"
        && hasBind hm "switch:on:Lid Switch" "marchyo monitor clamshell on"
        && hasBind hm "switch:off:Lid Switch" "marchyo monitor clamshell off"
        && hasBind hm "SUPER + CTRL + A" "marchyo:panel.audio"
        && hasBind hm "SUPER + CTRL + B" "marchyo:panel.bluetooth"
        && hasBind hm "SUPER + CTRL + SHIFT + B" "--class=org.omarchy.bluetui -e bluetui"
        && hasBind hm "SUPER + CTRL + N" "marchyo:panel.network"
        && hasBind hm "SUPER + CTRL + W" "marchyo bg next"
        && hasBind hm "SUPER + ALT + return" "-e tmux new -A -s Work"
        && hasBind hm "SUPER + ALT + SHIFT + F" "marchyo launch file-manager"
        && hasPackage hm "xdg-utils"
        && hasPackage hm "tmux"
      then
        "pass"
      else
        throw "FAIL: desktop+development enabled but an omarchy-binds keybinding or backing package is missing"
    );

  # No Docker TUI bind: lazydocker is not installed or bound by default.
  eval-omarchy-binds-no-lazydocker =
    let
      hm = hmFor (evalWith {
        marchyo.desktop.enable = true;
        marchyo.development.enable = true;
      });
    in
    pkgs.writeText "eval-omarchy-binds-no-lazydocker" (
      if hasBindText hm "marchyo monitor scale-cycle" && !(hasBindText hm "lazydocker") then
        "pass"
      else
        throw "FAIL: the Docker TUI bind is present, or the other binds are missing"
    );

  # Desktop off (default): none of the omarchy-binds contributions leak.
  eval-omarchy-binds-disabled =
    let
      hm = hmFor (evalWith { });
    in
    pkgs.writeText "eval-omarchy-binds-disabled" (
      if
        !(hasBindText hm "marchyo monitor scale-cycle")
        && !(hasBindText hm "marchyo monitor laptop-toggle")
        && !(hasBindText hm "marchyo launch file-manager")
        && !(hasPackage hm "tmux")
      then
        "pass"
      else
        throw "FAIL: desktop disabled but an omarchy-binds keybinding or package is present"
    );

  # No chord may be bound twice. modules/home/emacs.nix used to claim
  # SUPER+SHIFT+C, which modules/home/hyprland.nix already binds to the colour
  # picker; both land in the same list (emacs binds arrive via
  # `bind = lib.mkAfter hyprBinds`), so enabling marchyo.emacs silently emitted
  # two binds for one chord. Checked with every bind-contributing feature on.
  eval-binds-no-duplicate-chords =
    let
      dupes = duplicateChords (
        hmFor (evalWith {
          marchyo = {
            # desktop.enable is what makes the Hyprland HM module produce any
            # binds at all — without it this assertion is vacuous.
            desktop.enable = true;
            development.enable = true;
            emacs.enable = true;
            dictation.enable = true;
            webapps.enable = true;
            console.enable = true;
            ai.herdr.enable = true;
          };
        })
      );
    in
    pkgs.writeText "eval-binds-no-duplicate-chords" (
      if dupes == [ ] then
        "pass"
      else
        throw "FAIL: these chords are bound more than once: ${lib.concatStringsSep ", " dupes}"
    );
}
