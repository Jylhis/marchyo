pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as M
import "Plural.js" as Plural
import "Numbers.js" as Numbers

// omarchy-compat `I18n` singleton. The language follows marchyo's own
// Commons/I18n (baked default, `marchyo language` override). Strings come from
// omarchy's catalogs under $OMARCHY_PATH/default/i18n (<code>/shell.json over
// en/shell.json; locales.json for decimal and zero digit). A key the omarchy
// catalogs lack falls back to marchyo's own I18n.t, then to the caller's
// fallback, then to the key.
QtObject {
    id: root

    readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH")
    readonly property string language: M.I18n.language

    readonly property var localeSettings: parseCatalog(registryFile.text())[root.language] || ({})
    readonly property string formatLocale: localeSettings.formatLocale || "en-US"
    readonly property string decimal: localeSettings.decimal || M.I18n.decimal
    readonly property string zeroDigit: localeSettings.zeroDigit || M.I18n.zeroDigit
    readonly property bool rightToLeft: localeSettings.direction === "rtl" || M.I18n.rightToLeft

    readonly property var englishStrings: parseCatalog(englishCatalogFile.text())
    readonly property var languageStrings: parseCatalog(languageCatalogFile.text())
    readonly property var strings: {
        const merged = ({});
        for (const k in root.englishStrings)
            merged[k] = root.englishStrings[k];
        for (const k2 in root.languageStrings)
            merged[k2] = root.languageStrings[k2];
        return merged;
    }

    function t(key, fallback) {
        let value = root.strings[key];
        if (value && typeof value === "object")
            value = value.other;
        if (typeof value === "string" && value.length > 0)
            return value;
        const own = M.I18n.t(key);
        if (own !== key)
            return own;
        return fallback !== undefined ? fallback : key;
    }

    function tn(key, count, fallback) {
        let value = Plural.pick(root.languageStrings[key], root.language, count);
        if (typeof value !== "string" || value.length === 0)
            value = Plural.pick(root.englishStrings[key], "en", count);
        if (typeof value === "string" && value.length > 0)
            return value;
        const own = M.I18n.tn(key, count);
        if (own !== key)
            return own;
        return fallback !== undefined ? fallback : key;
    }

    function formatNumber(value, decimals) {
        return Numbers.format(value, decimals, root.decimal, root.zeroDigit);
    }

    function parseCatalog(raw) {
        try {
            const parsed = JSON.parse(raw || "{}");
            return (parsed && typeof parsed === "object" && !Array.isArray(parsed)) ? parsed : ({});
        } catch (e) {
            return ({});
        }
    }

    function catalogPath(rel) {
        return root.omarchyPath !== "" ? root.omarchyPath + "/default/i18n/" + rel : "";
    }

    readonly property var englishCatalogView: FileView {
        id: englishCatalogFile
        path: root.catalogPath("en/shell.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
    }

    readonly property var languageCatalogView: FileView {
        id: languageCatalogFile
        path: root.language !== "en" ? root.catalogPath(root.language + "/shell.json") : ""
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
    }

    readonly property var registryView: FileView {
        id: registryFile
        path: root.catalogPath("locales.json")
        watchChanges: true
        printErrors: false
        blockLoading: true
        onFileChanged: reload()
    }
}
