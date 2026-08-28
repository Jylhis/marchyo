import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import qs.Services

// Summoned from CpuWidget. A read-only system-resource card: CPU and memory come
// from the shared SystemStats singleton (the same sampler the bar's CpuWidget
// reads), while disk-use and CPU temperature are polled here only while the panel
// is open. "btop" opens the full monitor TUI — the action CpuWidget used to
// trigger directly. Native/sysfs data throughout; the one external tool is `df`
// (no statvfs binding exists), its path baked into Config like the others.
Panel {
  id: root
  panelId: "monitor"
  title: "System"

  // Disk use of / (df -kP: one line, 1K blocks). Polled only while open.
  property real diskUsedKb: 0
  property real diskTotalKb: 0
  property int diskPercent: 0

  // CPU temperature (millidegrees / 1000). Sensor discovered by hwmon name.
  property string tempInput: ""
  property int tempC: 0

  function gib(kb) {
    return (kb / 1048576).toFixed(1);
  }

  readonly property string memText: gib(SystemStats.memUsedKb) + " / " + gib(SystemStats.memTotalKb) + " GiB"
  readonly property string diskText: diskTotalKb > 0 ? (gib(diskUsedKb) + " / " + gib(diskTotalKb) + " GiB") : "n/a"

  Process {
    id: dfProc
    command: [ Config.df, "-kP", "/" ]
    stdout: StdioCollector {
      onStreamFinished: {
        // "Filesystem 1024-blocks Used Available Capacity Mounted on"
        const line = this.text.split("\n")[1];
        if (!line)
          return;
        const cols = line.trim().split(/\s+/);
        root.diskTotalKb = Number(cols[1]);
        root.diskUsedKb = Number(cols[2]);
        root.diskPercent = parseInt(cols[4]) || 0;
      }
    }
  }

  // Discover the CPU temperature sensor once: scan /sys/class/hwmon (via the baked
  // `ls`, no PATH reliance) and pick the first entry whose `name` is a known CPU
  // sensor (Intel coretemp, AMD k10temp/zenpower, ARM cpu_thermal). thermal_zone0
  // is unreliable (often the motherboard acpitz), so match by hwmon name instead.
  property var hwmonDirs: []

  Process {
    running: true
    command: [ Config.ls, "/sys/class/hwmon" ]
    stdout: StdioCollector {
      onStreamFinished: {
        root.hwmonDirs = this.text.split("\n").map(s => s.trim()).filter(s => s.length > 0).map(d => "/sys/class/hwmon/" + d);
      }
    }
  }

  Instantiator {
    model: root.hwmonDirs
    delegate: FileView {
      required property string modelData
      path: modelData + "/name"
      blockLoading: true
      onLoaded: {
        const name = text().trim();
        if (root.tempInput === "" && [ "coretemp", "k10temp", "zenpower", "cpu_thermal" ].indexOf(name) !== -1)
          root.tempInput = modelData + "/temp1_input";
      }
    }
  }

  FileView {
    id: tempFile
    path: root.tempInput
    blockLoading: true
  }

  // Poll disk + temperature only while the panel is open.
  Timer {
    interval: 5000
    running: root.visible
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      dfProc.running = true;
      if (root.tempInput !== "") {
        tempFile.reload();
        const t = parseInt(tempFile.text().trim());
        if (!isNaN(t))
          root.tempC = Math.round(t / 1000);
      }
    }
  }

  component StatRow: RowLayout {
    id: statRow
    property string label: ""
    property int percent: 0
    property string detail: ""

    Layout.fillWidth: true
    spacing: Style.spacing

    Text {
      Layout.preferredWidth: Style.panelWidth / 5
      text: statRow.label
      color: Color.textMuted
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSizeSmall
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Style.osdBarHeight
      radius: height / 2
      color: Color.bgSubtle

      Rectangle {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width * Math.max(0, Math.min(100, statRow.percent)) / 100
        height: parent.height
        radius: height / 2
        color: Color.accent
      }
    }

    Text {
      Layout.preferredWidth: Style.panelWidth / 3
      horizontalAlignment: Text.AlignRight
      text: statRow.detail !== "" ? statRow.detail : (statRow.percent + "%")
      color: Color.text
      font.family: Style.fontFamily
      font.pixelSize: Style.fontSizeSmall
      elide: Text.ElideRight
    }
  }

  body: [
    StatRow {
      label: "cpu"
      percent: SystemStats.cpuUsage
    },

    StatRow {
      label: "mem"
      percent: SystemStats.memPercent
      detail: root.memText
    },

    StatRow {
      label: "disk"
      percent: root.diskPercent
      detail: root.diskText
    },

    StatRow {
      label: "temp"
      visible: root.tempC > 0
      percent: Math.min(100, root.tempC)
      detail: root.tempC + " °C"
    },

    PanelButton {
      Layout.fillWidth: true
      text: "btop"
      onClicked: Quickshell.execDetached([ Config.terminal, "--class=org.omarchy.btop", "-e", Config.btop ])
    }
  ]
}
