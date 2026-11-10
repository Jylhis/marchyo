pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "I18n.js" as I18nJs
import "Paths.js" as Paths

// Display-language strings for the shell. Use I18n.t("audio.title"),
// I18n.t("power.charger", watts) for %1 holes, and I18n.tn(key, count, ...args)
// for plural entries. Strings come from i18n/<code>/shell.json layered over
// i18n/en/shell.json, so a missing translation falls back to English per key,
// then to the key itself.
//
// The language is the baked default (Config.language, from marchyo.language)
// unless `marchyo language <code>` wrote a runtime override
// ($XDG_STATE_HOME/marchyo/runtime.json, overrides.language). Every source is
// a watched FileView, so a switch re-renders the shell without a restart.
QtObject {
    id: root

    readonly property string baked: Config.language
    readonly property string override: root.overrideFrom(runtimeText)

    readonly property var registry: I18nJs.parseCatalog(registryText)
    readonly property string language: I18nJs.resolveLanguage(root.override, root.baked, root.registry)
    readonly property var localeSettings: root.registry[root.language] || ({})
    readonly property string decimal: root.localeSettings.decimal || "."
    readonly property string zeroDigit: root.localeSettings.zeroDigit || "0"
    readonly property bool rightToLeft: root.localeSettings.direction === "rtl"

    // text() is read inside bindings: with blockLoading the first read already
    // has the content, and a watched change re-evaluates the dependents. Only
    // `override` is a plain string, so the 5s poll below re-renders nothing
    // unless the language really changed.
    readonly property string runtimeText: runtimeFile.text()
    readonly property string registryText: registryFile.text()
    readonly property var englishStrings: I18nJs.parseCatalog(englishFile.text())
    readonly property var languageStrings: root.language === "en" ? ({}) : I18nJs.parseCatalog(languageFile.text())

    function t(key, ...args) {
        return I18nJs.t(root.languageStrings, root.englishStrings, key, args);
    }

    function tn(key, count, ...args) {
        return I18nJs.tn(root.languageStrings, root.englishStrings, root.language, key, count, args);
    }

    function formatNumber(value, decimals) {
        return I18nJs.formatNumber(value, decimals, root.decimal, root.zeroDigit);
    }

    function overrideFrom(text: string): string {
        const state = I18nJs.parseCatalog(text);
        const value = state.overrides ? state.overrides.language : "";
        return typeof value === "string" ? value : "";
    }

    function runtimePath(): string {
        return Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/runtime.json";
    }

    // Small local files, read synchronously so the first binding to call t()
    // already gets its string rather than the key.
    readonly property var runtimeView: FileView {
        id: runtimeFile
        path: root.runtimePath()
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: runtimeFile.reload()
    }

    readonly property var registryView: FileView {
        id: registryFile
        path: Quickshell.shellPath("i18n/locales.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: registryFile.reload()
    }

    readonly property var englishView: FileView {
        id: englishFile
        path: Quickshell.shellPath("i18n/en/shell.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: englishFile.reload()
    }

    readonly property var languageView: FileView {
        id: languageFile
        path: Quickshell.shellPath("i18n/" + root.language + "/shell.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: languageFile.reload()
    }

    // An atomic rename replaces the runtime.json inode, which ends the inotify
    // watch on the old file; the poll picks the new one up.
    readonly property var pollTimer: Timer {
        interval: 5000
        running: true
        repeat: true
        onTriggered: {
            runtimeFile.reload();
        }
    }
}
