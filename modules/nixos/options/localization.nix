{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  registry = builtins.fromJSON (builtins.readFile ../../../shell/i18n/locales.json);
  languageCodes = builtins.attrNames registry;

  languageFor = import ../../../lib/locale-language.nix { inherit lib; } registry;
in
{
  options.marchyo = {
    timezone = mkOption {
      type = types.str;
      default = "Europe/Zurich";
      example = "America/New_York";
      description = "System timezone";
    };

    defaultLocale = mkOption {
      type = types.str;
      default = "en_US.UTF-8";
      example = "de_DE.UTF-8";
      description = "System default locale";
    };

    language = mkOption {
      type = types.enum languageCodes;
      default = languageFor config.marchyo.defaultLocale;
      defaultText = lib.literalMD "derived from `marchyo.defaultLocale`, `\"en\"` when no catalog matches";
      example = "en";
      description = ''
        Display language of the Marchyo shell and CLI strings (a code from
        `shell/i18n/locales.json`; only English ships today). Strings without a
        translation fall back to English. This does not change the system `LANG`; use
        `marchyo.defaultLocale` for that. `marchyo language <code>` overrides it
        at runtime until `marchyo language --revert`.
      '';
    };

    autoTimezone.enable = lib.mkEnableOption ''
      automatic timezone updates from your location (services.automatic-timezoned
      via geoclue2). Opt-in and off by default. When enabled it overrides the
      static marchyo.timezone; a warning is emitted if marchyo.timezone was also
      changed from its default'';
  };
}
