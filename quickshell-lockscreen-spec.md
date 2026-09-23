# Quickshell Lock Screen — Implementation Spec (Hyprland)

Target: Quickshell v0.3.x (confirmed against v0.3.1 docs, Sept 2026). All APIs below are native
to Quickshell — no hyprlock, no hypridle, no external PAM helper binary required.

## Goal

Implement a lock screen entirely inside a Quickshell config, using:

1. `Quickshell.Wayland.WlSessionLock` — the actual compositor-level lock surface (`ext-session-lock-v1`)
2. `Quickshell.Services.Pam.PamContext` — native PAM authentication, in-process
3. `Quickshell.Wayland.IdleMonitor` — native idle detection (`ext-idle-notify-v1`), to trigger the lock automatically

## 1. Session lock surface

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland

WlSessionLock {
    id: lock

    // false by default; set true to engage the lock
    locked: false

    // Fires once the compositor confirms every screen is actually covered.
    // Gate showing sensitive content (e.g. autofocus on password field) on this,
    // not on `locked` alone.
    onSecureChanged: {
        if (secure) {
            // safe to focus password input, start animations, etc.
        }
    }

    WlSessionLockSurface {
        // Instantiated once per screen automatically. `screen` (readonly) gives you
        // the ShellScreen this instance belongs to, if you need per-monitor content.
        color: "#000000" // background; avoid transparency, see warning below

        Rectangle {
            anchors.fill: parent
            color: "#1a1a1a"

            // ... clock, wallpaper, password field, etc.
        }
    }
}
```

Properties:
- `surface` (default property, Component): must create a `WlSessionLockSurface`. Instantiated per screen.
- `locked` (bool): drives lock state. **Only one `WlSessionLock` may be locked system-wide at a time** — setting `locked = true` while another lock is active is a no-op.
- `secure` (readonly bool): true once compositor confirms all screens are covered.

`WlSessionLockSurface` properties: `color`, `screen` (readonly `ShellScreen`), `contentItem` (readonly), `visible` (readonly).

**Critical safety warning (from upstream docs):** if the `WlSessionLock` object is destroyed, or quickshell exits, while still locked (`locked` was never set back to `false`), conformant compositors leave the screen locked and painted with a solid color — with no way back in via quickshell. This is intentional (it's what makes the lock secure), but it means:
- The unlock path must be the *only* thing that sets `locked = false`.
- Never let the `WlSessionLock` item get destroyed (e.g. via a `Loader` that unloads it) while `locked` is true.
- Test crash/restart behavior in a VM before relying on this, not on your daily driver.

## 2. Native PAM authentication

```qml
import Quickshell.Services.Pam

PamContext {
    id: pam

    // config names a file inside configDirectory (default "/etc/pam.d"); default value is "login"
    config: "login"
    // user: leave unset to authenticate as the current user

    onPamMessage: {
        // `message`, `messageIsError`, `responseRequired`, `responseVisible` have just been updated
        if (responseRequired) {
            // Show the prompt from `message`. Mask the input field if !responseVisible.
            passwordField.echoMode = responseVisible ? TextInput.Normal : TextInput.Password
            passwordField.forceActiveFocus()
        } else if (messageIsError) {
            errorLabel.text = message
        }
    }

    onCompleted: (result) => {
        if (result === PamResult.Success) {
            lock.locked = false
        } else {
            passwordField.text = ""
            errorLabel.text = "Authentication failed"
            // optionally: pam.start() again to retry
        }
    }

    onError: (err) => {
        // A completed(PamResult.Error) will also fire after this.
        console.log("PAM error:", err)
    }
}

// Wire submit:
// TextInput { onAccepted: { pam.respond(text); } }
// Start a session when the lock surface becomes ready:
// onSecureChanged: if (secure) pam.start()
```

API surface:
- Properties: `user` (string), `active` (bool — same effect as calling `start()`/`abort()`), `message` (readonly string), `config` (string, default `"login"`), `configDirectory` (string, default `"/etc/pam.d"`, ignored on FreeBSD), `messageIsError` (readonly bool), `responseVisible` (readonly bool, only meaningful when `responseRequired`), `responseRequired` (readonly bool).
- Functions: `start()` → bool (whether session started), `abort()`, `respond(response: string)` — only callable when `responseRequired` is true.
- Signals: `completed(result: PamResult)`, `error(error: PamError)`, `pamMessage()` — fires after the message/messageIsError/responseRequired change signals.
- `user` and `config`/`configDirectory` cannot be changed while `active` is true.

Do not attempt to call an `unlock()` method on `WlSessionLock` directly — it does not exist in QML (it's private C++ API). The correct pattern is exactly the above: drive `lock.locked = false` yourself once `PamContext.completed` reports `PamResult.Success`.

## 3. Idle-triggered locking

```qml
import Quickshell.Wayland

IdleMonitor {
    id: idleMonitor
    timeout: 300           // seconds of no input before considered idle
    respectInhibitors: true // an active IdleInhibitor elsewhere (e.g. video playback) suppresses this
    enabled: true

    onIsIdleChanged: {
        if (isIdle) lock.locked = true
    }
}
```

Requires the compositor to support `ext-idle-notify-v1` (Hyprland does). If you want different timeouts for
"dim" vs "lock" vs "suspend", instantiate multiple `IdleMonitor`s with different `timeout` values.

## 4. Multi-monitor behavior

`WlSessionLock` already instantiates one `surface` component per screen automatically — you do not need a
manual `Variants`/`Repeater` over `Quickshell.screens` unless you want to pass different external data to
each instance beyond what `WlSessionLockSurface.screen` already exposes.

## 5. Manual trigger (keybind)

Expose an `IpcHandler` so Hyprland (or any external tool) can trigger the lock via `qs ipc call`:

```qml
import Quickshell.Io

IpcHandler {
    target: "lock"
    function lock(): void { lockRoot.locked = true }
}
```

Then bind in `hyprland.conf`:

```
bind = SUPER, L, exec, qs ipc call lock lock
```

## 6. Assembly notes for the agent

- Put `WlSessionLock` at the top level of a `ShellRoot` (or equivalent), not inside a `Loader` that could
  tear it down while locked.
- Sequence: `IdleMonitor.isIdle` or the IPC handler sets `lock.locked = true` → wait for `lock.secure` to
  become true before focusing the password field → user types → `PamContext.start()` on first keystroke or
  on surface ready → `pam.respond()` on submit → on `PamResult.Success`, `lock.locked = false`.
- Handle `PamResult.Error` / `error()` signal by showing a generic "authentication error" state and allowing
  retry via `pam.start()` again — don't leave the UI stuck.
- No external processes (hyprlock, swaylock, hypridle) are required for a minimal working version. If the
  existing setup already has hyprlock/hypridle installed, they are not needed for this integration path and
  can be removed once this is working, but that's an optional cleanup, not a dependency.

## References

- https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLock/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlSessionLockSurface/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Services.Pam/PamContext/
- https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/IdleMonitor/
