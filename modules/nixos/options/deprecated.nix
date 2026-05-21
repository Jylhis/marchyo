{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  # Removed/inert options kept only so old downstream configs evaluate
  # to a clear migration error instead of "option does not exist".
  # Enforcement lives in modules/nixos/input-migration.nix.
  options.marchyo.inputMethod = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        REMOVED: This option has been removed in favor of marchyo.keyboard.layouts.

        Please migrate your configuration:

        OLD:
          marchyo.inputMethod.enable = true;
          marchyo.inputMethod.enableCJK = true;
          marchyo.keyboard.layouts = ["us" "fi"];

        NEW:
          marchyo.keyboard.layouts = [
            "us"
            "fi"
            { layout = "cn"; ime = "pinyin"; }  # For Chinese input
            # { layout = "jp"; ime = "mozc"; }  # For Japanese input
            # { layout = "kr"; ime = "hangul"; }  # For Korean input
          ];

        See CLAUDE.md for complete documentation.
      '';
    };

    triggerKey = mkOption {
      type = types.listOf types.str;
      default = [
        "Super+I"
        "Zenkaku_Hankaku"
        "Hangul"
      ];
      example = [
        "Alt+grave"
        "Super+I"
      ];
      description = ''
        INERT: This option has no effect. Use marchyo.keyboard.imeTriggerKey instead.

        This option is kept only to avoid evaluation errors for consumers who
        haven't migrated yet. It will be removed in a future release.
      '';
    };

    enableCJK = mkOption {
      type = types.bool;
      default = true;
      description = ''
        INERT: This option has no effect. Add CJK layouts to marchyo.keyboard.layouts instead.

        Example:
          marchyo.keyboard.layouts = [
            "us"
            { layout = "cn"; ime = "pinyin"; }  # Chinese
            { layout = "jp"; ime = "mozc"; }    # Japanese
            { layout = "kr"; ime = "hangul"; }  # Korean
          ];

        This option is kept only to avoid evaluation errors for consumers who
        haven't migrated yet. It will be removed in a future release.
      '';
    };
  };
}
