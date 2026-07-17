# Per-user jotain (Jylhis's Emacs config) as the marchyo default editor.
#
# Enabled via services.jotain when "jotain" is the selected
# marchyo.defaults.editor and/or terminalEditor and desktop is enabled.
# EDITOR/VISUAL are owned by marchyo at the NixOS level
# (modules/nixos/defaults.nix maps jotain -> jotain-visual/jotain-editor), so
# defaultEditor is false here to avoid double-defining the session variables;
# this also keeps the mixed case correct (e.g. editor = "jotain" +
# terminalEditor = "neovim"). xdg.nix routes text/plain to jotain-client.desktop.
{
  osConfig ? { },
  pkgs,
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  selected = (defaults.editor or null) == "jotain" || (defaults.terminalEditor or null) == "jotain";
  enabled = pkgs.stdenv.isLinux && (osConfig.marchyo.desktop.enable or false) && selected;

  inherit (pkgs.glib) getSchemaPath;
in
{
  config = lib.mkIf enabled {
    services.jotain = {
      enable = true;
      defaultEditor = false; # marchyo owns EDITOR/VISUAL (modules/nixos/defaults.nix)
      client.enable = true; # installs jotain-client.desktop (Linux)
    };

    # The jotain daemon (upstream-defined `jotain.service`, systemd --user)
    # starts with a minimal environment whose XDG_DATA_DIRS lacks the GSettings
    # schema directories, so GTK's frame setup for `emacsclient -c` aborts with
    # `g_settings_schema_source_lookup: assertion 'source != NULL'` and the
    # client connects but silently opens no window. Point GSETTINGS_SCHEMA_DIR
    # (colon-separated; GLib merges all listed dirs) at the current generation's
    # compiled schemas so GUI frames work from a cold daemon start. These store
    # paths are pinned by the unit, so the fix survives later rebuilds.
    #
    # Merges into the upstream `Service` section (it defines no Environment).
    # Note: upstream sets Unit.X-RestartIfChanged = false to preserve unsaved
    # buffers across activations, so after the switch that introduces this the
    # daemon must be restarted once (`systemctl --user restart jotain.service`
    # or re-login); every fresh daemon start thereafter has correct schemas.
    systemd.user.services.jotain.Service.Environment = [
      "GSETTINGS_SCHEMA_DIR=${getSchemaPath pkgs.gsettings-desktop-schemas}:${getSchemaPath pkgs.gtk4}:${getSchemaPath pkgs.gtk3}"
    ];
  };
}
