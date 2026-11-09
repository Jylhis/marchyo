import QtQuick
import QtQuick.Layouts
import qs.Ui
import qs.Commons
import qs.Services
import "../Commons/AgentUsage.js" as AgentUsage

// Usage limits of the AI coding agents in use: one meter per limit with the
// time to its reset, from Services/Agents. A provider with several accounts
// lists them with their limits and a button to switch new sessions. Opening
// the panel asks the CLI for a fresh record.
Panel {
    id: root
    panelId: "agents"
    title: I18n.t("agents.title")
    cardWidth: Style.panelWidth * 1.3

    body: [
        Text {
            Layout.fillWidth: true
            visible: Agents.agents.length === 0
            text: Agents.refreshing ? I18n.t("agents.loading") : I18n.t("agents.empty")
            color: Colors.textMuted
            font.family: Style.fontFamily
            font.pixelSize: Style.fontSizeSmall
            wrapMode: Text.WordWrap
        },
        Repeater {
            model: Agents.agents

            ColumnLayout {
                id: agentBlock
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.spacing

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: agentBlock.modelData.name
                        color: Colors.textMuted
                        font.family: Style.fontFamily
                        font.pixelSize: Style.fontSizeSmall
                        font.bold: true
                    }
                    AgentInfo {
                        details: {
                            const agent = agentBlock.modelData;
                            let failure = agent.error;
                            if (agentBlock.signIn)
                                failure = I18n.t("agents.signInRequired", agent.name);
                            const age = AgentUsage.ageMinutes(agent.fetchedAt, Agents.now);
                            const stale = agentBlock.stale ? I18n.t("agents.stale", age) : "";
                            return [failure, stale].filter(s => s !== "").join("\n");
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                }

                Repeater {
                    model: agentBlock.modelData.limits

                    AgentMeter {
                        id: limitRow
                        required property var modelData
                        limit: limitRow.modelData
                        fetchedAt: agentBlock.modelData.fetchedAt
                    }
                }

                Text {
                    Layout.fillWidth: true
                    visible: agentBlock.modelData.limits.length === 0 && agentBlock.modelData.error === ""
                    text: I18n.t("agents.noLimits")
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }

                readonly property bool signIn: AgentUsage.needsSignIn(agentBlock.modelData.error)
                readonly property bool stale: AgentUsage.isStale(agentBlock.modelData.fetchedAt, Agents.now)
            }
        },
        Repeater {
            model: Agents.accountGroups

            ColumnLayout {
                id: groupBlock
                required property var modelData
                Layout.fillWidth: true
                spacing: Style.spacing

                PanelSectionHeader {
                    text: I18n.t("agents.accounts", groupBlock.modelData.name)
                }

                Text {
                    Layout.fillWidth: true
                    text: groupBlock.modelData.mode === "auto" ? I18n.t("agents.modeAuto", groupBlock.modelData.threshold) : I18n.t("agents.modeManual", groupBlock.modelData.threshold)
                    color: Colors.textMuted
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSizeSmall
                }

                PanelButton {
                    visible: groupBlock.modelData.offer !== null && groupBlock.modelData.mode === "manual"
                    active: true
                    text: groupBlock.modelData.offer === null ? "" : I18n.t("agents.offerButton", groupBlock.modelData.offer.toLabel)
                    onClicked: Agents.useAccount(groupBlock.modelData.provider, groupBlock.modelData.offer.toId)
                }

                Repeater {
                    model: groupBlock.modelData.accounts

                    ColumnLayout {
                        id: accountRow
                        required property var modelData
                        readonly property real peak: AgentUsage.accountPeak(accountRow.modelData)
                        Layout.fillWidth: true
                        spacing: 2

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: accountRow.modelData.label + (accountRow.modelData.plan !== "" ? "  " + accountRow.modelData.plan : "") + (accountRow.modelData.signedIn ? "" : "  " + I18n.t("agents.accountSignedOut"))
                                color: accountRow.modelData.active ? Colors.accent : Colors.text
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizeSmall
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: accountRow.peak >= 0
                                text: Math.round(accountRow.peak * 100) + "%"
                                color: Agents.levelColor(accountRow.peak)
                                font.family: Style.fontFamily
                                font.pixelSize: Style.fontSizeSmall
                            }
                            PanelButton {
                                active: accountRow.modelData.active
                                text: accountRow.modelData.active ? I18n.t("agents.accountActive") : I18n.t("agents.accountUse")
                                onClicked: {
                                    if (!accountRow.modelData.active)
                                        Agents.useAccount(groupBlock.modelData.provider, accountRow.modelData.id);
                                }
                            }
                        }

                        Repeater {
                            model: accountRow.modelData.limits

                            AgentMeter {
                                id: accountLimit
                                required property var modelData
                                limit: accountLimit.modelData
                                fetchedAt: accountRow.modelData.fetchedAt
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: accountRow.modelData.error !== ""
                            text: accountRow.modelData.error
                            color: Colors.statusWarn
                            font.family: Style.fontFamily
                            font.pixelSize: Style.fontSizeSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        },
        PanelButton {
            Layout.alignment: Qt.AlignRight
            text: Agents.refreshing ? I18n.t("agents.refreshing") : I18n.t("agents.refresh")
            onClicked: Agents.refresh(true)
        }
    ]
}
