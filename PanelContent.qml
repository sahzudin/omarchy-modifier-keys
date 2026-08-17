import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Ui
import qs.Commons

// Bar-anchored panel hosting the shared ModifierContent UI. Loaded by
// BarWidget.qml when the bar-widget kind is placed in the bar.
Panel {
  id: root
  moduleName: "io.github.sahzudin.modifier-keys"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  onOpenedChanged: {
    if (opened) content.refresh()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: content.focusTarget
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(content.contentImplicitHeight, Style.space(560))

    ModifierContent {
      id: content
      anchors.fill: parent
      bar: root.bar
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
    }
  }
}