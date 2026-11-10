import QtQuick

// A toast restored after a shell restart: the fields of a Quickshell
// Notification that the cards read, without a sender behind them. dismiss() and
// expire() close it the way a real notification would.
QtObject {
    property string appName: ""
    property string appIcon: ""
    property string desktopEntry: ""
    property string summary: ""
    property string body: ""
    property string image: ""
    property int urgency: 1
    property real expireTimeout: 0
    property var hints: ({})
    property var actions: []
    property bool resident: false
    property bool tracked: true

    signal closed(int reason)

    function dismiss(): void {
        closed(2);
    }

    function expire(): void {
        closed(1);
    }
}
