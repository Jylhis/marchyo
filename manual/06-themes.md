---
title: Themes
description: Dark and light, switching at runtime, fonts, and the wallpaper.
---

Marchyo comes with a single, coherent look already applied. Every surface — the
terminal, the bar, the launcher, notifications, the lock screen, your GTK apps, even
the boot splash — is colored from one design system, so nothing clashes and nothing
looks half-themed. You don't assemble a theme here; you pick a variant and, if you
like, swap it out at runtime.

## Dark or light

Out of the box you're on the dark variant. To live in light instead, set the variant
in your configuration and rebuild:

```nix
marchyo.theme.variant = "light";
```

Both variants share the same palette family — a cool, near-neutral ground with a
single bronze accent — so switching between them feels like the same desktop at a
different time of day, not a different desktop. Syntax highlighting in your editor
and terminal uses the Modus color sets, so code reads the same everywhere.

## Switching themes at runtime

Changing `variant` means a rebuild. For a faster swap, Marchyo pre-builds a set of
themes into your system so you can switch between them instantly, with no rebuild at
all. The [marchyo CLI](./08-the-marchyo-cli.md) drives it:

```bash
marchyo theme list        # what's available, with the active one marked
marchyo theme set light   # switch now
marchyo theme next        # cycle to the next one
```

By default the dark and light Jylhis themes are the two switchable options. You can
add more — any named [base16](https://github.com/base16-project) scheme works — by
listing them so they're built into the system ahead of time:

```nix
marchyo.theme.themes = [
  "jylhis-dark"
  "jylhis-light"
  "nord"
  "gruvbox-dark-hard"
];
```

Now `marchyo theme set nord` is instant. One thing to know: a runtime switch is
*ephemeral*. It changes the directly-themed surfaces — terminal, bar, launcher,
notifications, wallpaper — live, but the next rebuild resets everything to whatever
`variant` says. Runtime switching is for trying things and matching your mood; the
declarative `variant` is your real default.

## Fonts

Marchyo ships three typefaces that carry across the whole system: a slab serif for
headings, a grotesque for body text, and a Nerd Font monospace for the terminal and
all the desktop chrome (the icon glyphs in the bar and notifications need it). You
don't have to touch any of this — it's chosen to look right together.

If you want everything a little larger or smaller, there's one dial that moves every
text surface at once:

```nix
marchyo.theme.fontScale = 1.5;  # everything ~50% larger
```

It defaults to `1.25`, which is comfortably larger than typical Linux defaults. Set
it to `1.0` for standard sizes, or higher for a HiDPI screen you sit far from, or for
readability. Each surface scales from its own base size, so the proportions between,
say, the bar and the terminal stay right.

## Wallpaper

A generated Marchyo wallpaper is set for you and follows the active theme. To turn it
off, or point at your own wallpaper assets:

```nix
marchyo.theme.wallpaper.enable = false;
```

You can also change the wallpaper at runtime with `marchyo bg set <path>` or cycle
with `marchyo bg next`, though like a runtime theme switch, that lasts only until the
next rebuild.
