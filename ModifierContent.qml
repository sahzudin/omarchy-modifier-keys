import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Shared settings UI for the Modifier Keys plugin. Hosted either by the
// standalone panel (Panel.qml) or the optional bar widget (PanelContent.qml).
Item {
  id: root

  property QtObject bar: null
  property color foreground: bar ? bar.foreground : Color.foreground
  property string fontFamily: bar ? bar.fontFamily : Style.font.family

  signal closeRequested()
  signal tabRequested(int direction)

  // Absolute path to the bundled apply script, resolved from this file's URL
  // so it works regardless of where the plugin folder lives.
  readonly property string applyScript: {
    var url = String(Qt.resolvedUrl("scripts/apply.py"))
    if (url.indexOf("file://") === 0) url = url.substring(7)
    return url
  }
  readonly property string pythonBin: "python3"

  // Keyboard cursor model.
  property int focusRow: 0
  property int focusPill: 0
  property bool cursorActive: false
  property bool applying: false
  property string statusText: ""

  property var selections: Model.defaultSelections()
  property var freeTokens: []
  property string appliedOptions: ""

  readonly property alias focusTarget: keyCatcher
  readonly property int contentImplicitHeight: bodyColumn.implicitHeight

  readonly property var warnings: {
    var list = []
    if (root.selections.lsuper !== "super" || root.selections.rsuper !== "super")
      list.push("Super-based shortcuts (launcher, workspaces, terminal, etc.) follow the keys you remap Super to.")
    if (root.selections.caps !== "compose")
      list.push("Caps Lock no longer acts as the Compose key (hold for accented characters).")
    return list
  }

  function rowCount() {
    return Model.rowCount()
  }

  function pillCount(rowIndex) {
    var row = Model.rowAt(rowIndex)
    return row ? row.targets.length : 0
  }

  function pillId(rowIndex, pillIndex) {
    var row = Model.rowAt(rowIndex)
    if (!row || pillIndex < 0 || pillIndex >= row.targets.length) return ""
    return row.targets[pillIndex].id
  }

  function selectedIndex(rowIndex) {
    var row = Model.rowAt(rowIndex)
    if (!row) return 0
    for (var i = 0; i < row.targets.length; i++) {
      if (row.targets[i].id === root.selections[row.id]) return i
    }
    return 0
  }

  function moveCursor(dx, dy) {
    var rows = root.rowCount()
    if (rows === 0) return
    if (!root.cursorActive) { root.cursorActive = true; return }
    if (dy !== 0) {
      var next = root.focusRow + dy
      if (next < 0) next = 0
      if (next > rows - 1) next = rows - 1
      root.focusRow = next
      root.focusPill = root.selectedIndex(next)
    } else if (dx !== 0) {
      var max = root.pillCount(root.focusRow) - 1
      var p = root.focusPill + dx
      if (p < 0) p = 0
      if (p > max) p = max
      root.focusPill = p
    }
    root.ensureVisible()
  }

  function activate() {
    var id = root.pillId(root.focusRow, root.focusPill)
    if (id) root.selectTarget(root.focusRow, id)
  }

  function selectTarget(rowIndex, targetId) {
    var row = Model.rowAt(rowIndex)
    if (!row) return
    root.selections = Model.applyTarget(root.selections, row.id, targetId)
    root.apply()
  }

  function apply() {
    if (root.applying) return
    var tokens = Model.buildTokens(root.selections)
    root.applying = true
    root.statusText = "Applying…"
    setProc.command = [root.pythonBin, root.applyScript, "set", tokens.join(",")]
    setProc.running = true
  }

  function restoreDefaults() {
    var next = Model.defaultSelections()
    next.caps = "compose"
    root.selections = next
    root.apply()
  }

  function refresh() {
    if (getProc.running) return
    getProc.running = true
  }

  function onState(json) {
    var data = {}
    try { data = JSON.parse(json) } catch (e) { data = {} }
    var tokens = Array.isArray(data.tokens) ? data.tokens : []
    root.selections = Model.inferSelections(tokens)
    root.freeTokens = Array.isArray(data.free) ? data.free : []
    root.appliedOptions = String(data.raw || "")
    root.statusText = ""
    root.focusPill = root.selectedIndex(root.focusRow)
  }

  function onApplyResult(json) {
    root.applying = false
    var data = {}
    try { data = JSON.parse(json) } catch (e) { data = {} }
    if (data && data.ok) {
      root.appliedOptions = String(data.kb_options || "")
      root.statusText = "Applied"
    } else {
      root.statusText = "Apply failed: " + String((data && data.error) || json)
    }
    root.refresh()
  }

  function ensureVisible() {
    var item = root.cursorItem
    if (!item || !scrollArea) return
    var flick = scrollArea.contentItem
    if (!flick || flick.contentY === undefined) return
    var pt = item.mapToItem(flick.contentItem || flick, 0, 0)
    var top = pt.y
    var bottom = top + (item.height || 0)
    var viewTop = flick.contentY
    var viewBottom = viewTop + flick.height
    var margin = 6
    if (top < viewTop + margin) flick.contentY = Math.max(0, top - margin)
    else if (bottom > viewBottom - margin)
      flick.contentY = bottom + margin - flick.height
  }

  function takeFocus() {
    root.cursorActive = false
    root.focusRow = 0
    root.focusPill = root.selectedIndex(0)
    keyCatcher.forceActiveFocus()
  }

  // Debug/IPC hook: return the panel's live selection state as JSON.
  function stateJson() {
    return JSON.stringify({
      selections: root.selections,
      tokens: Model.buildTokens(root.selections)
    })
  }

  Component.onCompleted: root.refresh()

  Process {
    id: getProc
    command: [root.pythonBin, root.applyScript, "get"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onState(String(text || "").trim())
    }
  }

  Process {
    id: setProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.onApplyResult(String(text || "").trim())
    }
  }

  PanelKeyCatcher {
    id: keyCatcher
    anchors.fill: parent
    onCloseRequested: root.closeRequested()
    onTabRequested: function(direction) { root.tabRequested(direction) }
    onMoveRequested: function(dx, dy) { root.moveCursor(dx, dy) }
    onActivateRequested: root.activate()
    onTextKey: function(t) {
      if (t === "r") root.refresh()
      else if (t === "d") root.restoreDefaults()
    }

    ScrollView {
      id: scrollArea
      anchors.fill: parent
      clip: true
      ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
      ScrollBar.vertical.policy: bodyColumn.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff

      Binding {
        target: scrollArea.contentItem
        property: "interactive"
        value: bodyColumn.implicitHeight > scrollArea.height
      }

      Column {
        id: bodyColumn
        width: scrollArea.availableWidth
        spacing: Style.space(10)

        // ---------- Header ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(headerIcon.implicitHeight, headerLabels.implicitHeight)

          Text {
            id: headerIcon
            text: ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: headerLabels
            anchors.left: headerIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Modifier Keys"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: "Caps Lock, Control, Alt, Super — applied live"
              color: Qt.darker(root.foreground, 1.4)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        // ---------- Rows ----------
        Repeater {
          model: root.rowCount()

          KeyRow {
            required property int index
            rowIndex: index
            width: bodyColumn.width
          }
        }

        // ---------- Footer ----------
        PanelSeparator {
          foreground: root.foreground
        }

        Row {
          id: footerRow
          width: parent.width
          spacing: Style.space(10)
          layoutDirection: Qt.LeftToRight

          Text {
            id: statusLabel
            text: root.statusText !== "" ? root.statusText : "Up to date"
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }

          Item {
            width: Math.max(0, footerRow.width - statusLabel.width - restoreButton.width - footerRow.spacing * 2)
            height: 1
          }

          Button {
            id: restoreButton
            text: "Restore defaults"
            fontSize: Style.font.caption
            foreground: root.foreground
            fontFamily: root.fontFamily
            horizontalPadding: Style.spacing.sm
            verticalPadding: Style.spacing.xxs
            bordered: true
            anchors.verticalCenter: parent.verticalCenter
            onClicked: root.restoreDefaults()
          }
        }

        Repeater {
          model: root.warnings

          Text {
            required property var modelData
            text: "⚠ " + modelData
            color: Qt.darker(root.foreground, 1.4)
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            width: parent.width
          }
        }

        Text {
          text: "j/k rows · h/l targets · Enter apply · r refresh · d defaults · Esc close"
          color: Qt.darker(root.foreground, 1.7)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          width: parent.width
        }

        Item {
          width: parent.width
          height: Style.space(2)
        }
      }
    }
  }

  component KeyRow: CursorSurface {
    id: keyRow
    required property int rowIndex

    implicitHeight: rowInner.implicitHeight + Style.spacing.sm
    hasCursor: root.cursorActive && root.focusRow === rowIndex
    onHasCursorChanged: if (hasCursor) root.ensureVisible()
    foreground: root.foreground
    outline: true

    Row {
      id: rowInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(10)

      Text {
        id: rowLabel
        text: Model.rowAt(keyRow.rowIndex).label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: hasCursor
        width: Style.space(96)
        anchors.verticalCenter: parent.verticalCenter
      }

      Flow {
        id: pills
        width: parent.width - rowLabel.width - parent.spacing
        spacing: Style.spacing.xs
        layoutDirection: Qt.LeftToRight

        Repeater {
          model: Model.rowAt(keyRow.rowIndex).targets

          PillButton {
            required property int index
            required property var modelData

            rowIndex: keyRow.rowIndex
            targetId: String(modelData.id)
            targetLabel: String(modelData.label)
            targetIndex: index
          }
        }
      }
    }

    HoverHandler {
      onHoveredChanged: function(hovered) {
        if (!hovered) return
        root.cursorActive = true
        root.focusRow = keyRow.rowIndex
        root.focusPill = root.selectedIndex(keyRow.rowIndex)
        root.ensureVisible()
      }
    }
  }

  component PillButton: Button {
    id: pill
    required property int rowIndex
    required property string targetId
    required property string targetLabel
    required property int targetIndex

    text: targetLabel
    fontSize: Style.font.caption
    foreground: root.foreground
    fontFamily: root.fontFamily
    horizontalPadding: Style.spacing.sm
    verticalPadding: Style.spacing.xxs
    bordered: true
    selected: root.selections[Model.rowAt(rowIndex).id] === targetId
    hasCursor: root.cursorActive && root.focusRow === rowIndex && root.focusPill === targetIndex

    onClicked: root.selectTarget(rowIndex, targetId)
    onHovered: function(hovered) {
      if (!hovered) return
      root.cursorActive = true
      root.focusRow = rowIndex
      root.focusPill = targetIndex
      root.ensureVisible()
    }
  }
}