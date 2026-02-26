{ inputs }:
final: prev: {
  vicinae = inputs.vicinae.packages.${final.system}.default;
  noctalia = inputs.noctalia.packages.${final.system}.default;
  worktrunk = inputs.worktrunk.packages.${final.system}.default;

  # Override python313 (the concrete interpreter behind python3) so that
  # both python3.pkgs and python3Packages stay in sync — overriding
  # python3Packages directly creates a disconnected copy that is not seen by
  # packages that create a fresh scope via python3.override { packageOverrides }.
  #
  # Fix picosvg tests failing with skia-pathops >= 0.9.0 due to floating-point
  # precision differences. Backport of upstream PR #331 (merged Nov 2025, not yet released).
  # https://github.com/googlefonts/picosvg/pull/331
  python313 = prev.python313.override {
    packageOverrides = _pyFinal: pyPrev: {
      picosvg = pyPrev.picosvg.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or [ ]) ++ [
          ./patches/picosvg-fix-tests-skia-pathops-m143.patch
        ];
      });
    };
  };

}
