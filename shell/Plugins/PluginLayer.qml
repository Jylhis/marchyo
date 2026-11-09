import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import "../Commons/PluginManifest.js" as PM

// Mounts the panel, menu, overlay and service plugins of Commons/PluginIndex
// (omarchy's plugin kinds). A panel, menu or overlay plugin gets one Loader,
// active while it is open or, with `keepLoaded`, always; Services/PluginHost
// delivers open()/close() and the payload. A service plugin is created once at
// startup. On load each plugin receives the properties omarchy injects (only
// the ones it declares): omarchyPath, shell, manifest, pluginRegistry,
// barWidgetRegistry and service. Bar widgets are mounted by shell.qml.
Item {
    id: pluginLayer
    visible: false

    property bool servicesReady: false

    function inject(item, id) {
        if ("omarchyPath" in item)
            item.omarchyPath = Quickshell.env("OMARCHY_PATH") || "";
        if ("shell" in item)
            item.shell = PluginHost.shellFor(id);
        if ("manifest" in item)
            item.manifest = PluginHost.publicManifest(id);
        if ("barWidgetRegistry" in item)
            item.barWidgetRegistry = PluginHost.barWidgetRegistryFor(id);
        if ("pluginRegistry" in item)
            item.pluginRegistry = PluginHost.registryFor(id);
        if ("service" in item)
            item.service = PluginHost.serviceFor(id);
    }

    function hostedEntries(): var {
        const out = [];
        const all = PluginIndex.allPlugins();
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            const key = ["panel", "menu", "overlay"].find(k => p.entryPoints && p.entryPoints[k]);
            if (key !== undefined && PM.isHosted(p))
                out.push({
                    "id": p.id,
                    "url": p.entryPoints[key],
                    "keepLoaded": p.keepLoaded === true
                });
        }
        return out;
    }

    function startServices(): void {
        const all = PluginIndex.allPlugins();
        for (let i = 0; i < all.length; i++) {
            const p = all[i];
            if (!PM.hasKind(p, "service") || !p.entryPoints.service)
                continue;
            const comp = Qt.createComponent(p.entryPoints.service, Component.PreferSynchronous);
            if (comp.status !== Component.Ready) {
                console.warn(`service plugin ${p.id}: ${comp.errorString()}`);
                continue;
            }
            const inst = comp.createObject(null);
            if (inst === null) {
                console.warn(`service plugin ${p.id}: could not be created`);
                continue;
            }
            pluginLayer.inject(inst, p.id);
            PluginHost.registerService(p.id, inst);
        }
        pluginLayer.servicesReady = true;
    }

    // A `bar` plugin selected by marchyo.shell.barPlugin replaces the built-in
    // bar; the built-in one stays if it fails to load.
    function startBarPlugin(): void {
        const id = Config.barPlugin;
        if (id === "")
            return;
        const comp = PluginIndex.barComponent(id);
        if (comp === null || comp.status !== Component.Ready) {
            console.warn(`bar plugin ${id}: ${comp === null ? "no such bar plugin" : comp.errorString()}`);
            return;
        }
        const inst = comp.createObject(null);
        if (inst === null) {
            console.warn(`bar plugin ${id}: could not be created`);
            return;
        }
        pluginLayer.inject(inst, id);
        pluginLayer.barInstance = inst;
        PluginHost.customBar = true;
    }

    property var barInstance: null

    Component.onCompleted: {
        pluginLayer.startServices();
        pluginLayer.startBarPlugin();
    }

    Instantiator {
        model: pluginLayer.servicesReady ? pluginLayer.hostedEntries() : []

        delegate: QtObject {
            id: entry
            required property var modelData

            property Loader loader: Loader {
                source: entry.modelData.url
                active: entry.modelData.keepLoaded || PluginHost.openIds[entry.modelData.id] === true
                asynchronous: true
                onLoaded: {
                    if (!item)
                        return;
                    pluginLayer.inject(item, entry.modelData.id);
                    PluginHost.registerLoader(entry.modelData.id, this);
                }
                onStatusChanged: {
                    if (status === Loader.Error) {
                        console.warn(`panel plugin ${entry.modelData.id} failed to load: ${sourceComponent ? sourceComponent.errorString() : ""}`);
                        PluginHost.hide(entry.modelData.id);
                    }
                }
                Component.onDestruction: PluginHost.unregisterLoader(entry.modelData.id)
            }
        }
    }
}
