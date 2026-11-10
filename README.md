# Marchyo

Marchyo is a declarative NixOS desktop: Hyprland, a Quickshell shell, a
matched theme and a curated set of apps, configured through `marchyo.*`
options in a single flake.

Read more at [marchyo.org](https://marchyo.org/).

## Quick start

Start from the template:

```bash
nix flake init -t github:Jylhis/marchyo#workstation
```

or add Marchyo as your only input:

```nix
{
  inputs.marchyo.url = "github:Jylhis/marchyo";

  outputs = { marchyo, ... }: {
    nixosConfigurations.myhost = marchyo.lib.mkNixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        {
          marchyo.desktop.enable = true;
          marchyo.users.me = { fullname = "Your Name"; email = "you@example.com"; };
        }
      ];
    };
  };
}
```

## The Marchyo Manual

The manual lives in [`manual/`](manual/), which is its authoritative source.

- [Welcome to Marchyo](manual/01-welcome-to-marchyo.md)

**The Basics**

- [Getting Started](manual/02-getting-started.md)
- [Coming from Other Distros](manual/03-coming-from-other-distros.md)
- [Navigation](manual/04-navigation.md)
- [The Top Bar](manual/05-the-top-bar.md)
- [Themes](manual/06-themes.md)
- [Hotkeys](manual/07-hotkeys.md)
- [The Marchyo CLI](manual/08-the-marchyo-cli.md)
- [Default Apps](manual/09-default-apps.md)

**Configuration**

- [Updating](manual/10-updating.md)
- [Monitors](manual/12-monitors.md)
- [Networking](manual/13-networking.md)
- [Hardware Authentication](manual/14-hardware-authentication.md)

**The Rest**

- [Troubleshooting](manual/11-troubleshooting.md)

The full option reference is at [marchyo.org/docs](https://marchyo.org/docs).
Contributors start at [`docs/`](docs/) and [`AGENTS.md`](AGENTS.md).

## License

Marchyo is released under the [MIT License](LICENSE).
