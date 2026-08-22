import QtQuick
import qs.Ui

BarWidget {
  id: root
  moduleName: "local.backrooms"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u2302"
    horizontalMargin: 7.5
    tooltipText: "Omarchy Backrooms"
    onPressed: function(button) {
      if (!root.bar) return
      root.bar.run("omarchy-shell shell toggle local.backrooms '{}'")
    }
  }
}
