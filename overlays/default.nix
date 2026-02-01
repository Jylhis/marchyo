{ inputs }:
final: _prev: {
  fh = inputs.fh.packages.${final.system}.default;
  vicinae = inputs.vicinae.packages.${final.system}.default;
  noctalia = inputs.noctalia.packages.${final.system}.default;
}
