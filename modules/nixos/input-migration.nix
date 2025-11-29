{
  config,
  ...
}:
{
  # Enforce manual migration from old marchyo.inputMethod.* options
  config = {
    assertions = [
      {
        assertion = !config.marchyo.inputMethod.enable;
        message = ''
          marchyo.inputMethod.enable is no longer supported.

          Please migrate to marchyo.keyboard.layouts.

          Migration examples:

          OLD:
            marchyo.inputMethod.enable = true;
            marchyo.inputMethod.enableCJK = true;
            marchyo.keyboard.layouts = ["us" "fi"];

          NEW (English + Finnish + Chinese):
            marchyo.keyboard.layouts = [
              "us"
              "fi"
              { layout = "cn"; ime = "pinyin"; }
            ];

          NEW (English + Finnish + Japanese):
            marchyo.keyboard.layouts = [
              "us"
              "fi"
              { layout = "jp"; ime = "mozc"; }
            ];

          NEW (All CJK languages):
            marchyo.keyboard.layouts = [
              "us"
              "fi"
              { layout = "cn"; ime = "pinyin"; }
              { layout = "jp"; ime = "mozc"; }
              { layout = "kr"; ime = "hangul"; }
            ];

          See CLAUDE.md for complete documentation.
        '';
      }
    ];
  };
}
