import qs.Ui
import qs.Commons
import qs.Services

// Free-space warning: a pure view over Services/DiskSpace. Hidden until the
// filesystem holding the Nix store drops to marchyo.shell.diskWarnPercent free.
// Registered but not placed by default: add marchyo.disk to a bar section.
BarItem {
    id: root

    shown: DiskSpace.low
    text: "󰋊 " + DiskSpace.freePercent + "%"
    textColor: DiskSpace.freePercent <= DiskSpace.warnPercent / 2 ? Colors.statusErr : Colors.statusWarn
    tooltipText: I18n.t("disk.low", DiskSpace.freeText)
}
