import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// CPU utilisation from /proc/stat. Usage is the busy fraction between two
// samples, so the first tick primes the baseline and the readout starts at the
// second. Matches waybar's "cpu N%". Click opens btop in a floating terminal.
BarItem {
  id: root

  property real prevIdle: 0
  property real prevTotal: 0
  property int usage: 0

  interactive: true
  text: "cpu " + usage + "%"
  onClicked: Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.btop", "-e", Config.btop ])

  FileView {
    id: stat
    path: "/proc/stat"
    blockLoading: true
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      stat.reload();
      // First line: "cpu  user nice system idle iowait irq softirq steal ..."
      const fields = stat.text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
      if (fields.length < 5)
        return;
      const idle = fields[3] + fields[4]; // idle + iowait
      const total = fields.reduce((a, b) => a + b, 0);
      const dIdle = idle - root.prevIdle;
      const dTotal = total - root.prevTotal;
      root.prevIdle = idle;
      root.prevTotal = total;
      if (dTotal > 0)
        root.usage = Math.round(100 * (dTotal - dIdle) / dTotal);
    }
  }
}
