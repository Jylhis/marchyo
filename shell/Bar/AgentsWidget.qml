import QtQuick
import qs.Ui
import qs.Commons
import qs.Services

// AI agent usage: the tightest limit across the agents in use, a pure view over
// Services/Agents. Registered but not placed by default; placing marchyo.agents
// is what starts the slow refresh. Self-hides until a limit is known.
BarItem {
    id: root

    readonly property var limit: Agents.tightest

    interactive: true
    shown: root.limit !== null
    text: root.limit ? "󰚩 " + Math.round(root.limit.percent * 100) + "%" : ""
    textColor: root.limit ? Agents.levelColor(root.limit.percent) : Colors.text
    tooltipText: root.limit ? I18n.t("agents.tooltip", root.limit.agent, root.limit.label, Math.round(root.limit.percent * 100), Agents.resetText(root.limit.resetsAt)) : I18n.t("agents.title")

    onClicked: PanelManager.toggle("agents", root)
    Component.onCompleted: Agents.attach()
    Component.onDestruction: Agents.detach()
}
