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
    property string activeSection: "theme"

    // Presentation registry for the Settings shell. Each module owns its
    // implementation/page; adding a module does not change Main.qml navigation.
    property var settingsSections: SettingsRegistry.getSections()

    readonly property bool compact: width < 760
    readonly property var navItems: {
        var items = [{ code: "theme", title: "Tema Aplikasi", shortTitle: "Tema" }]
        for (var i = 0; i < settingsSections.length; ++i) {
            var section = settingsSections[i]
            var shortTitle = section.title
            if (section.code === "operations")
                shortTitle = "Operasional"
            else if (section.code === "devices")
                shortTitle = "Perangkat"
            else if (section.code === "interface")
                shortTitle = "Antarmuka"
            items.push({ code: section.code, title: section.title, shortTitle: shortTitle })
        }
        return items
    }
    readonly property var activeSections: {
        if (activeSection === "theme")
            return []
        var result = []
        for (var i = 0; i < settingsSections.length; ++i) {
            if (settingsSections[i].code === activeSection)
                result.push(settingsSections[i])
        }
        return result
    }

    onActiveSectionChanged: {
        selectedModuleCode = ""
        selectedModuleTitle = ""
        selectedModuleDescription = ""
    }

    function selectModule(module) {
        selectedModuleCode = module.code
        selectedModuleTitle = module.title
        selectedModuleDescription = module.detail
    }

    ScrollView {
        id: settingsScroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            x: 32
            width: Math.max(0, settingsScroll.availableWidth - 64)
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
                    text: "Pilih menu pengaturan. Tema aplikasi dikelola di menu Tema Aplikasi; modul operasional, perangkat, dan antarmuka tetap tersedia di menu masing-masing."
                    color: mutedColor
                    wrapMode: Text.WordWrap
                    font.pixelSize: 13
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: page.compact ? 44 : 48
                radius: themeController.cardRadius
                color: themeController.panelInset
                border.color: page.borderColor

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Repeater {
                        model: page.navItems

                        delegate: Button {
                            id: navButton
                            objectName: "settingsNavButton"
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            checkable: true
                            checked: page.activeSection === modelData.code
                            text: page.compact ? modelData.shortTitle : modelData.title
                            font.pixelSize: page.compact ? 10 : 12
                            onClicked: page.activeSection = modelData.code
                            Accessible.name: modelData.title

                            background: Rectangle {
                                radius: Math.max(0, themeController.controlRadius - 2)
                                color: navButton.checked ? themeController.selected : "transparent"
                                border.color: navButton.checked
                                              ? themeController.accent : "transparent"
                            }

                            contentItem: Label {
                                text: navButton.text
                                color: navButton.checked
                                       ? themeController.accent : themeController.text
                                font: navButton.font
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ThemeStudio {
                Layout.fillWidth: true
                visible: page.activeSection === "theme"
                themeController: page.themeController
            }

            Repeater {
                model: page.activeSections

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
                visible: page.activeSection !== "theme" && page.selectedModuleCode !== ""
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
