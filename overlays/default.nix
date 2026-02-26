{ inputs }:
final: prev: {
  fh = inputs.fh.packages.${final.system}.default;
  vicinae = inputs.vicinae.packages.${final.system}.default;
  noctalia = inputs.noctalia.packages.${final.system}.default;
  worktrunk = inputs.worktrunk.packages.${final.system}.default;

  # Fix picosvg tests failing with skia-pathops >= 0.9.0 due to floating-point
  # precision differences. Backport of upstream PR #331 (merged Nov 2025, not yet released).
  # https://github.com/googlefonts/picosvg/pull/331
  python3Packages = prev.python3Packages.overrideScope (
    _pyFinal: pyPrev: {
      picosvg = pyPrev.picosvg.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ./patches/picosvg-fix-tests-skia-pathops-m143.patch
        ];
      });
    }
  );
}
