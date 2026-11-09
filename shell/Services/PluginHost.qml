pragma Singleton
import QtQuick
import Quickshell
import qs.Commons
import qs.compat.Services as Api
import "../Commons/PluginManifest.js" as PM

// State and operations of the omarchy plugin host. Plugins::PluginLayer mounts
// panel/menu/overlay/service plugins and registers them here; shell.qml
// registers the live bar widgets. Everything a plugin may call arrives through
// its PluginShellApi facade (shellFor), closed over the plugin's id: a plugin
// controls itself, and a `bar` plugin also controls the UI plugins it hosts.
// The facades are API boundaries, not a sandbox: plugin QML shares the
// shell's scene and process.
QtObject {
    id: root

    readonly property var entries: PluginIndex.all

    // Hosted plugin ids that are open, and payloads queued until the plugin's
    // Loader has produced its item.
    property var openIds: ({})
    property var pending: ({})

    // id -> Loader of a panel/menu/overlay plugin; id -> service instance;
    // id -> live bar widget items.
    property var loaders: ({})
    property var services: ({})
    property var barWidgets: ({})

    // Mirrors shell.qml's bar visibility for PluginBarStateApi.
    property bool barHidden: false

    // True while a `bar` plugin has replaced the built-in bar.
    property bool customBar: false

    function manifest(id: string): var {
        return PluginIndex.pluginById(String(id || ""));
    }

    function publicManifest(id: string): var {
        return PM.publicManifest(root.manifest(id));
    }

    function _with(map, key, value) {
        const next = {};
        for (const k in map)
            next[k] = map[k];
        next[key] = value;
        return next;
    }

    function _without(map, key) {
        const next = {};
        for (const k in map)
            if (k !== key)
                next[k] = map[k];
        return next;
    }

    // ---- summon / hide / toggle ------------------------------------------

    function liveWidget(id: string): var {
        const list = root.barWidgets[id] || [];
        return list.length > 0 ? list[0] : null;
    }

    // The live bar widget of `id` on output `screenName`, else on the focused
    // output, else any.
    function widgetOn(id: string, screenName: string): var {
        const want = screenName !== "" ? screenName : Screens.focusedName;
        return PM.pickWidget(root.barWidgets[id], want, w => Screens.nameOf(w));
    }

    function summon(id: string, payloadJson: string): bool {
        return root.summonOn(id, payloadJson, "");
    }

    // Like summon, but a bar widget opens on output `screenName` ("" is the
    // focused output).
    function summonOn(id: string, payloadJson: string, screenName: string): bool {
        const e = root.manifest(id);
        if (e === null)
            return false;
        if (PM.isBarWidgetOnly(e)) {
            const w = root.widgetOn(id, screenName);
            if (w === null || typeof w.open !== "function")
                return false;
            w.open();
            return true;
        }
        if (!PM.isHosted(e))
            return false;
        root.openIds = root._with(root.openIds, id, true);
        const queue = (root.pending[id] || []).slice();
        queue.push(payloadJson || "");
        root.pending = root._with(root.pending, id, queue);
        root.deliverIfLoaded(id);
        return true;
    }

    function hide(id: string): bool {
        const e = root.manifest(id);
        if (e === null)
            return false;
        if (PM.isBarWidgetOnly(e)) {
            if (root.liveWidget(id) === null)
                return false;
            const open = root._openWidgets(id);
            for (let i = 0; i < open.length; i++)
                if (typeof open[i].close === "function")
                    open[i].close();
            return true;
        }
        root.invokeIfLoaded(id, "close");
        if (root.openIds[id])
            root.openIds = root._without(root.openIds, id);
        root.pending = root._without(root.pending, id);
        return true;
    }

    function isOpen(id: string): bool {
        const e = root.manifest(id);
        if (e === null)
            return false;
        if (PM.isBarWidgetOnly(e))
            return root._openWidgets(id).length > 0;
        const loader = root.loaders[id];
        if (loader && loader.item && loader.item.opened !== undefined)
            return loader.item.opened === true;
        return root.openIds[id] === true;
    }

    function _openWidgets(id: string): var {
        return (root.barWidgets[id] || []).filter(w => w && w.opened === true);
    }

    function toggle(id: string, payloadJson: string): bool {
        return root.isOpen(id) ? root.hide(id) : root.summon(id, payloadJson);
    }

    // ---- loader / service / widget registration --------------------------

    function registerLoader(id: string, loader): void {
        root.loaders = root._with(root.loaders, id, loader);
        root.deliverIfLoaded(id);
    }

    function unregisterLoader(id: string): void {
        if (root.loaders[id])
            root.loaders = root._without(root.loaders, id);
    }

    function registerService(id: string, instance): void {
        root.services = root._with(root.services, id, instance);
    }

    function serviceFor(id: string): var {
        return root.services[id] || null;
    }

    function registerBarWidget(id: string, item): void {
        const list = (root.barWidgets[id] || []).slice();
        if (list.indexOf(item) === -1)
            list.push(item);
        root.barWidgets = root._with(root.barWidgets, id, list);
    }

    function unregisterBarWidget(id: string, item): void {
        const list = (root.barWidgets[id] || []).filter(w => w !== item);
        root.barWidgets = list.length > 0 ? root._with(root.barWidgets, id, list) : root._without(root.barWidgets, id);
    }

    function deliverIfLoaded(id: string): void {
        const loader = root.loaders[id];
        if (!loader || !loader.item)
            return;
        const queue = root.pending[id];
        if (!Array.isArray(queue) || queue.length === 0)
            return;
        root.pending = root._without(root.pending, id);
        if (typeof loader.item.open !== "function")
            return;
        for (let i = 0; i < queue.length; i++) {
            try {
                loader.item.open(queue[i]);
            } catch (e) {
                console.warn(`plugin ${id} open() threw: ${e}`);
            }
        }
    }

    function invokeIfLoaded(id: string, method: string): void {
        const loader = root.loaders[id];
        if (!loader || !loader.item || typeof loader.item[method] !== "function")
            return;
        try {
            loader.item[method]();
        } catch (e) {
            console.warn(`plugin ${id} ${method}() threw: ${e}`);
        }
    }

    // `call <id> <method> <arg>`: a method of an already-loaded plugin (its
    // panel item, else its service, else its live bar widget).
    function call(id: string, method: string, arg: string): string {
        const loader = root.loaders[id];
        const target = (loader && loader.item) || root.serviceFor(id) || root.liveWidget(id);
        if (!target || typeof target[method] !== "function")
            return "unknown";
        try {
            const result = target[method](arg);
            return result === undefined || result === null ? "ok" : String(result);
        } catch (e) {
            console.warn(`plugin ${id} ${method}() threw: ${e}`);
            return "error";
        }
    }

    // The id of the nth (1-based) plugin panel in a bar section's layout, so a
    // hotkey keeps meaning "the third panel on the right" after a rearrange.
    function panelWidgetIdAt(section: string, index: string): string {
        // The bar has left, center and right; omarchy's centerBegin and
        // centerEnd read as the center box.
        const name = section.indexOf("center") === 0 ? "center" : section;
        const list = ShellConfig.bar[name] || [];
        const n = Math.round(Number(index));
        let count = 0;
        for (let i = 0; i < list.length; i++) {
            const id = String(list[i].id || "");
            const e = root.manifest(id);
            if (e !== null && (PM.isBarWidgetOnly(e) || PM.isHosted(e)) && ++count === n)
                return id;
        }
        return "";
    }

    function togglePanelAt(section: string, index: string): string {
        const id = root.panelWidgetIdAt(section, index);
        if (id === "")
            return "unknown";
        root.toggle(id, "{}");
        return id;
    }

    // ---- per-plugin facades ----------------------------------------------

    property var _shellApis: ({})

    function _may(callerId: string, targetId: string): bool {
        return PM.mayControl(root.manifest(callerId), root.manifest(targetId));
    }

    function shellFor(id: string): var {
        if (root._shellApis[id])
            return root._shellApis[id];
        const e = root.manifest(id);
        if (e === null)
            return null;
        const api = shellApiC.createObject(root, {
            "pluginId": id,
            "appLibrary": PM.hasKind(e, "menu") ? root.appLibraryFor(id) : null,
            "bar": root.barStateFor(id),
            "_serviceLookup": target => String(target) === id ? root.serviceFor(id) : null,
            "_firstPartyServiceLookup": target => PM.mayUseFirstPartyService(e, root.manifest(target)) ? root.serviceFor(target) : null,
            "_summon": (target, payload) => root._may(id, target) && root.summon(target, payload),
            "_hide": target => root._may(id, target) && root.hide(target),
            "_toggle": (target, payload) => root._may(id, target) && root.toggle(target, payload),
            "_isOpen": target => root._may(id, target) && root.isOpen(target),
            "_updateSettings": (target, settings) => root.updateEntryInline(id, target, settings)
        });
        root._shellApis = root._with(root._shellApis, id, api);
        return api;
    }

    function registryFor(id: string): var {
        return registryApiC.createObject(root, {
            "pluginId": id,
            "manifest": root.publicManifest(id),
            "enabled": true,
            "_entryPointUrl": key => {
                const e = root.manifest(id);
                return e && e.entryPoints && e.entryPoints[key] ? e.entryPoints[key] : "";
            }
        });
    }

    function barWidgetRegistryFor(id: string): var {
        return barWidgetRegistryApiC.createObject(root, {});
    }

    function barStateFor(id: string): var {
        return barStateApiC.createObject(root, {
            "ownerPluginId": id
        });
    }

    function appLibraryFor(id: string): var {
        return appLibraryApiC.createObject(root, {
            "ownerPluginId": id,
            "_entryName": entry => entry && entry.name ? entry.name : "",
            "_entrySubtext": entry => entry && (entry.comment || entry.genericName) ? (entry.comment || entry.genericName) : "",
            "_sortedEntries": query => root.sortedApps(query),
            "_iconSource": icon => root.appIconSource(icon),
            "_refreshIcons": () => {},
            "_launch": (desktopId, name) => root.launchApp(desktopId),
            "_remove": () => console.warn("plugin app library: removing desktop entries is not supported")
        });
    }

    function sortedApps(query: string): var {
        const q = String(query || "");
        const all = DesktopEntries.applications.values.filter(a => !a.noDisplay);
        const scored = [];
        for (let i = 0; i < all.length; i++) {
            const s = q === "" ? 0 : Fuzzy.score(all[i].name, q);
            if (s >= 0)
                scored.push({
                    "entry": all[i],
                    "score": s
                });
        }
        scored.sort((a, b) => q === "" ? a.entry.name.localeCompare(b.entry.name) : b.score - a.score);
        return scored.map(x => ({
                    "entry": x.entry,
                    "score": x.score,
                    "key": x.entry.id,
                    "name": x.entry.name.toLowerCase()
                }));
    }

    function appIconSource(icon: string): string {
        const value = String(icon || "");
        if (value.startsWith("file://") || value.startsWith("image://"))
            return value;
        if (value.startsWith("/"))
            return "file://" + value;
        const themed = value ? Quickshell.iconPath(value, true) : "";
        return themed || Quickshell.iconPath("application-x-executable", true);
    }

    function launchApp(desktopId: string): void {
        const entries = DesktopEntries.applications.values;
        for (let i = 0; i < entries.length; i++) {
            if (entries[i].id === desktopId) {
                entries[i].execute();
                return;
            }
        }
    }

    // Persist a plugin's inline settings into the runtime overlay Commons/
    // ShellConfig reads (the omarchy-bar shim writes the same file). A plugin
    // may only write its own entry.
    function updateEntryInline(callerId: string, target: string, settings): bool {
        if (String(target) !== callerId || settings === null || typeof settings !== "object")
            return false;
        for (const key in settings) {
            const json = JSON.stringify(settings[key]);
            if (json === undefined)
                continue;
            Quickshell.execDetached(["omarchy-bar", "set", callerId, key, json, "--json"]);
        }
        return true;
    }

    // `rescanPlugins`: the dev index is read once per shell load, so a rescan
    // reloads the shell. Without the dev loader there is nothing to rescan.
    function rescan(): string {
        if (!Config.devPlugins)
            return "disabled";
        Qt.callLater(() => Quickshell.reload(false));
        return "ok";
    }

    property Component shellApiC: Component {
        Api.PluginShellApi {}
    }
    property Component registryApiC: Component {
        Api.PluginRegistryApi {}
    }
    property Component barWidgetRegistryApiC: Component {
        Api.PluginBarWidgetRegistryApi {}
    }
    property Component barStateApiC: Component {
        Api.PluginBarStateApi {
            barHidden: root.barHidden
            barSize: Style.barHeight
            fontFamily: Style.fontFamily
            position: "top"
        }
    }
    property Component appLibraryApiC: Component {
        Api.PluginAppLibraryApi {
            id: appLibrary

            readonly property Connections _apps: Connections {
                target: DesktopEntries.applications
                function onValuesChanged() {
                    appLibrary.appsChanged();
                }
            }
        }
    }
}
