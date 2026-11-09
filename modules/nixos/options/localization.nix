{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  registry = builtins.fromJSON (builtins.readFile ../../../shell/i18n/locales.json);
  languageCodes = builtins.attrNames registry;

  # "fi_FI.UTF-8" -> "fi_FI"
  withoutEncoding = locale: builtins.head (lib.splitString "." locale);

  # The registry code for a system locale: an exact locale match first (so
  # "pt_BR" picks "pt-BR"), then the bare language, else English.
  languageFor =
    locale:
    let
      full = withoutEncoding locale;
      exact = builtins.filter (code: withoutEncoding registry.${code}.locale == full) languageCodes;
      bare = builtins.head (lib.splitString "_" full);
    in
    if exact != [ ] then
      builtins.head exact
    else if registry ? ${bare} then
      bare
    else
      "en";
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
      example = "fi";
      description = ''
        Display language of the Marchyo shell and CLI strings (a code from
        `shell/i18n/locales.json`). Strings without a translation fall back to
        English. This does not change the system `LANG`; use
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
