# marchyo runtime-theming review and extension plan

**Status (2026-10): complete.** §3 steps 1-4 shipped (bat f045fce, fzf 42c3116,
hyprlock a797211, console 38898a8); step 5 (Qt) resolved as "Option A: follow
GTK" (`QT_QPA_PLATFORMTHEME=gtk3`, e01468a) instead of the qtct/Kvantum emitter
sketched here; step 6 (fonts + cursor) and step 7 (retire stylix) shipped as
97d74c5 + 8ff3a33, with the TUI long tail (lazygit/k9s/ncspot/spotify-player/
gdu) and Emacs re-homed from base16 slots (`modules/generic/theme-slots.nix`).
Still open: the §2 correctness findings F1, F2, F4 (F3 is cosmetic and remains
as documented) and the optional §3 step-6-adjacent Material-You mode. The text
below is the original review, kept as the record; line references are to
`main` @ `43f82b8` and are historical.

Review only. No code changed. All paths are relative to the marchyo repo
unless noted; `design:` prefixes a path in the jylhis-design source
(`pkgs.jylhis-design-src`). Line references are to the state reviewed at
`main` @ `43f82b8`.

Scope: can marchyo's theming be made fully runtime (`marchyo theme set/next`
restyles every surface with no rebuild) so Stylix can be retired?

---

## 1. Surface matrix

### Already runtime (CLI restyles live, no rebuild)

| Surface | Mechanism (asset + actuation) | Liveness |
| --- | --- | --- |
| Quickshell shell | `colors.json` in theme dir → shell reads pointer | live (shell watches) |
| GTK / libadwaita | relink `gtk-3.0/gtk.css` + `gtk-4.0/gtk.css`, `dconf write` color-scheme (`theme.ts:153-161`) | libadwaita live; running GTK3 keep cached context; new apps live |
| Ghostty | `?`-include of `current-theme/ghostty.conf` (`theme-runtime.nix:383`) + portal color-scheme | live (open windows) |
| mako | relink `mako/config` + `makoctl reload` (`theme.ts:128-131`) | live |
| waybar | relink `waybar/style.css` + `systemctl --user try-restart` (`theme.ts:133-137`) | restart (near-live) |
| Hyprland keywords | `hyprctl eval hl.config(...)` (`theme.ts:139-145`) | live |

### Build-time only

Format / live-reload / what runtime would take, from the same semantic-token
palette (`modules/generic/jylhis-palette.nix`):

