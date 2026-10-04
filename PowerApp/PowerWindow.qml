import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.PowerApp

// The power menu: a pill of buttons that slides in from the right edge of the
// screen. Which buttons it shows, in which order, and what each one runs come
// from PowerSettings (powermenu.order and commands in config.json).
PanelWindow {
    id: root

    readonly property var settings: PowerSettings.settings
    readonly property var buttons: PowerSettings.buttons

    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // Grab the keyboard while open so arrows, Return and Escape reach the menu.
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // 20px around the pill leave room for its shadow.
    implicitWidth: panelBg.implicitWidth + 40
    implicitHeight: panelBg.implicitHeight + 40
    color: "transparent"

    anchors {
        right: true
    }

    // Click outside to close.
    HyprlandFocusGrab {
        windows: [root]
        active: root.isOpen
        onCleared: root.isOpen = false
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.isOpen = false
    }

    property bool isOpen: false
    property int selectedIndex: -1

    onIsOpenChanged: {
        if (isOpen) {
            // Start keyboard navigation on the first button.
            selectedIndex = buttons.length > 0 ? 0 : -1
            panelBg.forceActiveFocus()
        }
    }

    // Run the button's command and slide the menu out.
    function activate(index: int): void {
        if (index < 0 || index >= buttons.length)
            return
        PowerSettings.runCommand(buttons[index])
        isOpen = false
    }

    // Keep the window mapped to the screen while the animation is playing.
    visible: isOpen || slideAnim.running

    margins {
        right: root.currentMargin
    }

    // Closed, the window sits fully off the right edge of the screen.
    property real currentMargin: isOpen ? settings.powermenu.marginRight
                                        : -(implicitWidth + 50)

    Behavior on currentMargin {
        NumberAnimation {
            id: slideAnim
            duration: root.settings.pill.animationDuration
            easing.type: Easing.OutQuint
        }
    }

    IpcHandler {
        target: "power"
        function toggle(): void { root.isOpen = !root.isOpen }
        function open(): void { root.isOpen = true }
        function close(): void { root.isOpen = false }
        // Re-read config.json from disk and apply the changes.
        function reload(): void {
            PowerSettings.reloadSettings()
            PowerTheme.reload()
        }
        // Open config.json in powermenu.editorCommand (or xdg-open).
        function edit(): void { PowerSettings.editConfig() }
    }

    Item {
        id: panelBg
        implicitWidth: root.settings.button.size + 2 * root.settings.pill.paddingX
        implicitHeight: buttonLayout.implicitHeight + 2 * root.settings.pill.paddingY
        anchors.centerIn: parent

        focus: true

        Keys.onUpPressed: {
            if (root.selectedIndex <= 0)
                root.selectedIndex = root.buttons.length - 1
            else
                root.selectedIndex--
        }
        Keys.onDownPressed: {
            if (root.selectedIndex >= root.buttons.length - 1)
                root.selectedIndex = 0
            else
                root.selectedIndex++
        }
        Keys.onReturnPressed: root.activate(root.selectedIndex)
        Keys.onEnterPressed: root.activate(root.selectedIndex)

        RectangularShadow {
            anchors.fill: mainBgRect
            radius: mainBgRect.radius
            blur: 15
            color: Qt.rgba(PowerTheme.shadow.r, PowerTheme.shadow.g, PowerTheme.shadow.b, 0.4)
        }

        Rectangle {
            id: mainBgRect
            anchors.fill: parent
            radius: root.settings.pill.radius
            // Only the background is transparent, not the buttons.
            opacity: root.settings.opacity.normal

            // Gradient border (outer)
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: root.settings.border.colorTop !== ""
                        ? root.settings.border.colorTop
                        : PowerTheme.primary
                }
                GradientStop {
                    position: 1.0
                    color: root.settings.border.colorBottom !== ""
                        ? root.settings.border.colorBottom
                        : PowerTheme.on_primary
                }
            }

            // Background fill (inner), inset by the border thickness
            Rectangle {
                anchors.fill: parent
                anchors.margins: root.settings.border.width
                radius: Math.max(0, parent.radius - anchors.margins)
                color: PowerTheme.background
            }
        }

        ColumnLayout {
            id: buttonLayout
            anchors.centerIn: parent
            spacing: root.settings.button.spacing

            Repeater {
                model: root.buttons

                PowerButton {
                    required property string modelData
                    required property int index

                    iconSrc: PowerSettings.buttonIcons[modelData]
                    selected: root.selectedIndex === index
                    onClicked: root.activate(index)
                }
            }
        }
    }
}
