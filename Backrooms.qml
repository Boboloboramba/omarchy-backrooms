import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

Item {
  id: root

  property var shell: null

  property bool opened: false
  property var scene: null
  function registerScene(win) { root.scene = win }

  function open(payloadJson) { root.opened = true }
  function close() { root.opened = false }
  function ping() { return "ok" }
  function state() { return root.opened ? "open" : "closed" }
  function debug() {
    var s = root.scene
    if (!s || !s.game) return "{}"
    return s.game.debug()
  }

  function startGame() {
    var s = root.scene
    if (!s || !s.game) return "no-scene"
    s.game.startGame()
    return "ok"
  }

  IpcHandler {
    target: "backrooms"

    function show(): string { root.opened = true; return "ok" }
    function close(): string { root.opened = false; return "ok" }
    function toggle(): string { root.opened = !root.opened; return root.opened ? "open" : "closed" }
    function state(): string { return root.opened ? "open" : "closed" }
    function debug(): string { return root.debug() }
    function start(): string { return root.startGame() }
    function ping(): string { return "ok" }
  }

  Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
      id: panel
      required property var modelData

      screen: modelData
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      visible: root.opened
      color: "transparent"

      WlrLayershell.namespace: "omarchy-backrooms"
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      exclusionMode: ExclusionMode.Ignore

      property alias game: game

      Game {
        id: game
        anchors.fill: parent
        active: panel.visible
        shell: root.shell
        onExit: root.close
      }

      onVisibleChanged: {
        if (panel.visible) {
          game.forceActiveFocus()
        }
      }

      Component.onCompleted: root.registerScene(panel)
    }
  }
}