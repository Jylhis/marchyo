import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.Services

// Owns the org.freedesktop.Notifications service and hands each
// incoming notification to the shared NotificationState. tracked = true keeps the
// object and its actions alive for the toast. Named NotificationDaemon, not
// NotificationServer, so it does not collide with the Quickshell type it
// instantiates.
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

    NotificationList {}
}
