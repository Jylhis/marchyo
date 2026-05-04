# Feedback for `Jylhis/design` from the marchyo integration

This report captures friction points and improvement ideas observed while
adopting `github:Jylhis/design` as the theming source of truth in
[`jylhis/marchyo`](https://github.com/jylhis/marchyo). It is intended as
upstream input — what worked well, what required workarounds, and what would
make the design system easier to consume in NixOS/Home-Manager configurations
beyond marchyo.

Marchyo at the time of this report:

- Consumes `pkgs.jylhis-themes` (built from `nix/themes.nix`) implicitly
  through `nix/home-manager-module.nix`.
- Reads `tokens.json` directly via `builtins.fromJSON` to derive a base16
  attrset, an ANSI-16 list, and a named-token map.
- Imports `nix/home-manager-module.nix` as a Home-Manager module.
- Composes upstream `platforms/waybar/style.css` with a marchyo overlay.

## What worked very well

1. **`tokens.json` is the right source of truth.** The structure is regular
   (every color exposes `light` / `dark`), machine-readable, and directly
   maps to the slots a base16 scheme needs. Reading it once via
   `builtins.fromJSON` and projecting it to base16 / ANSI-16 / named
   accessors took ~50 lines of Nix and replaced ~140 lines of duplicated
   hex literals.

2. **`pkgs.jylhis-themes` is a clean derivation.** Stable layout under
   `share/jylhis/<target>/...`, no dependency on the source tree in
   downstream modules. This is preferable to consuming
   `inputs.jylhis-design` as a raw source.

3. **Light/dark variant naming is unambiguous** (`paper` / `roast`). The
   one-bit translation from `marchyo.theme.variant ∈ { dark, light }` was
   trivial.

4. **Per-target opt-in toggles** in `home-manager-module.nix`
   (`jylhis.theme.{ghostty,mako,waybar,gtk,starship,fzf,bat}.enable`)
   matched our needs exactly when we wanted to compose marchyo logic on
   top of upstream output.

## Concrete improvement opportunities

### 1. `home-manager-module.nix` should set `FZF_DEFAULT_OPTS` at `lib.mkDefault`

**Symptom**: enabling the upstream HM module on a system that also imports
`programs.fzf` (HM module — set automatically by Stylix's `fzf` target,
even when the user only declares `programs.fzf.enable = true` indirectly)
fails with:

```
The option `home.sessionVariables.FZF_DEFAULT_OPTS' has conflicting definition values:
  - In `.../jylhis-design/nix/home-manager-module.nix': "--color=fg:#e8e0d4,bg:#1a1714,..."
  - In `.../home-manager/modules/programs/fzf.nix': "--color bg:#1a1714,bg+:#242019,..."
```

**Fix**: wrap the assignment with `lib.mkForce` (the design system value is
authoritative for users who imported the module) or `lib.mkDefault` (allows
overrides without errors). Concretely:

```nix
# nix/home-manager-module.nix — current
home.sessionVariables = lib.mkIf cfg.fzf.enable {
  FZF_DEFAULT_OPTS = "--color=fg:${...},bg:${...},...";
};

# proposed
home.sessionVariables = lib.mkIf cfg.fzf.enable {
  FZF_DEFAULT_OPTS = lib.mkForce "--color=fg:${...},bg:${...},...";
};
```

`mkForce` is the right choice: if a user has explicitly imported the
Jylhis HM module, they want jylhis colors to win over Stylix or any
other base16 derivation.

### 2. `nix/themes.nix` could expose targeted sub-derivations

Currently `pkgs.jylhis-themes` produces a single multi-output prefix
(`share/jylhis/{ghostty,mako,waybar,...}`). Consumers that want only one
target (e.g. just bat, just waybar) end up rebuilding the whole package.

A sub-attribute layout would help:

```nix
# nix/themes.nix → attrset of derivations
{ ghostty, mako, waybar, bat, gtk, kvantum, hyprland, base16 } : ...
# or expose them as outputs:
outputs = [ "out" "ghostty" "mako" "waybar" "bat" "gtk" "kvantum" "hyprland" "base16" ];
```

This is also a precondition for shipping a `flake.nix` that exposes
`packages.<system>.<target>` (see #5 below).

### 3. Ship a base16 YAML at a stable path

`platforms/base16/jylhis-{paper,roast}.yaml` exist but aren't installed by
`nix/themes.nix`. NixOS/HM users with Stylix often want a
`base16Scheme = "${pkgs.base16-schemes}/share/themes/<name>.yaml"`-style
indirection, and shipping the file under
`share/jylhis/base16/jylhis-{paper,roast}.yaml` would let them use the
upstream YAML with no Nix-side palette code:

```nix
stylix.base16Scheme = "${pkgs.jylhis-themes}/share/jylhis/base16/jylhis-roast.yaml";
```

Today marchyo computes the equivalent in Nix from `tokens.json` because
the YAML isn't where it expected.

### 4. Waybar coverage gap: extra selectors

The upstream `platforms/waybar/style.css` assumes a fairly minimal module
list. Real-world waybars commonly include `#wireplumber`, `#bluetooth`,
`#power-profiles-daemon`, `#hyprland-language`, `#custom-expand-icon`
(tray drawer pattern), and `#tray > .needs-attention`. Marchyo had to
append a small CSS overlay covering these, otherwise their padding /
muted-state colors are wrong.

These selectors don't add new tokens — just one more rule mapping to
`text-faint` (muted) and `accent` (needs-attention). Adding them
upstream in `platforms/waybar/style.css` (and `style-paper.css`) would
let downstream consumers drop their overlay entirely.

### 5. Consider adding a `flake.nix` to the design system

Today `Jylhis/design` is consumed as `flake = false;`. That works but
forces every consumer to:

- Use `pkgs.callPackage` against an in-tree path (`./nix/themes.nix`).
- Build their own overlay to expose `pkgs.jylhis-themes`.
- Pin `inputs.jylhis-design` separately and remember to bump it.

A small `flake.nix` exposing:

```
outputs = { self, nixpkgs, ... }: {
  packages.<system>.default = ...;        # = themes
  packages.<system>.{ghostty,mako,...} = ...;  # per-target
  homeManagerModules.default = import ./nix/home-manager-module.nix;
  homeModules.default = ...;              # for the future modern naming
  overlays.default = final: prev: {
    jylhis-themes = final.callPackage ./nix/themes.nix { };
  };
};
```

…would let consumers write:

```nix
inputs.jylhis-design.url = "github:Jylhis/design";
# in their config:
imports = [ inputs.jylhis-design.homeManagerModules.default ];
nixpkgs.overlays = [ inputs.jylhis-design.overlays.default ];
```

…with no shim package files, no `callPackage` boilerplate, and no
`pkgs.jylhis-design-src = inputs.jylhis-design;` overlay trick.

### 6. Plymouth / boot splash story is missing

The system covers the desktop but stops at "first frame after Plymouth
exits." Two specific surfaces are uncovered:

- **Linux virtual console (TTY) palette** — `console.colors` in NixOS
  takes 16 hex strings (no `#`). The ANSI-16 list in `tokens.json` is
  exactly this shape. A short `platforms/console/jylhis-{paper,roast}.nix`
  fragment, or just documentation in `platforms/KEYBOARD.md`-style,
  pointing at the canonical mapping would be welcome.

- **Plymouth theme** — there's no `platforms/plymouth/...` directory.
  Marchyo ships a hand-made theme (`packages/plymouth-marchyo-theme/`)
  with PNG assets baked at the marchyo level. A reference plymouth
  theme — even just colored text + spinner — generated from `tokens.json`
  would let downstream consumers cover the entire boot path with one
  cohesive look.

### 7. Tuigreet / regreet (greeter) reference snippet

Tuigreet is the most common login frontend on Hyprland setups. Its
`--theme` argument uses ANSI color names that resolve to whatever palette
the kernel/console has set. Documenting the recommended mapping (e.g.
"prompt = bright-yellow → brand copper") in `platforms/KEYBOARD.md` or a
new `platforms/greeters/README.md` would save consumers from
re-deriving it. Same applies to `regreet` (which Stylix targets natively
but the Jylhis-specific mapping isn't documented).

### 8. Mention Stylix interaction in `docs/INTEGRATION.md`

NixOS users typically already have Stylix configured. Without explicit
guidance, importing the Jylhis HM module on top of Stylix produces a
several-fan conflict (FZF as in #1, sometimes GTK CSS double-write,
etc.). A short paragraph along the lines of:

> If you also use Stylix, disable the targets it duplicates (`fzf`,
> `bat`, `gtk`, `starship`, `hyprland`, `waybar`, `mako`, `ghostty`,
> `hyprlock`, `console`) on the home-manager side. Stylix's `qt` target
> can stay enabled — it'll derive Qt colors from the base16 palette,
> which can also come from `tokens.json`.

…would make adoption a 5-minute job instead of a debugging session.

### 9. Hyprland fragment is helpful, but consumers want a single `source =` line

`platforms/hyprland/jylhis.conf` plus `jylhis-{roast,paper}.conf` work,
but the README doesn't say which to source first or whether to merge.
Marchyo ended up replicating the `general` / `decoration` / `animations`
sections in Nix because the source-line composition rules weren't
obvious. A README example like:

```
# In ~/.config/hypr/hyprland.conf
source = ~/.config/hypr/jylhis.conf
source = ~/.config/hypr/jylhis-roast.conf  # or jylhis-paper.conf
source = ~/.config/hypr/jylhis-keys.conf   # optional
# …user overrides below…
```

…makes it clear both files are intended to be sourced together.

### 10. ANSI 7 / 15 are unreadable as foreground on the paper variant

**Symptom**: any TUI app that emits `\e[37m` (white = ANSI 7) or `\e[97m`
(bright-white = ANSI 15) renders as near-invisible text on the paper
background. Concrete cases observed in marchyo: `claude` (Claude Code
CLI) status text, some `git`/`grep` output, and several REPL prompts.

The cause: `tokens.json` paper variant maps

```
ansi[7]  (white)        → #e8e1d6   /* same as palette.surface */
ansi[15] (bright-white) → #fefdfb   /* same as palette.surface-raised */
```

These are **background tones**, not foreground tones. When apps that
were designed against a dark terminal print "white" text, the result
becomes unreadable on paper.

**Roast variant doesn't have this issue** — there `ansi[7]` and
`ansi[15]` map to the cream tones, which read fine on the dark roast
background.

**Suggested fix**: invert the convention for paper. Either

- swap to readable foreground tones:
  ```
  ansi[7]  → #6b5f54  /* text-muted */
  ansi[15] → #2c2825  /* text */
  ```
- or, if the current Modus mapping must be preserved, document the
  expectation that *applications targeting the paper variant must not
  use ANSI 7/15 as foreground* and provide a per-app override recipe
  (Ghostty's `palette = 7=...` line, bat's `--color=normal:`, etc.).

This is the single biggest readability issue we hit with the paper
variant.

### 11. Variant-switch automation hook

`jylhis-theme-toggle.el` exists for Emacs. A symmetric story for the
desktop — e.g. a small shell script under `platforms/scripts/` that
flips a `~/.config/jylhis/active-theme` symlink and emits a signal HM
modules can react to (or just emits `kill -SIGUSR1 waybar`-style
reload calls) — would close the loop on day/night switching.

## Summary table

| # | Area | Effort | Impact |
|---|---|---|---|
| 1 | `mkForce` on `FZF_DEFAULT_OPTS` | trivial | unblocks Stylix coexistence |
| 2 | Per-target outputs in `themes.nix` | small | smaller closures for single-target consumers |
| 3 | Ship base16 YAML in `themes.nix` | trivial | one-liner Stylix integration |
| 4 | Add missing waybar selectors | small | drops the marchyo overlay |
| 5 | `flake.nix` with `homeModules.default` + overlay | small | removes consumer boilerplate |
| 6 | Plymouth + console reference assets | medium | covers boot/login surfaces |
| 7 | Tuigreet/regreet recipe | trivial (docs) | consistent login screen |
| 8 | Stylix interaction note | trivial (docs) | avoids first-time-user pain |
| 9 | Hyprland source order in README | trivial (docs) | enables `source =` instead of replicating |
| 10 | Paper ANSI 7/15 readability | small (token swap) | unblocks paper variant for everyday TUI use |
| 11 | Theme-switch shell hook | small | closes day/night switching story |

## Stats

- Inline hex values **eliminated**: 140+ (one base16 attrset × 2 variants
  × 2 declaration sites, plus Hyprland border colors, Mako urgency
  colors, Hyprlock fields).
- New code shipped: ~50 lines (`modules/generic/jylhis-palette.nix`).
- Net reduction: ~90 lines, plus all of `assets/applications/waybar.css`
  (a 97-line drift-prone fork).
- All values now driven by a single `flake.lock` bump of
  `inputs.jylhis-design`.
