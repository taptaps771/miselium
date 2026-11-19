import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "SettingsRegistry.js" as SettingsRegistry

Item {
    id: page

    required property var themeController
    property color panelColor: themeController.panel
    property color borderColor: themeController.border
    property color accentColor: themeController.accent
    property color mutedColor: themeController.muted

    property string selectedModuleCode: ""
    property string selectedModuleTitle: ""
    property string selectedModuleDescription: ""

    // Presentation registry for the Settings shell. Each module owns its
    // implementation/page; adding a module does not change Main.qml navigation.
    property var settingsSections: SettingsRegistry.getSections()

    function selectModule(module) {
        selectedModuleCode = module.code
        selectedModuleTitle = module.title
        selectedModuleDescription = module.detail
    }

    ScrollView {
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            x: 32
            width: Math.max(0, parent.width - 64)
            spacing: 18

            Item { Layout.preferredHeight: 8 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5

                Label {
                    text: "Pengaturan Aplikasi"
                    color: themeController.text
                    font.pixelSize: 26
                    font.bold: true
                }
                Label {
                    Layout.fillWidth: true
                    text: "Pilih kelompok pengaturan. Setiap modul berdiri sendiri sehingga modul baru dapat ditambahkan tanpa mengubah struktur navigasi utama."
                    color: mutedColor
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: themeController.cardRadius
                color: themeController.panel
                border.color: themeController.border
                implicitHeight: appearanceControls.implicitHeight + 32
                ColumnLayout {
                    id: appearanceControls
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    Label { text: "TAMPILAN & TEMA"; color: themeController.accent; font.bold: true; font.pixelSize: 11 }
                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 620 ? 2 : 1
                        columnSpacing: 12
                        rowSpacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Visual style"; color: themeController.muted }
                            ComboBox { Layout.fillWidth: true; model: ["Industrial Professional", "Glassmorphism", "Minimalist", "Industrial Dark"]; currentIndex: Math.max(0, model.indexOf(themeController.style)); onActivated: themeController.style = currentText }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Color palette"; color: themeController.muted }
                            ComboBox { Layout.fillWidth: true; model: ["Office Blue", "Teal", "Violet", "Warm Earth", "Forest"]; currentIndex: Math.max(0, model.indexOf(themeController.palette)); onActivated: themeController.palette = currentText }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Appearance"; color: themeController.muted }
                            ComboBox { Layout.fillWidth: true; model: ["System", "Light", "Dark"]; currentIndex: Math.max(0, model.indexOf(themeController.mode)); onActivated: themeController.mode = currentText }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label { text: "Custom accent (#RRGGBB)"; color: themeController.muted }
                            TextField { id: accentHexField; Layout.fillWidth: true; text: themeController.customAccent; placeholderText: "#245EA8"; onEditingFinished: themeController.setCustomAccent(themeController.customAccentEnabled, text) }
                        }
                    }
                    CheckBox { text: "Gunakan warna aksen kustom"; checked: themeController.customAccentEnabled; onToggled: themeController.setCustomAccent(checked, accentHexField.text) }
                    RowLayout {
                        Layout.fillWidth: true
                        Label { Layout.fillWidth: true; text: "Preview: " + themeController.style + " · " + themeController.palette; color: themeController.muted; wrapMode: Text.WordWrap }
                        Button { text: "Reset"; onClicked: themeController.reset() }
                    }
                }
            }
            Repeater {
                model: page.settingsSections

                delegate: ColumnLayout {
                    required property var modelData
                    property var sectionData: modelData

                    Layout.fillWidth: true
                    spacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Label {
                            text: sectionData.title
                            color: accentColor
                            font.pixelSize: 11
                            font.bold: true
                            font.letterSpacing: 1.4
                        }
                        Label {
                            text: sectionData.description
                            color: mutedColor
                            font.pixelSize: 11
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: width >= 820 ? 2 : 1
                        columnSpacing: 12
                        rowSpacing: 12

                        Repeater {
                            model: sectionData.modules

                            delegate: Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 126
                                radius: themeController.cardRadius
                                color: page.panelColor
                                border.color: page.selectedModuleCode === modelData.code
                                              ? page.accentColor : page.borderColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 16
                                    spacing: 7

                                    Label {
                                        Layout.fillWidth: true
                                        text: modelData.title
                                        color: themeController.text
                                        font.pixelSize: 15
                                        font.bold: true
                                        wrapMode: Text.WordWrap
                                    }
                                    Label {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        text: modelData.description
                                        color: page.mutedColor
                                        font.pixelSize: 11
                                        wrapMode: Text.WordWrap
                                    }
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Item { Layout.fillWidth: true }
                                        Button {
                                            text: "Buka modul"
                                            onClicked: page.selectModule(modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                visible: page.selectedModuleCode !== ""
                radius: themeController.cardRadius
                color: themeController.panelInset
                border.color: page.borderColor
                implicitHeight: moduleDetail.implicitHeight + 36

                ColumnLayout {
                    id: moduleDetail
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 8

                    Label {
                        text: "MODUL TERPILIH"
                        color: page.accentColor
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                    Label {
                        text: page.selectedModuleTitle
                        color: themeController.text
                        font.pixelSize: 18
                        font.bold: true
                    }
                    Label {
                        Layout.fillWidth: true
                        text: page.selectedModuleDescription
                        color: page.mutedColor
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Kerangka navigasi modul sudah tersedia. Form operasional dan integrasi backend modul ini dikerjakan sebagai implementasi terpisah."
                        color: themeController.success
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                    }
                }
            }

            Item { Layout.preferredHeight: 12 }
        }
    }
}
