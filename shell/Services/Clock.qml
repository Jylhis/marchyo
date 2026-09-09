pragma Singleton
import QtQuick
import Quickshell

// Seat-global clock: one SystemClock and one format toggle for the whole seat.
//
// Bar widgets are instantiated once per monitor (shell.qml's Variants loop), so
// when Bar/ClockWidget owned these itself every output got its own clock object
// and its own `showAlt`, and clicking the clock on one monitor left the others
// showing the old format. Same rule the contracts test enforces for
// Process/Timer/Connections in Bar/: shared state belongs in a singleton.
QtObject {
    id: root

    readonly property var clock: SystemClock {
        precision: SystemClock.Minutes
    }

    readonly property date date: root.clock.date

    // false = compact ("Sat 22 Aug · 14:30"), true = long form with ISO week
    // ("22 August W34 2025"). Mirrors waybar's clock format / format-alt pair.
    property bool showAlt: false

    function toggleFormat() {
        root.showAlt = !root.showAlt;
    }

    // ISO-8601 week number; Qt.formatDateTime has no week-of-year token, so derive
    // it (Thursday of the current week decides the year, per the ISO rule).
    function isoWeek(d) {
        const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
        const day = (t.getDay() + 6) % 7; // Monday = 0
        t.setDate(t.getDate() - day + 3); // move to this week's Thursday
        const firstThu = new Date(t.getFullYear(), 0, 4);
        const firstDay = (firstThu.getDay() + 6) % 7;
        firstThu.setDate(firstThu.getDate() - firstDay + 3);
        return 1 + Math.round((t - firstThu) / 604800000);
    }

    // The bar label, computed once for every output.
    // Qt.formatDateTime is a valid QML global; qmllint's Qt type model omits it.
    // qmllint disable missing-property
    readonly property string barText: root.showAlt ? (Qt.formatDateTime(root.date, "d MMMM") + " W" + root.isoWeek(root.date) + " " + Qt.formatDateTime(root.date, "yyyy")) : Qt.formatDateTime(root.date, "ddd d MMM · HH:mm")
    // qmllint enable missing-property
}
