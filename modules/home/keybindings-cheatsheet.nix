{
  lib,
  pkgs,
  config,
  osConfig ? { },
  ...
}:
let
  inherit (lib) mkIf mkEnableOption;
  cfg = config.marchyo.keybindingsHelp;
  desktopEnabled = pkgs.stdenv.isLinux && ((osConfig.marchyo or { }).desktop.enable or false);

  # Renders the live Hyprland bind table (the `bindd` entries carry
  # human-readable descriptions) into a searchable overlay. Reading from
  # `hyprctl binds -j` at runtime means the sheet always reflects the actual
  # running config, including any binds added by downstream consumers.
  cheatsheet = pkgs.writeShellApplication {
    name = "marchyo-keybindings";
    runtimeInputs = with pkgs; [
      hyprland # hyprctl
      jq
      fzf
      gawk
    ];
    text = ''
      # Pull every described bind, decode the modifier bitmask into readable
      # names, and emit "MODS+KEY<TAB>description" rows.
      binds=$(
        hyprctl binds -j | jq -r '
          def bit($b): (. / $b | floor) % 2 == 1;
          [
            .[]
            | select(.description and .description != "")
            | (.modmask) as $m
            | ([ (if ($m | bit(64)) then "SUPER" else empty end),
                 (if ($m | bit(4))  then "CTRL"  else empty end),
                 (if ($m | bit(8))  then "ALT"   else empty end),
                 (if ($m | bit(1))  then "SHIFT" else empty end) ]
               | join("+")) as $mods
            | (if .key and .key != "" then .key
               elif (.keycode >= 10 and .keycode <= 18) then ((.keycode - 9) | tostring)
               elif .keycode == 19 then "0"
               elif .keycode != 0 then "code:\(.keycode)"
               else "mouse" end) as $key
            | (if $mods == "" then $key else "\($mods)+\($key)" end) as $combo
            | "\($combo)\t\(.description)"
          ] | unique[]
        '
      )

      if [ -z "$binds" ]; then
        echo "No described keybindings found." >&2
        exit 1
      fi

      printf '%s\n' "$binds" \
        | awk -F'\t' '{ printf "%-24s  %s\n", $1, $2 }' \
        | fzf \
            --reverse \
            --no-sort \
            --cycle \
            --prompt 'keybindings> ' \
            --header 'Hyprland keybindings — type to filter, Esc to close' \
          || true
    '';
  };
in
{
  options.marchyo.keybindingsHelp = {
    enable = mkEnableOption "on-screen Hyprland keybinding cheat sheet (SUPER+K)" // {
      default = true;
    };
  };

  config = mkIf (desktopEnabled && cfg.enable) {
    home.packages = [ cheatsheet ];

    # Reuse the existing floating-terminal class so the overlay picks up the
    # centered floating-window rule from hyprland.nix without a new windowrule.
    wayland.windowManager.hyprland.settings.bindd = [
      "SUPER, K, Keybindings cheat sheet, exec, $terminal --class=org.omarchy.terminal -e marchyo-keybindings"
    ];
  };
}
