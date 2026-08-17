import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs.Ui
import qs.Commons

// Standalone panel entry point (kind: "panel"). Summoned from the Omarchy
// menu; appears centered on the primary screen. Escape, outside clicks, and
// the shell hide route all close it.
Panel {
  id: root
  moduleName: "io.github.sahzudin.modifier-keys"
  manageIpc: false

  readonly property var primaryScreen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
  readonly property int gap: Style.gapsOut

  // Keyboard focus prime: Exclusive while the surface maps, then OnDemand so
  // pointer input still reaches dismissal surfaces on other outputs.
  property bool focusPrimed: false

  readonly property real desiredHeight: {
    var inner = content.contentImplicitHeight
    if (!isFinite(inner) || inner < Style.space(80)) inner = Style.space(200)
    return inner + card.contentTopInset + card.contentBottomInset
  }

  // Prime keyboard focus when the surface actually maps (mirrors
  // KeyboardPanel): the Exclusive phase acquires compositor focus on map,
  // then settles on OnDemand so pointer input still reaches other outputs.
  function beginFocusPrime() {
    if (root.opened && win.backingWindowVisible) {
      root.focusPrimed = false
      focusPrimeTimer.restart()
      Qt.callLater(function() {
        if (root.opened) content.takeFocus()
      })
    }
  }

  onOpenedChanged: {
    if (opened) {
      content.refresh()
      root.beginFocusPrime()
    } else {
      focusPrimeTimer.stop()
      root.focusPrimed = false
    }
  }

  // Debug/IPC hook: expose the content's live state to omarchy-shell call.
  function stateJson() {
    return content.stateJson()
  }

  Timer {
    id: focusPrimeTimer
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  PanelWindow {
    id: win
    screen: root.primaryScreen
    visible: root.opened
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.namespace: "modifier-keys-panel"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.opened
      ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
      : WlrKeyboardFocus.None

    onBackingWindowVisibleChanged: root.beginFocusPrime()

    anchors {
      top: true
      bottom: true
      left: true
      right: true
    }

    // Outside-click dismissal.
    MouseArea {
      anchors.fill: parent
      enabled: root.opened
      onClicked: root.close()
    }

    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(460), parent.width - root.gap * 2)
      height: Math.min(root.desiredHeight, parent.height - root.gap * 2)
      color: Color.popups.background
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border, Math.max(1, Style.space(2)))
      padding: Style.spacing.popupPadding
      radius: Style.cornerRadius

      // Swallow clicks on the card background so they don't bubble to the
      // dismissal MouseArea behind us.
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Item {
        id: contentHolder
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset

        ModifierContent {
          id: content
          anchors.fill: parent
          bar: null
          onCloseRequested: root.close()
          onTabRequested: function() { /* no sibling panels in standalone mode */ }
        }
      }
    }
  }
}