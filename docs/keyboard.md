# Keyboard Configuration

Marchyo provides a unified way to configure keyboard layouts, variants, input methods (IMEs), and XKB options across the system (TTY/console) and the desktop environment (Hyprland + fcitx5).

All keyboard settings are configured under the `marchyo.keyboard.*` namespace.

## Layouts and Input Methods

The `marchyo.keyboard.layouts` option accepts a list of layouts. Each layout can be defined as a simple string or an attribute set for more advanced configuration.

### Simple Layouts

For basic layouts, you can just provide the layout code:

```nix
marchyo.keyboard.layouts = [
  "us"
  "fi"
  "de"
];
```

### Advanced Layouts (Variants and IMEs)

If you need specific layout variants (like US International) or Input Method Engines (IMEs) for languages like Chinese, Japanese, or Korean, use an attribute set:

```nix
marchyo.keyboard.layouts = [
  "us"                                   # Simple layout
  { layout = "us"; variant = "intl"; }   # US international with dead keys
  { layout = "cn"; ime = "pinyin"; }     # Chinese with Pinyin IME
  { layout = "jp"; ime = "mozc"; }       # Japanese with Mozc IME
  { layout = "kr"; ime = "hangul"; }     # Korean with Hangul IME
];
```

When an entry includes `ime`, the input method engine will be automatically activated when you switch to that layout.

Available IMEs:
- `pinyin`: Chinese Pinyin input (requires `fcitx5-chinese-addons`)
- `mozc`: Japanese input (requires `fcitx5-mozc`)
- `hangul`: Korean input (requires `fcitx5-hangul`)
- `unicode`: Unicode character picker

## Keyboard Switching Options

You can customize how you switch between layouts and IMEs.

### XKB Options

Use `marchyo.keyboard.options` to pass standard XKB options. By default, it is set to use Super+Space to toggle layouts:

```nix
marchyo.keyboard.options = [
  "grp:win_space_toggle"  # Use Super+Space to switch inputs
  "ctrl:swapcaps"         # Swap Caps Lock and Left Control
];
```

### Compose Key

The compose key allows you to type special characters by pressing the compose key followed by a sequence of characters (e.g., Compose + ' + e = é).

Configure it using `marchyo.keyboard.composeKey`:

```nix
marchyo.keyboard.composeKey = "ralt";  # Default: Right Alt
```

Common values:
- `ralt`: Right Alt key
- `rwin`: Right Super/Windows key
- `caps`: Caps Lock key
- `menu`: Menu key
- `null`: Disable compose key entirely

### IME Auto-Activation

By default, switching to a layout with an associated IME will automatically activate it. To disable this behavior:

```nix
marchyo.keyboard.autoActivateIME = false;
```

### Manual IME Toggle

If you prefer to toggle the IME manually rather than tying it to layout switching, you can specify trigger keys:

```nix
marchyo.keyboard.imeTriggerKey = [ "Super+I" ];
```

## How It Works Under the Hood

1. **NixOS (`services.xserver.xkb`)**: The basic layout codes and variants are applied to the console/TTY to provide fallback support outside the graphical environment.
2. **Hyprland (`home.keyboard`)**: The layout and XKB options are passed to Hyprland's input configuration.
3. **fcitx5**: Acts as the authoritative input manager in the graphical environment, reading your configured layouts, activating IMEs, and managing layout switching.
