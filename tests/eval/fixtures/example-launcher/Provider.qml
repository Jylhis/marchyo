import QtQuick
import qs.Launcher
import qs.Services

// Minimal example launcher plugin (test fixture + docs reference). The root is
// a Launcher Provider; the shell sets its providerId (the plugin id) and
// prefix (the manifest prefix), so typing "?hello" in the apps palette shows
// one row that copies the query.
Provider {
    id: root

    results: root.query.length === 0 ? [] : [
        {
            "title": root.query,
            "subtitle": "copy with example.echo",
            "icon": "edit-copy",
            "score": 0,
            "positions": [],
            "activate": () => {
                const text = root.query;
                Launcher.close();
                Launcher.pasteText(text);
            }
        }
    ]
}
