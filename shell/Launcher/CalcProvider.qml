import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// "=" calculator: the query evaluates through `qalc -t` (libqalculate, terse
// output: units, conversions and currencies included). One evaluation runs at
// a time; typing while one runs queues the latest expression for when it
// exits, and an answer only shows for the expression it was computed from.
// Activating copies the answer to the clipboard.
Provider {
    id: root

    providerId: "calc"
    prefix: Providers.prefixFor("calc")
    selectOnEmpty: true
    emptyText: root.expression.length === 0 ? "type an expression" : "no result"

    readonly property string expression: root.query.trim()

    // The expression the running (or last finished) evaluation was given.
    property string evaluating: ""
    property string answer: ""
    property string answerFor: ""
    property bool queued: false

    results: {
        if (root.expression.length === 0 || root.answerFor !== root.expression || root.answer.length === 0)
            return [];
        const text = root.answer;
        return [
            {
                title: text,
                subtitle: root.expression,
                icon: "accessories-calculator",
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    Quickshell.clipboardText = text;
                }
            }
        ];
    }

    onExpressionChanged: debounce.restart()

    readonly property var debounce: Timer {
        id: debounce
        interval: 120
        onTriggered: root.evaluate()
    }

    function evaluate() {
        if (root.expression.length === 0 || root.expression === root.answerFor)
            return;
        if (proc.running) {
            root.queued = true;
            return;
        }
        root.evaluating = root.expression;
        proc.running = true;
    }

    readonly property var proc: Process {
        id: proc
        // The expression travels as one argv element after "--", so qalc
        // never reads it as an option and no shell interprets it.
        command: [Config.qalc, "-t", "--", root.evaluating]
        stdout: StdioCollector {
            // A healthy answer is one short line; refuse anything larger.
            readonly property int maxChars: 4096
            onStreamFinished: {
                root.answer = text.length <= maxChars ? Providers.parseCalc(text) : "";
                root.answerFor = root.evaluating;
            }
        }
        onExited: {
            if (root.queued) {
                root.queued = false;
                Qt.callLater(root.evaluate);
            }
        }
    }
}
