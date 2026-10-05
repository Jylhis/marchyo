import QtQuick
import Quickshell
import qs.Commons
import qs.Services
import "../Commons/LauncherProviders.js" as Providers

// "!" session actions: lock, log out, suspend, hibernate, reboot, shut down.
// Each runs the matching `marchyo <verb>` power command, except lock, which
// goes to the shell's own lock surface (Services/Lock), the locker the
// running shell provides.
Provider {
    id: root

    providerId: "power"
    prefix: Providers.prefixFor("power")
    selectOnEmpty: true

    readonly property var rows: Providers.POWER_ACTIONS.map(a => ({
                title: a.title,
                subtitle: "",
                icon: a.icon,
                score: 0,
                positions: [],
                activate: () => {
                    Launcher.close();
                    if (a.verb === "lock")
                        Lock.lock();
                    else
                        Quickshell.execDetached([Config.marchyo, a.verb]);
                }
            }))

    results: Providers.rank(root.rows, root.query, (text, q) => Fuzzy.match(text, q))
}
