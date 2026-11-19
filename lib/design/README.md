# lib/design — vendored Jylhis design system

The subset of the Jylhis design system (version 7.0.0) that marchyo reads.
Nothing here is built from npm or bun: marchyo only reads these files.

| Path | Used by |
| --- | --- |
| `nix/palette.nix`, `tokens/*.tokens.json` | `modules/generic/jylhis-palette.nix`, wallpapers, plymouth, shell |
| `nix/fonts.nix` | font, fontconfig, GTK and theme-runtime modules |
| `platforms/gtk/` | `modules/home/jylhis-theme.nix`, `theme-runtime.nix` |
| `platforms/shell/starship.toml` | `modules/home/starship.nix` |
| `platforms/{ghostty,bat,emacs}/` | `pkgs.jylhis-themes`, the Emacs theme package |
| `platforms/quickshell/Tokens.qml` | `shell/Commons/Tokens.qml` (a byte-identical copy) |

`palette.nix` reads all five token files, so they travel together. The
contrast variants (`light-contrast`, `dark-contrast`) are in the palette but no
`marchyo.theme.variant` value selects them.

The Ghostty, bat, Emacs and quickshell files are generator output, not
committed upstream. To refresh everything from a design checkout:

```sh
D=../design                     # a design system checkout
bun "$D/scripts/generate.mjs" --out /tmp/design-gen
cp "$D"/nix/{palette,fonts}.nix nix/
cp "$D"/tokens/{base,light,dark,light-contrast,dark-contrast}.tokens.json tokens/
cp "$D"/platforms/gtk/jylhis-{light,dark}.css "$D"/platforms/gtk/jylhis.css.in platforms/gtk/
cp "$D"/platforms/shell/starship.toml platforms/shell/
cp "$D"/platforms/emacs/jylhis-{themes,theme-toggle}.el platforms/emacs/
cp /tmp/design-gen/platforms/emacs/jylhis-{light,dark}-theme.el platforms/emacs/
cp /tmp/design-gen/platforms/ghostty/jylhis-{light,dark} platforms/ghostty/
cp /tmp/design-gen/platforms/bat/jylhis-{light,dark}.tmTheme platforms/bat/
cp /tmp/design-gen/platforms/quickshell/{Tokens.qml,qmldir} platforms/quickshell/
cp platforms/quickshell/Tokens.qml ../../shell/Commons/Tokens.qml
```

The website imports `site/vendor/design`, a copy of the design checkout's web
files. It shares no paths with this directory. Refresh it from the same
checkout:

```sh
S=../../site/vendor/design
cp "$D"/{colors_and_type,density,elements,fonts,motion,styles,tokens}.css "$S"/
cp "$D"/components/components.css "$S"/components/
cp "$D"/platforms/shadcn/tokens.css "$S"/platforms/shadcn/
```

Copy `fonts/` too when the design system changes its font files. The
`design-vendor-sync` check fails when a colour in `site/vendor/design/tokens.css`
differs from the palette read from `tokens/`, or when `shell/Commons/Tokens.qml`
differs from `platforms/quickshell/Tokens.qml`.

Then update the version above. MIT licensed (`LICENSE`).
