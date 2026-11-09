# lib/design — vendored Jylhis design system

The subset of the Jylhis design system (version 6.0.0) that marchyo reads,
copied from `lib/design` in the j10s monorepo (j10s commit `6d74939000`). Nothing here
is built from npm or bun: marchyo only reads these files.

| Path | Used by |
| --- | --- |
| `nix/palette.nix`, `tokens/*.tokens.json` | `modules/generic/jylhis-palette.nix`, wallpapers, plymouth, shell |
| `nix/fonts.nix` | font, fontconfig, GTK and theme-runtime modules |
| `platforms/gtk/` | `modules/home/jylhis-theme.nix`, `theme-runtime.nix` |
| `platforms/shell/starship.toml` | `modules/home/starship.nix` |
| `platforms/{ghostty,bat,emacs}/` | `pkgs.jylhis-themes`, the Emacs theme package |

`palette.nix` reads all five token files, so they travel together.

The Ghostty, bat and Emacs `jylhis-{light,dark}` themes are generator output,
not committed upstream. To refresh everything from a design checkout:

```sh
D=../j10s/lib/design            # the design tree
bun "$D/scripts/generate.mjs" --out /tmp/design-gen
cp "$D"/nix/{palette,fonts}.nix nix/
cp "$D"/tokens/{base,light,dark,light-contrast,dark-contrast}.tokens.json tokens/
cp "$D"/platforms/gtk/jylhis-{light,dark}.css "$D"/platforms/gtk/jylhis.css.in platforms/gtk/
cp "$D"/platforms/shell/starship.toml platforms/shell/
cp "$D"/platforms/emacs/jylhis-{themes,theme-toggle}.el platforms/emacs/
cp /tmp/design-gen/platforms/emacs/jylhis-{light,dark}-theme.el platforms/emacs/
cp /tmp/design-gen/platforms/ghostty/jylhis-{light,dark} platforms/ghostty/
cp /tmp/design-gen/platforms/bat/jylhis-{light,dark}.tmTheme platforms/bat/
```

Then update the commit and version above. MIT licensed (`LICENSE`).
