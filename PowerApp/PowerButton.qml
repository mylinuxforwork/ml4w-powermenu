import QtQuick
import QtQuick.Effects
import qs.PowerApp

// One round button of the power menu: an icon on a ring that fills with the
// primary color while hovered or selected with the keyboard.
Rectangle {
    id: btn

    property string iconSrc: ""
    property bool selected: false

    signal clicked()

    readonly property bool highlighted: mouseArea.containsMouse || selected
    readonly property var settings: PowerSettings.settings

    implicitWidth: settings.button.size
    implicitHeight: settings.button.size
    radius: settings.button.size / 2

    color: highlighted ? PowerTheme.primary : "transparent"
    border.color: PowerTheme.primary
    border.width: settings.button.borderWidth

    Image {
        anchors.centerIn: parent
        source: btn.iconSrc
        width: btn.settings.button.iconSize
        height: btn.settings.button.iconSize
        sourceSize.width: btn.settings.button.iconSize
        sourceSize.height: btn.settings.button.iconSize
        fillMode: Image.PreserveAspectFit
        layer.enabled: true
        layer.effect: MultiEffect {
            colorization: 1.0
            colorizationColor: btn.highlighted ? PowerTheme.background : PowerTheme.primary
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        onClicked: btn.clicked()
    }
}
