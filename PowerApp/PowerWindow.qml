import Quickshell
import Quickshell.Wayland
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
    // Lets Hyprland layer rules match the menu, e.g. to turn off its
    // open/close animation (see README).
    WlrLayershell.namespace: "ml4w-powermenu"
    exclusionMode: ExclusionMode.Ignore
    // Grab the keyboard while open so arrows, Return and Escape reach the menu.
    WlrLayershell.keyboardFocus: isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    color: "transparent"

    // The window covers the whole screen so clicks outside the pill can be
    // caught and close the menu. The pill itself slides in and out inside it.
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    // Click outside to close.
    MouseArea {
        anchors.fill: parent
        enabled: root.isOpen
        onClicked: root.isOpen = false
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

    // Only map the full-screen surface while the menu is open or sliding out.
    // Keeping a transparent full-screen overlay mapped all the time turns the
    // whole screen black where the compositor fails to draw transparency.
    visible: isOpen || slideAnim.running

    // While sliding out, an empty input mask lets clicks pass through to the
    // windows below.
    mask: isOpen ? null : emptyMask

    Region {
        id: emptyMask
    }

    // Distance of the pill's right edge from the screen's right edge. 20px
    // leave room for its shadow. Closed, the pill sits fully off screen.
    property real currentMargin: isOpen ? settings.powermenu.marginRight + 20
                                        : -(panelBg.implicitWidth + 70)

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
        anchors.verticalCenter: parent.verticalCenter
        x: parent.width - width - root.currentMargin
        visible: root.isOpen || slideAnim.running

        focus: true

        // Swallow clicks on the pill itself so they don't close the menu.
        MouseArea {
            anchors.fill: parent
        }

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
            // Hidden while blur is on: the blur would end in a hard edge
            // around the background (see PowerTheme.blurEnabled).
            visible: !PowerTheme.blurEnabled
            anchors.fill: mainBgRect
            radius: mainBgRect.radius
            blur: 15
            color: Qt.rgba(PowerTheme.shadow.r, PowerTheme.shadow.g, PowerTheme.shadow.b, 0.4)
        }

        // Background: fill + gradient border, each with its own opacity
        // (PowerBackground). The shared opacity (theme.opacityFile) wins over
        // opacity.normal when it is set; the border follows it or stays at 80%
        // (theme.transparentBorderFile).
        PowerBackground {
            id: mainBgRect
            anchors.fill: parent
            radius: root.settings.pill.radius
            borderWidth: root.settings.border.width
            fillOpacity: PowerTheme.globalOpacity >= 0
                ? PowerTheme.globalOpacity / 100
                : root.settings.opacity.normal

            // Border colors come from the settings file; empty strings fall
            // back to the dynamic wallpaper theme.
            colorTop: root.settings.border.colorTop !== ""
                ? root.settings.border.colorTop
                : PowerTheme.primary
            colorBottom: root.settings.border.colorBottom !== ""
                ? root.settings.border.colorBottom
                : PowerTheme.on_primary
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
