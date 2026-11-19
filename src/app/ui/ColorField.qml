import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    objectName: "colorField"

    required property var themeController
    property string label: ""
    property string value: "#FFFFFF"

    signal colorAccepted(string hex)

    implicitWidth: fieldLayout.implicitWidth
    implicitHeight: fieldLayout.implicitHeight

    readonly property color currentColor: themeController.isHex(value)
        ? Qt.color(value) : "#FFFFFF"

    function normalizedHex(text) {
        return themeController.isHex(text) ? text.toUpperCase() : ""
    }

    function colorToHex(color) {
        return color.toString().toUpperCase()
    }

    function clamp01(number) {
        return Math.max(0, Math.min(1, number))
    }

    ColumnLayout {
        id: fieldLayout
        anchors.fill: parent
        spacing: 5

        Label {
            text: root.label
            color: root.themeController.muted
            font.pixelSize: 10
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                id: swatch
                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: root.themeController.controlRadius
                color: root.currentColor
                border.width: 1
                border.color: root.themeController.border
                Accessible.name: root.label + " color swatch"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: picker.open()
                }
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                text: root.value
                placeholderText: "#RRGGBB"
                selectByMouse: true
                onEditingFinished: {
                    var normalized = root.normalizedHex(text)
                    if (normalized.length > 0) {
                        text = normalized
                        root.colorAccepted(normalized)
                    } else {
                        text = root.value
                    }
                }
            }

            Button {
                text: "Pilih"
                onClicked: picker.open()
            }
        }
    }

    onValueChanged: {
        if (!hexField.activeFocus)
            hexField.text = value
    }

    Popup {
        id: picker
        objectName: "colorPickerPopup"
        parent: Overlay.overlay
        x: parent ? Math.max(16, (parent.width - width) / 2) : 0
        y: parent ? Math.max(16, (parent.height - height) / 2) : 0
        width: parent ? Math.min(360, parent.width - 32) : 320
        padding: 16
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property real hue: 0
        property real saturation: 1
        property real value: 1
        readonly property color previewColor: Qt.hsva(hue, saturation, value, 1)

        function updateFromColor(color) {
            hue = color.hsvHue >= 0 ? color.hsvHue : 0
            saturation = color.hsvSaturation
            value = color.hsvValue
        }

        onOpened: updateFromColor(root.currentColor)

        background: Rectangle {
            radius: root.themeController.cardRadius
            color: root.themeController.panel
            border.width: 1
            border.color: root.themeController.border
        }

        contentItem: ColumnLayout {
            width: picker.availableWidth
            spacing: 12

            Label {
                text: "Pilih warna " + root.label
                color: root.themeController.text
                font.pixelSize: 14
                font.bold: true
            }

            Rectangle {
                id: svPad
                Layout.fillWidth: true
                Layout.preferredHeight: 150
                radius: root.themeController.controlRadius
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: "white" }
                    GradientStop { position: 1; color: Qt.hsva(picker.hue, 1, 1, 1) }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0; color: "transparent" }
                        GradientStop { position: 1; color: "black" }
                    }
                }

                Rectangle {
                    id: svHandle
                    width: 16
                    height: 16
                    radius: 8
                    border.width: 2
                    border.color: "white"
                    color: "transparent"
                    x: picker.saturation * (svPad.width - width)
                    y: (1 - picker.value) * (svPad.height - height)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.CrossCursor
                    function updatePosition(mx, my) {
                        picker.saturation = root.clamp01(mx / svPad.width)
                        picker.value = 1 - root.clamp01(my / svPad.height)
                    }
                    onPressed: updatePosition(mouse.x, mouse.y)
                    onPositionChanged: if (pressed) updatePosition(mouse.x, mouse.y)
                }
            }

            Rectangle {
                id: hueBar
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                radius: 9
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ff0000" }
                    GradientStop { position: 0.17; color: "#ffff00" }
                    GradientStop { position: 0.33; color: "#00ff00" }
                    GradientStop { position: 0.5; color: "#00ffff" }
                    GradientStop { position: 0.67; color: "#0000ff" }
                    GradientStop { position: 0.83; color: "#ff00ff" }
                    GradientStop { position: 1.0; color: "#ff0000" }
                }

                Rectangle {
                    width: 20
                    height: 20
                    radius: 10
                    y: -1
                    border.width: 2
                    border.color: "white"
                    color: "transparent"
                    x: picker.hue * (hueBar.width - width)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    function updateHue(mx) {
                        picker.hue = root.clamp01(mx / hueBar.width)
                    }
                    onPressed: updateHue(mouse.x)
                    onPositionChanged: if (pressed) updateHue(mouse.x)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    radius: root.themeController.controlRadius
                    color: picker.previewColor
                    border.width: 1
                    border.color: root.themeController.border
                }

                TextField {
                    id: pickerHexField
                    Layout.preferredWidth: 104
                    text: root.colorToHex(picker.previewColor)
                    placeholderText: "#RRGGBB"
                    selectByMouse: true
                    onEditingFinished: {
                        if (root.themeController.isHex(text)) {
                            picker.updateFromColor(Qt.color(text))
                            text = root.colorToHex(picker.previewColor)
                        } else {
                            text = root.colorToHex(picker.previewColor)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Item { Layout.fillWidth: true }

                Button {
                    text: "Batal"
                    onClicked: picker.close()
                }

                Button {
                    text: "Terapkan"
                    highlighted: true
                    onClicked: {
                        root.colorAccepted(root.colorToHex(picker.previewColor))
                        picker.close()
                    }
                }
            }
        }
    }
}
