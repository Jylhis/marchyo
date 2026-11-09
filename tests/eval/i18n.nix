# marchyo.language: the default derives from marchyo.defaultLocale against the
# shell/i18n registry, the option rejects codes the registry lacks, and the
# value reaches the shell package (Commons/Config.qml bakes it).
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

  wrong = lib.filter (c: languageOf { marchyo.defaultLocale = c.locale; } != c.want) cases;

  shellPkgOf =
    extra:
    lib.findFirst (p: (p.pname or "") == "marchyo-shell") null (
      (evalWith extra).config.home-manager.users.testuser.home.packages
    );
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

  eval-i18n-language-explicit-wins = pkgs.writeText "eval-i18n-language-explicit-wins" (
    if
      languageOf {
        marchyo.defaultLocale = "fi_FI.UTF-8";
        marchyo.language = "de";
      } != "de"
    then
      throw "FAIL: an explicit marchyo.language must win over the defaultLocale derivation"
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
      pkg = shellPkgOf { marchyo.language = "fi"; };
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
