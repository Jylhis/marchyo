---
title: Networking
description: Wi-Fi, Bluetooth, Tailscale, and sharing files with LocalSend.
---

Networking on Marchyo mostly takes care of itself. NetworkManager handles wired and
wireless connections, Bluetooth is on whenever the desktop is, Tailscale is ready to
join your private network, and the firewall is up from the first boot. This chapter
covers the everyday parts: joining a network, pairing a device, reaching your other
machines, and sending a file across the room.

## Wi-Fi

Press `Super + Ctrl + W` to open the Wi-Fi manager, nmtui, in a floating terminal.
Pick **Activate a connection**, choose your network, and enter the password. You can
also get there from the system menu (`Super + Alt + Space`, then **Setup**, then
**Wifi**), or by clicking the network indicator in the top bar.

Networks you join are remembered by NetworkManager and reconnect on their own. That's
ordinary machine state, like a saved password, so it isn't part of your
configuration and doesn't change when you rebuild.

If you run the Marchyo shell, `Super + Shift + N` opens a Network panel with your
current connection, signal, and address, and a shortcut into nmtui.

## Bluetooth

Bluetooth is enabled with the desktop and powers on at boot. Press `Super + Ctrl + B`
to open bluetui, a terminal Bluetooth manager. From there you scan for devices, pair,
and connect. It's also under **Setup**, then **Bluetooth** in the system menu.
Headphones and speakers show up as audio outputs once connected; switch between them
in the audio mixer on `Super + Ctrl + A`.

## Tailscale

Tailscale connects your machines into a private network, so your laptop can reach
your desktop or home server from anywhere as if they were on the same LAN. Marchyo
runs it by default. The first time, sign in once from a terminal:

```bash
sudo tailscale up
```

That prints a link to log in with your Tailscale account. After that, the machine
stays on your tailnet across reboots.

With the Marchyo shell on, your user is set as the Tailscale operator, so the
Tailscale tile in the Control Center can connect and disconnect without `sudo`. If
the machine has several Marchyo users, the first one by name gets it, because
Tailscale allows only one operator. To choose a different user:

```nix
marchyo.services.tailscale.operator = "alice";
```

Marchyo treats the Tailscale interface as **trusted**. The firewall doesn't filter
traffic arriving over Tailscale, so any service you run is reachable by your other
Tailscale devices without opening ports one by one. Traffic from the rest of the
internet and your local network still goes through the firewall as normal. This is
the right default when your tailnet contains only machines you own. If you share it
with other people, use Tailscale's own access controls to limit who can reach what.

If you don't use Tailscale, turn it off:

```nix
marchyo.services.tailscale.enable = false;
```

## LocalSend

LocalSend sends files between devices on the same network, with no cable, account,
or cloud in between. It works with LocalSend on phones and other computers, whatever
they run. Open LocalSend from the launcher (`Super + R`); nearby devices running it
appear automatically. Pick one, choose your files, and accept on the other side.

If Nautilus is your file manager, there's also a shortcut: right-click a file, open
**Scripts**, and choose **Send with LocalSend**. That opens LocalSend, ready for you
to pick the files to send.

LocalSend comes with the desktop. For other devices to find yours, it opens port
53317 (TCP and UDP) on your network. If you'd rather not have it, switch it off and
the port closes with it:

```nix
marchyo.services.localsend.enable = false;
```

## The firewall

The firewall is on by default. Incoming connections are blocked unless something has
asked for them: Marchyo opens only what its own features need, such as LocalSend's
port, Tailscale's connection port, and local network discovery so your machine can
find printers and other devices by name. Outgoing traffic is not restricted.

To open a port for something you run yourself, add it to your configuration:

```nix
networking.firewall.allowedTCPPorts = [ 8080 ];
```

To turn the firewall off entirely, for example on a machine that sits behind another
firewall, set `marchyo.security.firewall.enable = false`. Features that open ports
keep declaring them, but nothing is blocked while the firewall is off.
