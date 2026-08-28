import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Services

// Owns org.freedesktop.Notifications (replacing mako) and drives the toast stack.
// Capabilities are tuned for a TUI-aesthetic desktop: body + limited markup +
// action buttons + an app image, but no inline reply and no persistence (there is
// no history panel). On each incoming notification we retain it (tracked = true,
// so its object and actions stay alive for the toast) and hand it to the shared
// NotificationState singleton, which applies the DND policy and the visible cap.
// The renderer is the separate NotificationList; this component is pure service
// glue. Named NotificationDaemon (not NotificationServer) so it does not collide
// with the Quickshell NotificationServer type it instantiates.
Scope {
    id: root

    NotificationServer {
        id: server

        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        actionsSupported: true
        persistenceSupported: false
        inlineReplySupported: false

        onNotification: function (notification) {
            notification.tracked = true;
            NotificationState.show(notification);
        }
    }

    // The visible stack (its own top-right layer-shell surface).
    NotificationList {}
}
