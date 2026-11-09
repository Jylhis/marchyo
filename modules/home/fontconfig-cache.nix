# fontconfig's per-user cache can outlive a Home Manager generation: HM
# scans ~/.nix-profile/share/fonts (10-hm-fonts.conf), and a cached entry
# keeps serving fonts that left the profile, so apps resolve a family to a
# dead path and fall back with mismatched metrics. Rebuild the cache
# whenever the profile font set changes.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.marchyo.fonts;
in
{
  options.marchyo.fonts.cleanUserCache =
    lib.mkEnableOption "rebuilding the per-user fontconfig cache when the profile font set changes"
    // {
      default = true;
    };

  config =
    lib.mkIf (pkgs.stdenv.hostPlatform.isLinux && config.fonts.fontconfig.enable && cfg.cleanUserCache)
      {
        home.activation.marchyoFontconfigCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          fonts_dir="${config.home.profileDirectory}/share/fonts"
          stamp_dir="${config.xdg.stateHome}/marchyo/fontconfig-cache"
          new_hash="$(
            { find -L "$fonts_dir" -type f -printf '%P %s\n' 2>/dev/null || true; } \
              | LC_ALL=C sort | sha256sum | cut -d' ' -f1
          )"
          old_hash="$(cat "$stamp_dir/fontset.sha256" 2>/dev/null || true)"
          if [ "$new_hash" != "$old_hash" ]; then
            rm -rf "${config.xdg.cacheHome}/fontconfig"
            ${pkgs.fontconfig}/bin/fc-cache -f > /dev/null 2>&1 || true
            mkdir -p "$stamp_dir"
            printf '%s\n' "$new_hash" > "$stamp_dir/fontset.sha256"
          fi
        '';
      };
}
