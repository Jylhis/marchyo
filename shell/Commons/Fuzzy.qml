pragma Singleton
import QtQuick
import "fuzzysort.js" as Fuzzysort
import "Match.js" as Match

// The launcher's fuzzy matcher for QML: Commons/Match.js bound to the
// vendored Commons/fuzzysort.js. Both stay plain Node-testable JS (no
// `.import`), so the binding lives here. A singleton, so the whole shell
// shares one fuzzysort instance.
QtObject {
    function prepare(text) {
        return Match.prepare(text, Fuzzysort.fuzzysort);
    }

    function match(text, query) {
        return Match.match(text, query, Fuzzysort.fuzzysort);
    }

    function score(text, query) {
        return Match.score(text, query, Fuzzysort.fuzzysort);
    }

    function highlight(text, positions, color) {
        return Match.highlight(text, positions, color);
    }

    function escapeHtml(s) {
        return Match.escapeHtml(s);
    }
}
