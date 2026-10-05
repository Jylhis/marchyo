---
title: Hardware Authentication
description: Fingerprint and FIDO2/U2F unlock on supported hardware.
---

Typing your password every time you unlock the screen or run `sudo` gets old. If your
machine has a fingerprint reader, or you own a hardware security key such as a
YubiKey, Marchyo can let you use it instead. Both are off by default because they
need hardware not every machine has. Turning one on takes two steps: set a flag and
rebuild, then enroll your finger or key once.

Your password keeps working either way. The fingerprint or key is an extra way in,
not a replacement, so you can't lock yourself out by forgetting your key at home.

## Fingerprint

Turn on fingerprint support in your configuration and rebuild:

```nix
marchyo.security.fingerprint.enable = true;
```

Then enroll a finger:

```bash
marchyo security enroll fingerprint
```

Follow the prompts and touch the reader several times until it reports the enrollment
complete.

From then on, the system accepts your fingerprint where it would ask for your
password, such as `sudo` and logging in. The lock screen follows the setting
automatically and unlocks with a touch, with no further setup. On a machine without
a reader, leave the flag off; the lock screen only looks for a reader when you've
said there is one.

## Security keys (FIDO2 / U2F)

A FIDO2 or U2F security key is a small USB or NFC device you touch to prove it's you.
Turn on support and rebuild:

```nix
marchyo.security.fido2.enable = true;
```

Then, with the key plugged in, enroll it:

```bash
marchyo security enroll fido2
```

When the key starts blinking, touch it. Marchyo registers the key to your user
account and tells you where it saved the registration. To add a spare key, plug it in
and run the same command again; each run adds one more key alongside the ones you
already have.

Once a key is enrolled, plug it in and touch it when asked. The system shows
"Please touch the device." while it waits, so authentication never looks like it has
stalled. This works for `sudo`, logging in, and unlocking the screen.

## If enrollment fails

`marchyo security enroll` only runs the enrollment tool; it doesn't change your
configuration. If it says the tool is not found, the matching flag isn't on yet:
set `marchyo.security.fingerprint.enable` or `marchyo.security.fido2.enable`,
rebuild, and try again. For a security key, "no key present, or touch timed out"
means the key wasn't plugged in or wasn't touched in time; plug it in and run the
command again.
