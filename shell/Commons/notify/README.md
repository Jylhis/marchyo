# notify

Pure notification libraries copied from omacom/omarchy (MIT, `../../compat/LICENSE.omarchy`),
branch quattro at rev `6194f4606c585da8b839b87df9120b7d796afedf`, `shell/plugins/notifications/`.
Each file keeps a provenance header. They are QML JavaScript libraries (`.pragma library`,
`.import`); `tests/shell/notify-lib-test.js` loads them the way QML does.

Local deltas, kept small so a re-sync is a diff:

- Hint names are `marchyo-exec-argv`, `marchyo-actions` and `marchyo-glyph`, and the Marchyo
  sender is `marchyo-action` (`Store.js`, `Delivery.js`, `Markup.js`, `Security.js`).
- `Store.snapshot(n, key, urgency, trusted)` ignores the exec, actions and glyph hints unless
  `trusted` is true. The caller sets it from the `marchyo-token` hint, a one-time nonce
  (`NotificationState.tokenOk`).
- `Store.STORED` omits `execArgv` and `execActions`: a stored or restored row never carries a
  click command.
- `Delivery.quietReason` is unused: do-not-disturb is decided by `Notify.dndPass`, which also
  passes critical urgency, per-sender rules and `marchyo.notifications.passApps`.

Not copied: `Layout.js`, `Icons.js`, `Service.qml`, `Toast.qml`, `DeedButton.qml` (marchyo keeps
its own toast UI).
