import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Services
import qs.Launcher

// The launcher surface: a full-screen transparent layer-shell overlay (the
// Ui/Panel dismiss idiom) whose centered card hosts the query field and one
// result list. Services/Launcher routes the query to a provider (by mode and
// prefix); the list renders that provider's results. While open it takes
// EXCLUSIVE keyboard focus and releases it when closed. Opens on the focused
// output, like PanelManager's fallback.
PanelWindow {
    id: root

    // Every provider, keyed by the id Services/Launcher routes to: the
    // first-party ones plus the launcher plugins (keyed by plugin id).
    readonly property var providers: Object.assign({}, root.pluginProviders, {
        "apps": appsProvider,
        "emoji": emojiProvider,
        "clipboard": clipboardProvider,
        "calc": calcProvider,
        "theme": themeProvider,
        "windows": windowsProvider,
        "power": powerProvider
    })
    readonly property var active: root.providers[Launcher.provider] || appsProvider

    readonly property var appsProvider: AppsProvider {}
    readonly property var emojiProvider: EmojiProvider {}
    readonly property var clipboardProvider: ClipboardProvider {}
    readonly property var calcProvider: CalcProvider {}
    readonly property var themeProvider: ThemeProvider {}
    readonly property var windowsProvider: WindowsProvider {}
    readonly property var powerProvider: PowerProvider {}

    // Launcher plugins (Commons/PluginIndex): each component's root is a
    // Provider. Its providerId and prefix come from the manifest, so routing
    // in Services/Launcher and this map agree. A plugin that fails to load is
    // logged and skipped.
    property var pluginProviders: ({})
    Component.onCompleted: {
        const out = {};
        const entries = PluginIndex.launcherComponents();
        for (let i = 0; i < entries.length; i++) {
            const e = entries[i];
            if (e.component.status !== Component.Ready) {
                console.warn(`launcher plugin ${e.id}: ${e.component.errorString()}`);
                continue;
            }
            const obj = e.component.createObject(root, {
                "providerId": e.id,
                "prefix": e.prefix
            });
            if (obj === null || typeof obj.results === "undefined") {
                console.warn(`launcher plugin ${e.id}: root is not a Launcher Provider`);
                if (obj !== null)
                    obj.destroy();
                continue;
            }
            out[e.id] = obj;
        }
        root.pluginProviders = out;
    }

    visible: Launcher.open
    screen: Screens.byName(Screens.focusedName)
    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "marchyo:launcher"
    WlrLayershell.keyboardFocus: Launcher.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // No window-level focus signal to auto-close on: PanelWindow exposes no
    // `active`, and the Exclusive keyboard grab means the compositor can't
    // silently route focus elsewhere while open. Dismissal is Escape, the
    // outside-click MouseArea below, and item activation.

    // Take focus once the surface has mapped; the focusRetry call is the one
    // that sticks on some compositors.
    onVisibleChanged: if (visible) {
        query.text = "";
        query.forceActiveFocus();
        focusRetry.restart();
    }

    // Declared first so the card sits on top of it (Ui/Panel.qml ordering trick).
    MouseArea {
        anchors.fill: parent
        onClicked: Launcher.close()
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(Style.launcherWidth, parent.width - 2 * Style.panelGap)
        implicitHeight: Math.min(column.implicitHeight, parent.height - 2 * Style.panelGap)
        radius: 0
        color: Qt.alpha(Color.bg, Style.surfaceAlpha)
        border.color: Color.border
        border.width: 1

        // Swallow clicks inside the card so they don't reach the dismiss
        // area below (Ui/Panel.qml idiom).
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: column
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Style.spacing

            // The one query field, shared by every mode.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.panelPad
                implicitHeight: query.implicitHeight + Style.panelPad
                color: Color.bgSubtle
                border.width: 1
                border.color: query.activeFocus ? Color.accent : Color.border

                TextInput {
                    id: query
                    anchors.fill: parent
                    anchors.margins: Style.panelPad / 2
                    color: Color.text
                    selectionColor: Color.selectionBg
                    selectedTextColor: Color.text
                    font.family: Style.fontFamily
                    font.pixelSize: Style.fontSize
                    clip: true
                    Keys.onEscapePressed: Launcher.close()

                    // Inline autocomplete: remaining letters of the active
                    // provider's suggestion, dimmed after the cursor. Only a
                    // `completes` provider (apps) offers one.
                    property string ghost: (root.active.completes && query.activeFocus && root.active.suggestion.length > query.text.length) ? root.active.suggestion.substring(query.text.length) : ""

                    function acceptGhost() {
                        if (query.ghost.length === 0)
                            return false;
                        query.text = root.active.suggestion;
                        query.cursorPosition = query.text.length;
                        return true;
                    }

                    onTextChanged: Launcher.query = text

                    Text {
                        id: ghostText
                        x: query.contentWidth
                        anchors.verticalCenter: parent.verticalCenter
                        text: query.ghost
                        visible: text.length > 0
                        color: Color.textMuted
                        font: query.font
                    }

                    // Arrows/Enter go to the results view. Lists move by
                    // row; the emoji grid moves by three cells on Up/Down and
                    // by one on Left/Right.
                    Keys.onPressed: event => {
                        const grid = root.active.layout === "grid";
                        if (event.key === Qt.Key_Down) {
                            results.move(grid ? 3 : 1);
                            event.accepted = true;
                        } else if (event.key === Qt.Key_Up) {
                            results.move(grid ? -3 : -1);
                            event.accepted = true;
                        } else if (grid && event.key === Qt.Key_Left) {
                            results.move(-1);
                            event.accepted = true;
                        } else if (grid && event.key === Qt.Key_Right) {
                            results.move(1);
                            event.accepted = true;
                        } else if (root.active.completes && event.key === Qt.Key_Tab) {
                            query.acceptGhost();
                            event.accepted = true;
                        } else if (root.active.completes && event.key === Qt.Key_Right && query.cursorPosition === query.text.length) {
                            // Only swallow Right when it accepts a ghost;
                            // otherwise let the cursor move normally.
                            event.accepted = query.acceptGhost();
                        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            results.activate();
                            event.accepted = true;
                        }
                    }
                }
            }

            ResultsView {
                id: results
                anchors.left: parent.left
                anchors.right: parent.right
                provider: root.active
            }
        }
    }

    // Map-then-focus retry: on some compositors forceActiveFocus() in the
    // visible-change handler lands before the surface accepts keyboard focus.
    Timer {
        id: focusRetry
        interval: 50
        onTriggered: if (root.visible)
            query.forceActiveFocus()
    }
}
