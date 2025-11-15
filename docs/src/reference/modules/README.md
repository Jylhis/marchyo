# Module Options Reference

Auto-generated reference documentation for all Marchyo module options.

## NixOS Module Options

Configuration options for NixOS system-level modules under the `marchyo.*` namespace.

[→ View NixOS Module Options](nixos-options.md)

## Home Manager Module Options

Configuration options for user-level modules in Home Manager.

[→ View Home Manager Module Options](home-options.md)

## Using Module Options

Options are configured in your `configuration.nix`:

```nix
{
  # NixOS options
  marchyo.desktop.enable = true;
  marchyo.theme.scheme = "dracula";

  # Home Manager options (per-user)
  home-manager.users.myuser = {
    programs.kitty.enable = true;
    services.mako.enable = true;
  };
}
```

## Option Types

- **Boolean**: `true` or `false`
- **String**: Text value in quotes
- **Integer**: Numeric value
- **List**: `[ item1 item2 item3 ]`
- **Attribute Set**: `{ key = value; }`
- **Null or Type**: Optional value, use `null` to disable

## Finding Options

Search options documentation:
- Use browser search (Ctrl+F)
- Check type and default value
- Read description for usage

## See Also

- [Feature Flags](../feature-flags.md) - High-level configuration
- [Tutorials](../../tutorials/adding-modules.md) - Learn about modules
