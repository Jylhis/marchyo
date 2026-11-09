pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "../Commons/AgentUsage.js" as AgentUsage
import "../Commons/Paths.js" as Paths

// Seat-wide AI agent usage: reads the record `marchyo agent usage` writes and
// asks the CLI for a fresh one when the agents panel opens, then on a slow
// timer only while the panel or a placed bar widget is showing. The shell
// never sees a credential; the CLI reads them and writes none to the record.
QtObject {
    id: root

    readonly property var agents: AgentUsage.readyAgents(usageFile.text())
    readonly property var tightest: AgentUsage.tightest(root.agents)
    // Providers with several accounts (`marchyo agent account`).
    readonly property var accountGroups: AgentUsage.accountGroups(usageFile.text())
    // Offer alerts already raised this session, so each is raised once.
    property var offered: ({})
    property var pendingOffer: null
    readonly property bool panelOpen: PanelManager.openId === "agents"
    // Bar widgets register on creation; one per screen it is placed on.
    property int widgets: 0
    property bool refreshing: false
    property real now: Date.now()

    function attach(): void {
        root.widgets += 1;
    }

    function detach(): void {
        root.widgets = Math.max(0, root.widgets - 1);
    }

    function refresh(force: bool): void {
        if (refreshProc.running)
            return;
        refreshProc.command = force ? [Config.marchyo, "agent", "usage", "--force"] : [Config.marchyo, "agent", "usage"];
        root.refreshing = true;
        refreshProc.running = true;
    }

    // New sessions of `provider` start as account `id`; running ones stay.
    function useAccount(provider: string, id: string): void {
        if (useProc.running)
            return;
        useProc.command = [Config.marchyo, "agent", "account", "use", provider, id];
        useProc.running = true;
    }

    // In manual mode the CLI leaves a standing offer in the record when the
    // active account crosses its threshold: one notification, click to switch.
    function raiseOffers(): void {
        if (offerProc.running)
            return;
        for (let i = 0; i < root.accountGroups.length; i++) {
            const g = root.accountGroups[i];
            if (g.mode !== "manual" || g.offer === null || root.offered[g.offer.alert])
                continue;
            const seen = Object.assign({}, root.offered);
            seen[g.offer.alert] = true;
            root.offered = seen;
            root.pendingOffer = {
                provider: g.provider,
                id: g.offer.toId
            };
            offerProc.command = ["notify-send", "-a", "marchyo", "--wait", "-A", "default=" + I18n.t("agents.offerButton", g.offer.toLabel), I18n.t("agents.offerTitle", g.offer.fromLabel, g.offer.fromPercent, g.name), I18n.t("agents.offerBody", g.offer.toLabel, g.offer.toPercent)];
            offerProc.running = true;
            return;
        }
    }

    onAccountGroupsChanged: root.raiseOffers()

    function resetText(iso: string): string {
        const p = AgentUsage.resetParts(iso, root.now);
        if (p === null)
            return "";
        if (p.days > 0)
            return I18n.t("agents.resetsDays", p.days, p.hours);
        if (p.hours > 0)
            return I18n.t("agents.resetsHours", p.hours, p.minutes);
        return I18n.t("agents.resetsMinutes", p.minutes);
    }

    function levelColor(percent: real): color {
        const l = AgentUsage.level(percent);
        return l === "err" ? Colors.statusErr : l === "warn" ? Colors.statusWarn : Colors.accent;
    }

    function resetClock(iso: string): string {
        const p = AgentUsage.resetParts(iso, root.now);
        if (p === null)
            return "";
        const hours = String(p.days * 24 + p.hours).padStart(2, "0");
        const minutes = String(p.minutes).padStart(2, "0");
        return I18n.t("agents.resetClock", hours, minutes);
    }

    function usagePath(): string {
        return Paths.xdgDir(Quickshell.env("XDG_STATE_HOME"), Quickshell.env("HOME"), "/.local/state") + "/marchyo/agents/usage.json";
    }

    onPanelOpenChanged: {
        if (root.panelOpen) {
            root.now = Date.now();
            root.refresh(false);
        }
    }

    readonly property var usageView: FileView {
        id: usageFile
        path: root.usagePath()
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: usageFile.reload()
    }

    readonly property var refreshProcess: Process {
        id: refreshProc
        // The CLI replaces the file by rename, which ends the inotify watch.
        onExited: {
            root.refreshing = false;
            root.now = Date.now();
            usageFile.reload();
        }
    }

    readonly property var useProcess: Process {
        id: useProc
        onExited: root.refresh(false)
    }

    readonly property var offerProcess: Process {
        id: offerProc
        stdout: SplitParser {
            onRead: line => {
                if (line.trim() === "default" && root.pendingOffer !== null)
                    root.useAccount(root.pendingOffer.provider, root.pendingOffer.id);
            }
        }
        onExited: {
            root.pendingOffer = null;
            root.raiseOffers();
        }
    }

    // With several accounts the record also refreshes in the background, so
    // a near-limit offer or an automatic switch happens without the panel.
    readonly property var poll: Timer {
        interval: 300000
        repeat: true
        running: root.panelOpen || root.widgets > 0 || root.accountGroups.length > 0
        triggeredOnStart: root.widgets > 0 && !root.panelOpen
        onTriggered: root.refresh(false)
    }

    readonly property var clock: Timer {
        interval: 60000
        repeat: true
        running: root.panelOpen || root.widgets > 0
        onTriggered: root.now = Date.now()
    }
}
