# marchyo.language: the default derives from marchyo.defaultLocale against the
# shell/i18n registry, the option rejects codes the registry lacks, and the
# value reaches the shell package (Commons/Config.qml bakes it).
#
# Only English ships, so the derivation and override cases use a synthetic
# registry: lib/locale-language.nix is called with it directly, and a test
# module widens the option's enum (enum declarations merge) with the synthetic
# codes.
{
  helpers,
  lib,
  pkgs,
  nixosModules,
  homeManagerModules,
  ...
}:
let
  inherit (helpers) withTestUser;

  evalWith =
    extra:
    lib.nixosSystem {
      inherit (pkgs.stdenv.hostPlatform) system;
      modules = [
        nixosModules
        (withTestUser (
          lib.recursiveUpdate {
            marchyo.desktop.enable = true;
            home-manager.users.testuser.imports = [ homeManagerModules ];
          } extra
        ))
      ];
    };

  languageOf = extra: (evalWith extra).config.marchyo.language;

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
    extra:
    lib.findFirst (p: (p.pname or "") == "marchyo-shell") null
      (evalWith extra).config.home-manager.users.testuser.home.packages;
in
{
  eval-i18n-language-default = pkgs.writeText "eval-i18n-language-default" (
    if wrong != [ ] then
      throw "FAIL: marchyo.language default is wrong for: ${
        lib.concatMapStringsSep ", " (c: "${c.locale} (want ${c.want})") wrong
      }"
    else
      "pass"
  );

  eval-i18n-language-default-shipped = pkgs.writeText "eval-i18n-language-default-shipped" (
    if wrongShipped != [ ] then
      throw "FAIL: marchyo.language should default to en with the shipped registry for: ${lib.concatStringsSep ", " wrongShipped}"
    else
      "pass"
  );

  eval-i18n-language-explicit-wins = pkgs.writeText "eval-i18n-language-explicit-wins" (
    if
      languageOf (
        withCodes [ "de" ]
        // {
          marchyo.defaultLocale = "en_US.UTF-8";
          marchyo.language = "de";
        }
      ) != "de"
      || languageOf { marchyo.language = "en"; } != "en"
    then
      throw "FAIL: an explicit marchyo.language must win over the defaultLocale derivation (and en must be settable)"
    else
      "pass"
  );

  eval-i18n-language-rejects-unknown = pkgs.writeText "eval-i18n-language-rejects-unknown" (
    if
      (builtins.tryEval (languageOf {
        marchyo.language = "zz";
      })).success
    then
      throw "FAIL: marchyo.language accepted a code that is not in shell/i18n/locales.json"
    else
      "pass"
  );

  eval-i18n-language-baked-into-shell =
    let
      pkg = shellPkgOf (withCodes [ "fi" ] // { marchyo.language = "fi"; });
      defaultPkg = shellPkgOf { };
    in
    pkgs.writeText "eval-i18n-language-baked-into-shell" (
      if pkg == null then
        throw "FAIL: the marchyo-shell package is not in the Home Manager profile"
      else if pkg.language != "fi" then
        throw "FAIL: marchyo.language = fi did not reach the marchyo-shell package (got ${pkg.language})"
      else if defaultPkg.language != "en" then
        throw "FAIL: the default marchyo.language should bake en into the shell (got ${defaultPkg.language})"
      else
        "pass"
    );
}
