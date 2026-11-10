pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/Appearance.js" as Appearance
import "../Commons/LauncherProviders.js" as Providers

// Data behind the "themes" and "backgrounds" panels (Panels/ImagePicker):
// `marchyo theme list` and `marchyo bg list` run each time the panel opens,
// and applying a row runs `marchyo theme set` or `marchyo bg set`. Rows share
// one shape: { id, title, subtitle, image, current }, where image is the
// absolute preview path ("" when the theme has no preview.png).
QtObject {
    id: root

    property var themes: []
    property var backgrounds: []
    property bool themesLoading: false
    property bool backgroundsLoading: false

    readonly property var themeRows: root.themes.map(t => ({
                id: t.name,
                title: t.name,
                subtitle: t.variant,
                image: t.preview,
                current: t.current
            }))

    readonly property var backgroundRows: root.backgrounds.map(b => ({
                id: b.path,
                title: b.name,
                subtitle: I18n.t("picker.source." + b.source),
                image: b.path,
                current: b.current
            }))

    function rows(kind: string): var {
        return kind === "themes" ? root.themeRows : root.backgroundRows;
    }

    function loading(kind: string): bool {
        return kind === "themes" ? root.themesLoading : root.backgroundsLoading;
    }

    function refresh(kind: string): void {
        if (kind === "themes") {
            root.themesLoading = true;
            root.themeProc.running = false;
            root.themeProc.running = true;
        } else if (kind === "backgrounds") {
            root.backgroundsLoading = true;
            root.bgProc.running = false;
            root.bgProc.running = true;
        }
    }

    function apply(kind: string, id: string): void {
        if (kind === "themes") {
            Quickshell.execDetached([Config.marchyo, "theme", "set", id]);
            root.themes = root.themes.map(t => Object.assign({}, t, {
                    current: t.name === id
                }));
        } else {
            Quickshell.execDetached([Config.marchyo, "bg", "set", id]);
            root.backgrounds = root.backgrounds.map(b => Object.assign({}, b, {
                    current: b.path === id
                }));
        }
    }

    readonly property var events: Connections {
        target: PanelManager
        function onOpenIdChanged() {
            if (PanelManager.openId === "themes" || PanelManager.openId === "backgrounds")
                root.refresh(PanelManager.openId);
        }
    }

    // A manifest or wallpaper list is a few KiB; refuse anything absurd.
    readonly property var themeProc: Process {
        command: [Config.marchyo, "theme", "list", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.themes = text.length <= Appearance.MAX_CHARS ? Providers.parseThemes(text) : [];
                root.themesLoading = false;
            }
        }
    }

    readonly property var bgProc: Process {
        command: [Config.marchyo, "bg", "list", "--format", "json"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backgrounds = text.length <= Appearance.MAX_CHARS ? Appearance.parseBackgrounds(text) : [];
                root.backgroundsLoading = false;
                Thumbnails.request(root.backgrounds.map(b => b.path));
            }
        }
    }
}
