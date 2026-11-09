{
  pkgs,
  lib,
  config,
  ...
}:
let
  designFonts = import "${pkgs.jylhis-design-src}/nix/fonts.nix";
  keyboardLib = import ../generic/keyboard-lib.nix;

  cjkImes = lib.unique (
    lib.filter (ime: ime != null && keyboardLib.cjkImes ? ${ime}) (
      map (l: l.ime) (map keyboardLib.normalizeLayout config.marchyo.keyboard.layouts)
    )
  );

  faces = region: {
    sans-serif = "Noto Sans CJK ${region}";
    serif = "Noto Serif CJK ${region}";
    monospace = "Noto Sans Mono CJK ${region}";
  };

  appendRules =
    test: region:
    lib.concatStrings (
      lib.mapAttrsToList (generic: face: ''
        <match target="pattern">
          ${test}
          <test name="family" qual="any"><string>${generic}</string></test>
          <edit name="family" mode="append" binding="same"><string>${face}</string></edit>
        </match>
      '') (faces region)
    );

  # Text tagged with a language gets that language's glyph forms.
  langRules = lib.concatMapStrings (
    ime:
    let
      info = keyboardLib.cjkImes.${ime};
    in
    appendRules ''<test name="lang" compare="contains"><string>${info.lang}</string></test>'' info.region
  ) cjkImes;

  # Untagged text falls back to the glyph forms of the first configured engine.
  defaultRules = appendRules "" keyboardLib.cjkImes.${lib.head cjkImes}.region;
in
{
  imports = [
    ../generic/fontconfig.nix
  ];
  fonts = {
    enableDefaultPackages = lib.mkDefault true;
    fontDir.enable = lib.mkDefault true;
    packages =
      designFonts.packages pkgs
      ++ (with pkgs; [
        # Programming fonts (Nerd Font variants only). BlexMono is the Nerd Font
        # patch of IBM Plex Mono: the code face, and the face marchyo's desktop
        # chrome (shell, greeter, hyprlock) asks for by name for its icon glyphs.
        nerd-fonts.blex-mono
        nerd-fonts.caskaydia-mono
        nerd-fonts.jetbrains-mono # v2 mono fallback

        # UI and reading fonts: the design system's families (Jost, Fira Sans,
        # IBM Plex Mono) and the Liberation metric-compatible set.
        liberation_ttf

        # Emoji fallback: the shell launcher's emoji mode renders through
        # fontconfig fallback (fcitx5 already pulls this on IME hosts).
        noto-fonts-color-emoji
      ]);
    fontconfig = {
      cache32Bit = true;

      localConf = lib.mkIf (config.marchyo.desktop.enable && cjkImes != [ ]) (langRules + defaultRules);

      antialias = true;
      hinting = {
        enable = true;
        style = "slight";
        autohint = false;
      };

      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
    };
  };
}
