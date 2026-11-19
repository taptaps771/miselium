import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: window

    required property var themeController
    property color panelColor: themeController.panel
    property color borderColor: themeController.border
    property color accentColor: themeController.accent
    property color mutedColor: themeController.muted
    property var hardwareRows: JSON.parse(appController.hardwareCapabilitiesJson)

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            x: 32
            width: Math.max(0, parent.width - 64)
            spacing: 20

            Item { Layout.preferredHeight: 8 }

            RowLayout {
                Layout.fillWidth: true
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: themeController.cardRadius
                    color: themeController.selected
                    Label {
                        anchors.centerIn: parent
                        text: "C"
                        color: accentColor
                        font.pixelSize: 26
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Label {
                        text: appController.appName
                        color: themeController.text
                        font.pixelSize: 25
                        font.bold: true
                    }
                    Label {
                        text: "PySide6 · Qt Quick · Python · Application Foundation"
                        color: mutedColor
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    radius: themeController.cardRadius
                    color: themeController.panelInset
                    border.color: themeController.border
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: 112
                    Label {
                        anchors.centerIn: parent
                        text: "M3 · CAMERA & SCANNER"
                        color: themeController.success
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: themeController.cardRadius
                color: panelColor
                border.color: borderColor
                implicitHeight: intro.implicitHeight + 44
                ColumnLayout {
                    id: intro
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 10
                    Label {
                        text: "Fondasi aplikasi aktif"
                        color: themeController.text
                        font.pixelSize: 22
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Konfigurasi bertipe, pencatatan log, error terstruktur, dan lifecycle sekarang dipisahkan dari antarmuka. Ini menjadi titik awal untuk service hardware dan adapter platform pada milestone berikutnya."
                        color: mutedColor
                        wrapMode: Text.WordWrap
                        font.pixelSize: 14
                    }
                    RowLayout {
                        spacing: 8
                        Label { text: "●"; color: themeController.success }
                        Label {
                            text: "Lifecycle: " + appController.lifecycleState
                            color: themeController.success
                            font.pixelSize: 12
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: "v" + appController.appVersion
                            color: mutedColor
                            font.pixelSize: 12
                        }
                    }
                }
            }

            Label {
                text: "RUNTIME ENVIRONMENT"
                color: accentColor
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 800 ? 3 : 1
                columnSpacing: 14
                rowSpacing: 14
                Repeater {
                    model: [
                        { title: "Python", value: appController.pythonVersion, detail: "Interpreter aktif" },
                        { title: "PySide6", value: appController.pysideVersion, detail: "Qt for Python" },
                        { title: "Platform", value: appController.platformName, detail: "Sistem operasi" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 108
                        radius: themeController.cardRadius
                        color: panelColor
                        border.color: borderColor
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 18
                            spacing: 7
                            Label { text: modelData.title; color: mutedColor; font.pixelSize: 12 }
                            Label { text: modelData.value; color: themeController.text; font.pixelSize: 20; font.bold: true }
                            Label { text: modelData.detail; color: mutedColor; font.pixelSize: 11 }
                        }
                    }
                }
            }

            Label {
                text: "APPLICATION SERVICES"
                color: accentColor
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.4
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width >= 800 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14

                Repeater {
                    model: [
                        { title: "Configuration", value: appController.environment, detail: "Environment and typed settings" },
                        { title: "API endpoint", value: appController.apiBaseUrl, detail: "Backend connection setting" },
                        { title: "Logging", value: "Rotating file + console", detail: appController.logFile },
                        { title: "Lifecycle", value: appController.lifecycleState, detail: "Controlled startup and shutdown" }
                    ]
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 104
                        radius: themeController.cardRadius
                        color: panelColor
                        border.color: borderColor
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 6
                            Label { text: modelData.title; color: mutedColor; font.pixelSize: 12 }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.value
                                color: themeController.text
                                font.pixelSize: 14
                                font.bold: true
                                elide: Text.ElideMiddle
                            }
                            Label {
                                Layout.fillWidth: true
                                text: modelData.detail
                                color: mutedColor
                                font.pixelSize: 10
                                elide: Text.ElideMiddle
                            }
                        }
                    }
                }
            }

            Label {
                text: "HARDWARE ABSTRACTION LAYER"
                color: accentColor
                font.pixelSize: 11
                font.bold: true
                font.letterSpacing: 1.4
            }

            Rectangle {
                Layout.fillWidth: true
                radius: themeController.cardRadius
                color: panelColor
                border.color: borderColor
                implicitHeight: halContent.implicitHeight + 36

                ColumnLayout {
                    id: halContent
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 12

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Capability registry · " + appController.hardwarePlatform
                            color: themeController.text
                            font.pixelSize: 14
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        Label {
                            text: appController.hardwareCapabilityCount + " contracts"
                            color: mutedColor
                            font.pixelSize: 11
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Status kamera dan scanner diambil dari pemeriksaan adapter Qt Multimedia serta decoder ZXing-C++. Kamera tidak diaktifkan sampai pengguna membuka halaman kamera."
                        color: mutedColor
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 760 ? 3 : 1
                        columnSpacing: 10
                        rowSpacing: 10

                        Repeater {
                            model: window.hardwareRows
                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 58
                                radius: themeController.controlRadius
                                color: themeController.panelInset
                                border.color: borderColor
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 8
                                    Rectangle {
                                        Layout.preferredWidth: 7
                                        Layout.preferredHeight: 7
                                        radius: 4
                                        color: themeController.muted
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Label {
                                            Layout.fillWidth: true
                                            text: modelData.label
                                            color: themeController.text
                                            font.pixelSize: 11
                                            elide: Text.ElideRight
                                        }
                                        Label {
                                            text: modelData.status.replace("_", " ")
                                            color: mutedColor
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                Button {
                    text: "Keluar"
                    onClicked: appController.quit()
                }
            }
            Item { Layout.preferredHeight: 12 }
        }
    }
}
