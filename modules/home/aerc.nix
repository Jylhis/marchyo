# Per-user aerc (TUI mail client). Account/credential setup is left to the consumer.
#
# Theming is marchyo's, not Stylix's (aerc target disabled in
# modules/generic/theme.nix): upstream uses base07, a base16 background slot, as
# a foreground, which is white-on-white in the light variant. The "marchyo"
# styleset built from Jylhis semantic tokens contrasts against its surface in both
# variants.
{
  osConfig ? { },
  pkgs,
  lib,
  ...
}:
let
  defaults = (osConfig.marchyo or { }).defaults or { };
  enabled = (osConfig.marchyo.desktop.enable or false) && (defaults.email or null) == "aerc";

  themeVariant = (osConfig.marchyo or { }).theme.variant or "dark";
  palette = import ../generic/jylhis-palette.nix {
    inherit pkgs lib;
    variant = themeVariant;
  };
  inherit (palette) hex;
in
{
  config = lib.mkIf enabled {
    programs.aerc = {
      enable = true;

      extraConfig.ui.styleset-name = "marchyo";

      # See aerc-stylesets(7). Colors carry the leading "#" (palette.hex format).
      stylesets.marchyo = {
        global = {
          "*.default" = true;
          "*.normal" = true;

          "default.fg" = hex.text;

          "error.fg" = hex."status-err";
          "warning.fg" = hex."status-warn";
          "success.fg" = hex."status-ok";

          # Never surface-raised (base07) as a foreground: near-white in the light variant.
          "title.fg" = hex."text-heading";
          "title.bg" = hex.surface;
          "title.bold" = true;
          "header.fg" = hex.accent;
          "header.bold" = true;

          "statusline_default.fg" = hex.text;
          "statusline_default.bg" = hex.surface;
          "statusline_error.fg" = hex."status-err";
          "statusline_error.bold" = true;
          "statusline_success.fg" = hex."status-ok";
          "statusline_success.bold" = true;

          "msglist_default.fg" = hex.text;
          "msglist_unread.fg" = hex."text-heading";
          "msglist_unread.bold" = true;
          "msglist_flagged.fg" = hex."status-warn";
          "msglist_flagged.bold" = true;
          "msglist_deleted.fg" = hex."text-faint";
          "msglist_marked.fg" = hex.accent;
          "msglist_marked.reverse" = true;
          "msglist_result.fg" = hex."status-info";
          "msglist_result.bold" = true;
          "msglist_*.selected.bg" = hex."selection-bg";
          "msglist_*.selected.bold" = true;
          "msglist_pill.bg" = hex.surface;

          "dirlist_default.fg" = hex.text;
          "dirlist_unread.fg" = hex."text-heading";
          "dirlist_unread.bold" = true;
          "dirlist_*.selected.bg" = hex."selection-bg";
          "dirlist_*.selected.bold" = true;

          "part_filename.fg" = hex."text-muted";
          "part_mimetype.fg" = hex."text-faint";
          "part_*.selected.bg" = hex."selection-bg";
          "part_*.selected.bold" = true;

          "completion_default.fg" = hex.text;
          "completion_*.bg" = hex.surface;
          "completion_pill.bg" = hex."surface-raised";
          "completion_*.selected.bg" = hex."selection-bg";
          "completion_*.selected.bold" = true;

          "tab.fg" = hex."text-muted";
          "tab.bg" = hex.bg;
          "tab.selected.fg" = hex."text-heading";
          "tab.selected.bg" = hex.surface;
          "tab.selected.bold" = true;

          "border.fg" = hex.border;
          "border.bold" = true;

          "selector_focused.fg" = hex."text-heading";
          "selector_focused.bg" = hex."selection-bg";
          "selector_focused.bold" = true;
        };

        viewer = {
          "*.default" = true;
          "*.normal" = true;

          "default.fg" = hex.text;

          "url.fg" = hex."status-info";
          "url.underline" = true;
          "header.fg" = hex.accent;
          "header.bold" = true;
          "signature.fg" = hex."text-faint";
          "signature.dim" = true;

          "diff_meta.bold" = true;
          "diff_chunk.fg" = hex."status-info";
          "diff_chunk_func.fg" = hex."status-info";
          "diff_chunk_func.bold" = true;
          "diff_add.fg" = hex."status-ok";
          "diff_del.fg" = hex."status-err";

          "quote_*.fg" = hex."text-muted";
          "quote_1.fg" = hex.accent;
        };
      };
    };
  };
}
