import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

Panel {
  id: root
  moduleName: "network-devices.plugin"
  ipcTarget: "network-devices.plugin"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property string pluginDir: Model.pluginDirFromUrl(Qt.resolvedUrl("manifest.json"))
  readonly property string helper: Model.helperPath(pluginDir)

  readonly property int refreshIntervalSec: Math.max(15, Number(setting("refreshIntervalSec", 60)) || 60)
  readonly property bool showCount: {
    var value = setting("showCount", "On")
    if (value === false || value === "Off" || value === "off") return false
    return true
  }

  property var hosts: []
  property string iface: ""
  property string selfIp: ""
  property string errorText: ""
  property bool everScanned: false
  property bool scanning: false
  property string scanStdout: ""
  property int selectedIndex: 0
  property bool cursorActive: false
  property int phraseIndex: 0

  readonly property var activePhrases: [
    "Listening for hosts",
    "Asking the mesh",
    "Collecting .locals",
    "Walking the LAN",
    "Sniffing mDNS",
    "Counting neighbours"
  ]
  readonly property string heroStatusText: {
    if (scanning) return activePhrases[phraseIndex % activePhrases.length]
    if (errorText !== "") return "Discovery issue"
    if (!everScanned) return "Waiting"
    if (hosts.length === 0) return "No hosts yet"
    return hosts.length + " host" + (hosts.length === 1 ? "" : "s")
      + (iface !== "" ? " on " + iface : "")
  }
  readonly property string countText: Model.barCountText(hosts)
  readonly property string barLabel: showCount ? ("󰒍 " + countText) : "󰒍"

  function refresh() {
    if (scanProc.running) return
    scanning = true
    scanStdout = ""
    scanProc.running = true
  }

  function applyScan(text) {
    scanning = false
    everScanned = true
    var parsed = Model.normalizeHosts(Model.parseJson(text, {}))
    hosts = parsed.hosts
    iface = parsed.iface
    selfIp = parsed.selfIp
    errorText = parsed.error
    if (selectedIndex >= hosts.length) selectedIndex = Math.max(0, hosts.length - 1)
  }

  function selectedHost() {
    if (hosts.length === 0) return null
    return hosts[Math.max(0, Math.min(selectedIndex, hosts.length - 1))]
  }

  function copyToClipboard(value) {
    var text = String(value || "")
    if (text === "") return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(text) + " | wl-copy"])
  }

  function copyHost(kind) {
    var host = selectedHost()
    if (!host) return
    if (kind === "name") copyToClipboard(host.name)
    else if (kind === "local") copyToClipboard(host.local)
    else copyToClipboard(host.ip)
  }

  function moveCursor(dy) {
    if (hosts.length === 0) return
    cursorActive = true
    selectedIndex = Math.max(0, Math.min(hosts.length - 1, selectedIndex + dy))
    Qt.callLater(function() {
      if (hostList.currentIndex >= 0)
        hostList.positionViewAtIndex(hostList.currentIndex, ListView.Contain)
    })
  }

  function activateCursor() {
    copyHost("ip")
  }

  function barTooltip() {
    if (errorText !== "") return "Network Devices — " + errorText
    if (!everScanned) return "Network devices"
    return countText + " network device" + (hosts.length === 1 ? "" : "s")
  }

  implicitWidth: barFace.implicitWidth
  implicitHeight: barFace.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    phraseIndex = 0
    refresh()
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 2200
    running: root.opened && root.scanning
    repeat: true
    onTriggered: root.phraseIndex++
  }

  Process {
    id: scanProc
    command: [root.helper, "scan"]
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(data) { root.scanStdout += String(data || "") }
    }
    onExited: function(exitCode) {
      root.applyScan(root.scanStdout)
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  Row {
    id: barFace
    spacing: Style.space(6)
    height: root.barSize

    WidgetButton {
      id: button
      bar: root.bar
      text: root.barLabel
      foreground: root.errorText !== "" && root.everScanned
        ? (root.bar ? root.bar.urgent : Color.urgent)
        : (root.bar ? root.bar.barForeground : root.foreground)
      tooltipText: root.barTooltip()
      onPressed: function(b) {
        if (b === Qt.MiddleButton) root.refresh()
        else root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: root.activateCursor()
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "c" || t === "C") root.copyHost("ip")
        else if (t === "n" || t === "N") root.copyHost("name")
        else if (t === "d" || t === "D") root.copyHost("local")
        else if (t === "r" || t === "R") root.refresh()
      }
    }

    Flickable {
      id: flick
      anchors.fill: parent
      contentWidth: width
      contentHeight: column.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Item {
          width: parent.width
          height: Style.space(56)

          Text {
            id: heroIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "󰒍"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
          }

          Column {
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: refreshBtn.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Network Devices"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.heroStatusText.toUpperCase()
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
              width: parent.width
            }
          }

          BarIconButton {
            id: refreshBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            bar: root.bar
            text: root.scanning ? "󰔟" : "󰑐"
            tooltipText: "Refresh"
            onPressed: root.refresh()
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Text {
          visible: root.errorText !== ""
          width: parent.width
          text: root.errorText
          color: root.bar ? root.bar.urgent : Color.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        Text {
          visible: root.hosts.length === 0 && root.errorText === ""
          width: parent.width
          text: root.scanning ? "Looking for machines…" : "No mDNS hosts found on this network."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ListView {
          id: hostList
          visible: root.hosts.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(420))
          spacing: Style.space(8)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          model: root.hosts
          currentIndex: root.cursorActive ? root.selectedIndex : -1
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: CursorSurface {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            hasCursor: root.cursorActive && root.selectedIndex === index
            foreground: root.foreground
            fill: root.hoverFill
            currentFill: root.selectedFill

            readonly property string glyph: Model.kindGlyph(modelData.kind)
            readonly property string title: modelData.self ? (modelData.name + " (this)") : modelData.name
            readonly property string subtitle: Model.hostSubtitle(modelData)

            implicitHeight: rowInner.implicitHeight + Style.spacing.rowPaddingX

            Row {
              id: rowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              spacing: Style.space(10)

              Text {
                text: row.glyph
                color: modelData.self ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                width: Style.space(22)
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
              }

              Column {
                width: parent.width - Style.space(22) - Style.space(10)
                spacing: Style.space(2)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  width: parent.width
                  text: row.title
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: modelData.self === true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  visible: row.subtitle !== ""
                  text: row.subtitle
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onEntered: {
                root.cursorActive = true
                root.selectedIndex = row.index
              }
              onClicked: function(mouse) {
                root.cursorActive = true
                root.selectedIndex = row.index
                if (mouse.button === Qt.RightButton) root.copyHost("local")
                else root.copyHost("ip")
              }
            }

            PanelToolTip {
              visible: rowMouse.containsMouse
              text: Model.hostTooltip(modelData) + "\nClick: copy IP · Right-click: copy .local"
              fontFamily: root.fontFamily
            }
          }
        }

        Text {
          visible: root.hosts.length > 0
          width: parent.width
          text: "c IP · n name · d .local · r refresh"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
