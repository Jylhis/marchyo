pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

// The first-login checklist from `marchyo setup --json`. Each item is
// { id, title, status: done | todo | skip, detail, fix: { label, argv } | null }.
// A fix argv comes from the CLI, never from a notification, and runs without a
// shell, in the shell's own terminal.
QtObject {
    id: root

    property var items: []
    property bool loaded: false

    readonly property int todoCount: root.items.filter(i => i.status === "todo").length

    function refresh(): void {
        root.listProc.running = true;
    }

    function fix(item): void {
        const argv = item && item.fix ? item.fix.argv : null;
        if (Array.isArray(argv) && argv.length === 4 && argv[0] === "marchyo" && argv[1] === "setup" && argv[2] === "fix")
            Quickshell.execDetached([Config.terminal, "--class=org.marchyo.setup", "-e", Config.marchyo, "setup", "fix", String(argv[3])]);
    }

    function finish(): void {
        root.doneProc.running = true;
    }

    readonly property var listProc: Process {
        command: [Config.marchyo, "setup", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                let report = {};
                try {
                    report = JSON.parse(text);
                } catch (e) {
                    // No answer: show the empty state.
                }
                root.items = Array.isArray(report.items) ? report.items : [];
                root.loaded = true;
            }
        }
    }

    readonly property var doneProc: Process {
        command: [Config.marchyo, "setup", "--done"]
    }
}
