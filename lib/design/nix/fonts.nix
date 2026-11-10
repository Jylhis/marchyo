# Jylhis design system: the font families as Nix values, for desktop configs
# (fontconfig, GTK, Emacs) that cannot read the web fonts in fonts/.
#
#   fonts = import ./fonts.nix;
#   fonts.body                  # "Fira Sans"
#   fonts.packages pkgs         # [ jost fira-sans ibm-plex ]
#
# Family names come from tokens/base.tokens.json (the first entry of each
# font.* stack), so a token change reaches the desktop without a second edit.
let
  base = builtins.fromJSON (builtins.readFile ../tokens/base.tokens.json);
  family = role: builtins.head base.font.${role}."$value";
in
{
  display = family "display";
  body = family "body";
  mono = family "mono";

  # nixpkgs packages that provide the three families.
  packages = pkgs: [
    pkgs.jost
    pkgs.fira-sans
    pkgs.ibm-plex
  ];
}