- **Qt (qt5ct/qt6ct/Kvantum)** — Stylix-owned (the `qt` target is **not** in
  `theme.nix`'s `disabledTargets`, `modules/generic/theme.nix:27-45`). Reads
  `~/.config/qt{5,6}ct/qt{5,6}ct.conf` + a palette `.conf`, or a Kvantum
  theme. qt5ct/qt6ct pick up on **new instances**; Kvantum can be told to
  reload running apps. Runtime path: emit a per-variant qtct colorscheme
  (and/or ship design's Kvantum `JylhisDark.colors`/`JylhisLight.colors`,
  `design:platforms/kvantum/`) into the theme dir, relink on switch, set
  `QT_QPA_PLATFORMTHEME`. **Biggest single blocker to retiring Stylix.**
- **bat** (`modules/home/bat.nix`) — reads `~/.config/bat/config` (`theme=`)
  plus a themes cache; both `jylhis-{dark,light}.tmTheme` are already
  installed (`bat.nix:17-22`). No daemon → **next invocation** is "live".
  Runtime: emit a one-line `theme=jylhis-<v>` fragment into the theme dir,
  relink `bat/config`. Trivial for the Jylhis pair; base16 schemes need a
  generated `.tmTheme` (pure templating, see IFD note).
- **fzf** (`modules/home/fzf.nix`) — colors via `programs.fzf.colors` →
  `--color` in `FZF_DEFAULT_OPTS`, fixed at shell init. **Next fzf
  invocation**. Runtime: write the `--color` string per variant into the
  theme dir, source it from the shell; cannot restyle an already-open fzf.
- **starship** (`modules/home/starship.nix`) — installs the design
  `starship.toml` verbatim (`starship.nix:16`). Per design's own notes the
  shell preset is **ANSI-name based and theme-agnostic**, so it already
  tracks whatever ANSI palette Ghostty paints — i.e. **effectively already
  runtime** via the live Ghostty theme. Likely needs nothing; confirm no
  hard-coded hexes in the toml.
- **hyprlock** (`modules/home/hyprlock.nix`) — reads `hypr/hyprlock.conf` at
  each lock; colors baked from `palette.hex` at build (`hyprlock.nix:57-99`).
  **Next lock** is "live" (no persistent surface between locks). Runtime:
  emit a hyprlock colors include per variant/scheme into the theme dir and
  `source=` it (hyprlock supports `source`), or relink. fontScale geometry
  can stay build-time.
- **console / TTY** (`modules/nixos/console.nix`) — `console.colors` = 16
  hex applied at boot via `earlySetup`. The live VT palette **can** be
  reset at runtime: `setvtrgb` rewrites the 16-colour table for all VTs and
  cells recolour (they reference palette indices). So TTY is genuinely
  runtime-able. Runtime: emit the `tty16` table per variant/scheme into the
  theme dir; `activateThemeDir` runs `setvtrgb` best-effort (same tolerance
  as the other actuations).
- **plymouth** (`modules/nixos/plymouth.nix`) — boot splash only, rendered
  in initrd via `pkgs.plymouth-marchyo-theme.override { variant }`
  (`plymouth.nix:13-18`). **Cannot be made runtime in any useful sense** —
  it is not on screen during a session. The only coherent improvement is
  that the *next* boot matches the last runtime choice, which needs a state
  marker consumed at rebuild/activation (still not runtime). Recommend
  leaving it build-time and documenting that.

---

## 2. Correctness review (ranked)

### F1 — MEDIUM (latent today): `replaceStrings` cannot disambiguate two tokens that share a source hex

`theme-runtime.nix:38-40` builds the swap as a flat
`builtins.replaceStrings (hexesFor buildVariant) (hexesFor otherVariant)`
keyed on raw hex. When two distinct tokens have the **same** hex in the build
variant but **diverge** in the other, `replaceStrings` takes the first match
(token order = `lib.attrNames`, alphabetical) and the second token is swapped
to the wrong colour.

Concrete input (verified against `design:themes/jylhis.json`):

- `status-info` and `syn-variable` are **both** `#005e8a` in *light*, but in
  *dark* they are `#17a4ed` and `#00a3ee` respectively.
- With `buildVariant = "light"`, `hexesFor "light"` lists `#005e8a` twice;
  `status-info` sorts before `syn-variable`, so **every** `#005e8a` →
  `#17a4ed`. A `#005e8a` that meant `syn-variable` renders as `status-info`.
- (`accent` and `cursor` also collide — `#f5a351` dark / `#693900` light —
  but map *identically*, so that collision is harmless.)

Why it is only latent: neither `status-info` nor `syn-variable` currently
appears in any swapped surface (verified: `grep` for `005e8a / 17a4ed /
00a3ee` across the waybar/mako/gtk reference surfaces is empty), and the
default `buildVariant` is `dark`, whose only collision is the harmless
`accent`/`cursor` pair. So the common path is safe **today**. It breaks
silently the moment a swapped surface uses one of those tokens in a
light-default build.

Fix options: (a) add an eval assertion that `hexesFor buildVariant` has no
hex that maps to more than one distinct `otherVariant` hex (fail the build on
a divergent collision); or (b) translate structurally per token rather than
textually by raw hex (larger change).

### F2 — LOW–MEDIUM: the `shade_color` decimal `rgba()` literal is not translated for base16-scheme themes

The GTK css carries one raw decimal colour, `@define-color shade_color
rgba(209, 212, 220, 0.08)` in dark / `rgba(42, 45, 51, 0.08)` in light
(verified in `design:platforms/gtk/jylhis-{dark,light}.css:40`; these are the
`text` token's RGB). The Jylhis light↔dark swap handles it via `swapShadeRgba`
/ `textFor` (`theme-runtime.nix:46-61`). But `mkSchemeThemeDir`
(`theme-runtime.nix:284-286`) uses `swapToScheme`, which is **hex-only**
(`theme-runtime.nix:207-208`) and never applies the shade swap. So every
tinted-scheme theme's `gtk.css` keeps the build-variant's text-coloured 8%
shade (e.g. a `nord` theme built on a dark default keeps
`rgba(209,212,220,0.08)`). Low severity (an 8%-alpha hairline overlay) but it
is the exact "decimal literal slips through unswapped" the brief asks about,
and it is live for schemes now. Note the other decimal-ish forms,
`alpha(@accent_color, …)` / `alpha(@window_fg_color, …)`, are safe because
they indirect through `@define-color` names whose hexes *do* swap.

Fix: fold the shade translation into `swapToScheme` (map the `text`-token RGB
to the scheme's `base05` RGB), or have the upstream generator emit an explicit
shade token so no decimal parsing is needed (upstream dependency if the token
set gains a `shade`/overlay colour).

### F3 — LOW (scheme-only cosmetic): `tokenSlots` role approximations collapse distinct roles

`theme-runtime.nix:179-202`. The 16 exact base16 pairs are fine; the five
"closest slot by role" extras are lossy for tinted schemes only (the Jylhis
pair never hits them — `swapToOther` is exact per token):

- `accent-hover → base09` = **identical to `accent`** → the hover delta
  disappears (GTK uses both: `#ffb063` accent-hover and `#f5a351` accent are
  present in `design:platforms/gtk/jylhis-dark.css`).
- `border`, `syn-comment → base03` (= `text-faint`); `border-strong → base04`
  (= `text-muted`).
- `accent-subtle → base01` (= `bg-subtle`, a near-background) — a trap if a
  future swapped surface ever puts text on `accent-subtle` (today only
  `fzf bg+` uses it and fzf is not swapped, so no live contrast failure).
- `status-ok → base0B` (= `syn-string`) — fine, that is the standard base16
  green.

The code comment claiming these tokens "don't appear in the swapped surfaces"
is inaccurate for `accent-hover` and `border` (both are in the GTK css); the
effect is cosmetic, not broken. Severity low because schemes are opt-in.

### F4 — LOW (robustness): the swap rests on an unenforced invariant

The whole translation assumes every colour in a swapped surface is a
lowercase, 6-digit, semantic-token hex. All three hold today (verified:
reference CSS is lowercase and matches the JSON casing; no 8-digit hex in any
surface; ANSI/collision tokens absent). Nothing enforces them:

- **Casing** — if upstream ever emits uppercase hex in a surface while
  `jylhis.json` stays lowercase, `hexesFor` won't match and the swap silently
  no-ops (the "other variant" dir ships build-variant colours).
- **8-digit hex** — a future `#rrggbbaa` would have its first 6 digits
  replaced and the `aa` left dangling → corrupt colour (`replaceStrings` does
  one left-to-right pass; no cascade, but no length-awareness either).
- **New literals / ANSI** — ANSI hexes are excluded by construction
  (`hex = p // s // sy`, ANSI is a separate attr); a surface adding an
  ANSI-only colour or a new decimal literal is silently left unswapped.

Fix: an eval/determinism check that every hex in each resolved surface is in
`hexesFor buildVariant`, so an un-swappable literal fails the build instead of
shipping a badly-themed dir. This also backstops F1 and F2.

### F5 — LOW: `theme generate` (matugen) restyles fewer surfaces than `theme set`

`theme.ts:407-441` writes only `colors.json`, `variant`, `hyprland.conf`,
`ghostty.conf`, `wallpaper.png` into the generated dir — no
`mako.conf`/`waybar.css`/`gtk.css`. `activateThemeDir` (`theme.ts:118-167`)
therefore skips mako/waybar/GTK for a generated theme, so those surfaces keep
the previously-active theme while shell/ghostty/hyprland/wallpaper change.
Inconsistent vs `theme set`. Fix: run the same slot swap over the resolved
mako/waybar/gtk text with the matugen base16 result (all inputs are present),
or document the limitation.

### F6 — activation hook: correct for intended flows, one undocumented wedge

`resetThemeRuntimeSurfaces` (`theme-runtime.nix:353-372`):

- **readlink guard is correct.** The CLI only ever links these paths to
  `…-marchyo-theme-*` store paths (pointer → `entry.dir`; relinked configs →
  `join(entry.dir, file)`, `theme-assets.ts:110-118`, `theme.ts:61-66`) or to
  `${stateHome}/marchyo/generated-theme*` (matugen). Both globs match, and
  matching the *immediate* target (not `realpath`) is right because the links
  point straight at the store/state path.
- **Real file** → `-L` false → falls through to HM's normal backup/clobber
  path. Correct and intended.
- **Foreign symlink** (target matches neither glob — e.g. a user- or
  third-party-created link on one of the five paths) is **not** removed, so
  HM's `checkLinkTargets` aborts activation with "would be clobbered", and
  neither `backupFileExtension` nor `backupCommand` rescues a symlink. That is
  arguably safe-by-default, but it is a real failure mode the module header
  does not mention (it documents only the marchyo-link case). Worth a doc
  note.

Net: the hook is sound; only the foreign-symlink wedge is undocumented.

### Coupling checks that currently hold (no finding, but fragile-by-convention)

- `mako` swap depends on HM rendering `services.mako.settings` into
  `xdg.configFile."mako/config"` — confirmed in the HM mako module
  (`xdg.configFile."mako/config"` at its line 158). `mako.nix` uses
  `settings`, so the coupling holds.
- `waybar` swap depends on `programs.waybar.style` being a string —
  `waybar.nix:199` sets `style = upstreamCss + marchyoCss` (string). Holds.
- GTK runtime path depends on `gtk.gtk3.extraCss` text, sourced from
  `design:platforms/gtk/jylhis-<mode>.css` (`jylhis-theme.nix:25`). Those
  per-mode files are **git-tracked** in design (only `platforms/gtk/gtk.css`
  is gitignored), and read from the source input, so this is IFD-free and the
  file is present. Holds.

---

## 3. Extension plan (ordered) and Stylix retirement

Minimal, each step is additive and independently shippable. Each new asset in
a theme dir needs a `testNixOS` eval assertion in `tests/eval/themes.nix`
(assert the new file appears in the dir / manifest) and a `theming.mdx`
update (`site/src/content/docs/docs/configuration/theming.mdx`).

**Step 0 (prereq, addresses F1/F2/F4).** Add the eval assertion that the swap
is lossless before widening surfaces, so any new surface that introduces a
divergent collision, a new decimal literal, or a non-matching hex fails the
build loudly instead of shipping a badly-themed dir.

**Step 1 — bat.** Emit `bat.conf` (`theme=jylhis-<v>`) into `themeDirFor` /
`mkSchemeThemeDir`; relink `~/.config/bat/config` in `activateThemeDir` (no
reload; next invocation). Jylhis pair is trivial. Scheme support needs a
generated `.tmTheme` (see IFD note).

**Step 2 — fzf.** Emit the `--color` string per variant/scheme into the theme
dir; source it from the shell (relinked fragment). Next fzf invocation picks
it up.

**Step 3 — hyprlock.** Emit a hyprlock colours include per variant/scheme;
`source=` it from `hyprlock.conf` (or relink). Next lock picks it up.
fontScale geometry stays build-time.

**Step 4 — console/TTY.** Emit the 16-entry `setvtrgb` table per
variant/scheme; `activateThemeDir` runs `setvtrgb` best-effort. Genuinely
live. (NixOS-only module — fine.)

**Step 5 — Qt (the big one).** Ship design's Kvantum themes
(`design:platforms/kvantum/`) and/or emit per-variant qt5ct/qt6ct colour
schemes from the palette; set `QT_QPA_PLATFORMTHEME`; relink the active scheme
on switch; optionally poke Kvantum to reload. New Qt instances restyle;
Kvantum can live-reload. This is what currently keeps Stylix mandatory.

**Step 6 — re-home fonts + cursor (pure re-homing, not runtime).** Move the
font stack and cursor off Stylix (`modules/generic/stylix.nix:38-74`) into a
marchyo-owned module:

- fonts: `fonts.packages` + a fontconfig `defaultFonts` generator (serif =
  Zilla Slab, sansSerif = Hanken Grotesk, monospace = BlexMono Nerd Font) and
  the four size knobs (currently `stylix.fonts.sizes.*`, scaled by
  `lib/font-scale.nix`). Also the GNOME/dconf interface font that Stylix's
  `gnome` target writes.
- cursor: `home.pointerCursor` (already partly seeded in
  `jylhis-theme.nix:56`).

Fonts and cursor don't change per theme, so no runtime work — just ownership.

**Step 7 — retire Stylix.** Once Qt + fonts + cursor + the base16 fallback
are marchyo-owned:

- remove `stylix` and `stylix-stable` inputs (`flake.nix:47-55`) and their
  `osConfig ? stylix` / `options ? stylix` plumbing;
- delete `modules/generic/stylix.nix`;
- collapse `modules/generic/theme.nix` — it exists almost entirely to disable
  Stylix targets and set `polarity`; with Stylix gone the `disabledTargets`
  list and most of the module disappear;
- simplify the `eval-themes-light-dconf-color-scheme` test rationale
  (`tests/eval/themes.nix:79-94`): that conflict is Stylix's `gnome` target
  vs HM's gtk, so removing Stylix removes the conflict.

**Coverage lost → replacement**

- base16 fallback for `marchyo.theme.scheme` → already have `jylhis-palette` +
  `base16-scheme` loader; plumb the palette into each surface directly (done
  everywhere except Qt, which Step 5 covers).
- Qt → Step 5.
- fonts (fontconfig + app/terminal/desktop/popup sizes, GNOME interface
  font) → Step 6.
- cursor → Step 6.
- **Stylix `autoEnable` long tail** — before deleting anything, enumerate
  `config.stylix.targets` on a *built* host config and diff against
  `disabledTargets` to find every surface Stylix silently themes that marchyo
  does not yet own (candidates: `gnome`, `qt`, `fontconfig`, and any
  greeter/bootloader targets). Anything there is a hidden coverage loss and
  must get an explicit marchyo owner before Stylix leaves.

**Cannot be made runtime:** plymouth (boot-only; see §1). Everything else
reaches at least next-instance; console + the §1 "already runtime" set are
fully live; bat/fzf/starship/hyprlock/Qt are next-invocation/next-instance
(acceptable — no persistent styled surface, except Qt where Kvantum can
live-reload).

---

## 4. Hard-constraint verification

- **IFD-free.** Every proposed emitter reads from `pkgs.jylhis-design-src`
  (source input) or computes from `palette.hex` / base16 `slots` in pure Nix.
  The one trap: generating per-scheme `.tmTheme` (bat) or qt colour schemes
  must be **pure string templating**, never `readFile` of the built
  `pkgs.jylhis-themes` derivation — that is IFD and is exactly why
  `jylhis-theme.nix` already avoids the upstream targets. Note bat.nix today
  references `${pkgs.jylhis-themes}/share/...` as a *path* (`bat.nix:10`),
  which is a store-path string, not `readFile` → IFD-free; keep it a path.
- **Platform-neutral options.** Most steps add no option (they extend
  `theme-runtime.nix` emitters + the CLI). Any new option goes in
  `modules/nixos/options/theme.nix` as a neutral declaration; impl stays in
  `modules/home/*` / `modules/nixos/*`. Console/TTY and plymouth are already
  NixOS-only modules. The Darwin eval gate is unaffected.
- **Tests + docs.** Each new surface needs a `testNixOS` assertion in
  `tests/eval/themes.nix` and a `theming.mdx` update. The existing
  manifest/catalog tests (`tests/eval/themes.nix`,
  `tests/eval/theme-catalog.nix`) are the pattern to extend.
- **Declarative only.** All actuation stays the CLI's symlink-swap +
  best-effort reload; the ephemeral-overlay reset
  (`resetThemeRuntimeSurfaces`) already restores declarative state on
  rebuild. No imperative installs proposed.
- **No upstream design edits.** If a surface cannot be driven from the current
  token set — the clearest candidate is an explicit `shade`/overlay colour to
  retire the decimal `rgba()` literal (F2), and possibly distinct
  hover/subtle/border tokens to remove the base16 approximations (F3) — that
  is an **upstream dependency** on `jylhis-design`, not a marchyo change.
- **Verification stops at build.** All findings were reached by reading
  sources and the committed token/reference files; nothing was activated or
  rebuilt.
