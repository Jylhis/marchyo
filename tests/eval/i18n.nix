# marchyo.language: the default derives from marchyo.defaultLocale against the
# shell/i18n registry, the option rejects codes the registry lacks, and the
# value reaches the shell package (Commons/Config.qml bakes it).
#
# Only English ships, so the derivation and override cases use a synthetic
# registry: lib/locale-language.nix is called with it directly, and a test
# module widens the option's enum (enum declarations merge) with the synthetic
# codes.
{ helpers, lib, ... }:
let
  inherit (helpers) evalOptions;

  # marchyo.language from the option declarations alone: the default derives
  # from marchyo.defaultLocale, so no system evaluation is needed.
  languageOf = module: (evalOptions module).marchyo.language;

  # Synthetic registry entries in the locales.json shape.
  entry = locale: {
    name = locale;
    englishName = locale;
    formatLocale = locale;
    inherit locale;
    decimal = ",";
    zeroDigit = "0";
  };
  registry = {
    en = entry "en_US.UTF-8";
    fi = entry "fi_FI.UTF-8";
    de = entry "de_DE.UTF-8";
    pt = entry "pt_PT.UTF-8";
    pt-BR = entry "pt_BR.UTF-8";
    no = entry "nb_NO.UTF-8";
  };
  languageFor = import ../../lib/locale-language.nix { inherit lib; } registry;

  # Extra language codes accepted by marchyo.language, as if their catalogs
  # shipped.
  withCodes = codes: {
    imports = [ { options.marchyo.language = lib.mkOption { type = lib.types.enum codes; }; } ];
  };

  cases = [
    {
      locale = "en_US.UTF-8";
      want = "en";
    }
    {
      locale = "fi_FI.UTF-8";
      want = "fi";
    }
    {
      locale = "de_CH.UTF-8";
      want = "de";
    }
    {
      locale = "pt_BR.UTF-8";
      want = "pt-BR";
    }
    {
      locale = "pt_PT.UTF-8";
      want = "pt";
    }
    {
      locale = "nb_NO.UTF-8";
      want = "no";
    }
    {
      locale = "xx_XX.UTF-8";
      want = "en";
    }
  ];

  wrong = lib.filter (c: languageFor c.locale != c.want) cases;

  # The shipped registry: every locale derives to English.
  wrongShipped = lib.filter (l: languageOf { marchyo.defaultLocale = l; } != "en") [
    "en_US.UTF-8"
    "fi_FI.UTF-8"
    "xx_XX.UTF-8"
  ];

  shellPkgOf =
    c:
    lib.findFirst (
      p: (p.pname or "") == "marchyo-shell"
    ) null c.home-manager.users.testuser.home.packages;
in
{
  checks = {
    eval-i18n-language-default =
      helpers.assertTest "i18n-language-default" (wrong == [ ])
        "marchyo.language default is wrong for: ${
          lib.concatMapStringsSep ", " (c: "${c.locale} (want ${c.want})") wrong
        }";

    eval-i18n-language-default-shipped =
      helpers.assertTest "i18n-language-default-shipped" (wrongShipped == [ ])
        "marchyo.language should default to en with the shipped registry for: ${lib.concatStringsSep ", " wrongShipped}";

    eval-i18n-language-explicit-wins =
      helpers.assertTest "i18n-language-explicit-wins"
        (
          languageOf (
            withCodes [ "de" ]
            // {
              marchyo.defaultLocale = "en_US.UTF-8";
              marchyo.language = "de";
            }
          ) == "de"
          && languageOf { marchyo.language = "en"; } == "en"
        )
        "an explicit marchyo.language must win over the defaultLocale derivation (and en must be settable)";

    eval-i18n-language-rejects-unknown = helpers.assertTest "i18n-language-rejects-unknown" (
      helpers.throws
        (languageOf {
          marchyo.language = "zz";
        })
    ) "marchyo.language accepted a code that is not in shell/i18n/locales.json";
  };

  # desktop-tweaks sets marchyo.language = "fi" (with the code widened in);
  # the plain desktop keeps the default. Nothing builds that shell, so the
  # missing fi catalog does not matter (and desktop-tweaks feeds no heavy check).
  refs.desktop-tweaks.eval-i18n-language-baked-into-shell =
    c:
    let
      pkg = shellPkgOf c;
    in
    if pkg == null then
      "the marchyo-shell package is not in the Home Manager profile"
    else if pkg.language != "fi" then
      "marchyo.language = fi did not reach the marchyo-shell package (got ${pkg.language})"
    else
      true;

  # The default marchyo.language bakes en into the shell.
  refs.desktop.eval-i18n-language-baked-into-shell-default =
    c:
    let
      pkg = shellPkgOf c;
    in
    helpers.expect (
      pkg != null && pkg.language == "en"
    ) "the default marchyo.language should bake en into the shell (got ${pkg.language or "no shell"})";

  refConfig.desktop-tweaks = withCodes [ "fi" ] // {
    marchyo.language = "fi";
  };
}
