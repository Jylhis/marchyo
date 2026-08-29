import Quickshell
import qs.Ui

// Live clock. Left-click toggles between the compact form ("Sat 22 Aug · 14:30")
// and the long form with ISO week ("22 August W34 2025"), matching waybar's
// clock format / format-alt pair.
BarItem {
    id: root

    property bool showAlt: false

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
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

    interactive: true
    // Qt.formatDateTime is a valid QML global; qmllint's Qt type model omits it.
    // qmllint disable missing-property
    text: root.showAlt ? (Qt.formatDateTime(clock.date, "d MMMM") + " W" + root.isoWeek(clock.date) + " " + Qt.formatDateTime(clock.date, "yyyy")) : Qt.formatDateTime(clock.date, "ddd d MMM · HH:mm")
    // qmllint enable missing-property
    onClicked: root.showAlt = !root.showAlt
}
