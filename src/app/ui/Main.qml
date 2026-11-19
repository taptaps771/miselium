import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 1180
    height: 820
    minimumWidth: 360
    minimumHeight: 560
    title: appController.appName
    color: theme.window

    ThemeController {
        id: theme
    }

    readonly property bool compact: width < 720
    readonly property bool medium: width >= 720 && width < 1080
    property int currentPage: 0

    readonly property var destinations: [
        { title: "Dashboard", shortTitle: "Beranda", symbol: "⌂" },
        { title: "Camera & Scanner", shortTitle: "Scanner", symbol: "▣" },
        { title: "Pengaturan", shortTitle: "Setting", symbol: "⚙" }
    ]

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: compact ? 56 : 62
            color: theme.surface
            border.color: theme.border

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: compact ? 16 : 22
                anchors.rightMargin: compact ? 12 : 22
                spacing: 12

                Label {
                    text: compact ? "Miselium" : appController.appName
                    color: theme.text
                    font.pixelSize: compact ? 18 : 20
                    font.weight: Font.DemiBold
                }
                Label {
                    visible: !compact
                    text: "Workspace"
                    color: theme.muted
                    font.pixelSize: 12
                }
                Item { Layout.fillWidth: true }
                Label {
                    visible: !compact
                    text: "Tampilan"
                    color: theme.muted
                    font.pixelSize: 12
                }
                ComboBox {
                    id: themeSelector
                    Layout.preferredWidth: compact ? 112 : 132
                    model: ["System", "Light", "Dark"]
                    currentIndex: Math.max(0, model.indexOf(theme.mode))
                    onActivated: theme.mode = currentText
                    font.pixelSize: 12
                    Accessible.name: "Tema aplikasi"
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                visible: !compact
                Layout.fillHeight: true
                Layout.preferredWidth: medium ? 76 : 224
                color: theme.sidebar
                border.color: theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: medium ? 8 : 14
                    spacing: 8

                    Repeater {
                        model: window.destinations
                        delegate: Button {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            text: medium ? modelData.symbol : modelData.symbol + "    " + modelData.title
                            highlighted: window.currentPage === index
                            font.pixelSize: medium ? 19 : 13
                            onClicked: window.currentPage = index
                            Accessible.name: modelData.title
                            background: Rectangle {
                                radius: 7
                                color: window.currentPage === index ? theme.selected : "transparent"
                                border.color: window.currentPage === index ? theme.border : "transparent"
                            }
                            contentItem: Label {
                                text: parent.text
                                color: window.currentPage === index ? theme.accent : theme.text
                                font: parent.font
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: medium ? Text.AlignHCenter : Text.AlignLeft
                                leftPadding: medium ? 0 : 12
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }
                    Label {
                        visible: !medium
                        text: "Miselium  •  " + appController.appVersion
                        color: theme.muted
                        font.pixelSize: 10
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: window.currentPage

                DashboardPage { themeController: theme }
                CameraPage { themeController: theme }
                SettingsPage { themeController: theme }
            }
        }

        Rectangle {
            visible: compact
            Layout.fillWidth: true
            Layout.preferredHeight: 66
            color: theme.surface
            border.color: theme.border

            RowLayout {
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: window.destinations
                    delegate: ToolButton {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        onClicked: window.currentPage = index
                        Accessible.name: modelData.title
                        contentItem: ColumnLayout {
                            spacing: 1
                            Label {
                                text: modelData.symbol
                                color: window.currentPage === index ? theme.accent : theme.muted
                                font.pixelSize: 19
                                Layout.alignment: Qt.AlignHCenter
                            }
                            Label {
                                text: modelData.shortTitle
                                color: window.currentPage === index ? theme.accent : theme.muted
                                font.pixelSize: 10
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                        background: Rectangle {
                            color: window.currentPage === index ? theme.selected : "transparent"
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: !compact && !medium
            Layout.fillWidth: true
            Layout.preferredHeight: 26
            color: theme.surface
            border.color: theme.border
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                Label {
                    text: appController.lifecycleState
                    color: theme.status
                    font.pixelSize: 10
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: "v" + appController.appVersion + "  ·  " + theme.mode
                    color: theme.status
                    font.pixelSize: 10
                }
            }
        }
    }
}
