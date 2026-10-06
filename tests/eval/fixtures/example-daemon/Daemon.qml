import QtQuick

// Minimal example daemon plugin (test fixture + docs reference). The shell
// creates one instance at its root for its whole lifetime; a daemon owns
// non-visual state, like a Services/ singleton.
QtObject {
    id: root

    property int ticks: 0

    property Timer timer: Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.ticks++
    }

    Component.onCompleted: console.info("example.ticker: started")
}
