import QtQuick
import qs.Commons

// A thin vertical rule between bar clusters. Pure decoration: no text, no
// hover, no signals, so it stays a safe per-monitor view per the Bar/ contract.
Rectangle {
    implicitWidth: 1
    implicitHeight: Math.round(Style.barHeight * 0.5)
    color: Color.border
}
