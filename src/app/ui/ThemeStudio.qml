import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: studio
    required property var themeController

    property string harmonyFilter: "All"
    property string vibeFilter: "All"
    property string compatibilityFilter: "Any"
    property string paletteFeedback: ""
    property string themeFeedback: ""

    readonly property var filteredPalettes: themeController.filterPalettes(
        harmonyFilter, vibeFilter, compatibilityFilter)

    implicitHeight: studioContent.implicitHeight

    ColumnLayout {
        id: studioContent
        width: parent.width
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            radius: themeController.cardRadius
            color: themeController.panel
            border.color: themeController.border
            implicitHeight: styleContent.implicitHeight + 32

            ColumnLayout {
                id: styleContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Label {
                    text: "THEME STUDIO"
                    color: themeController.accent
                    font.bold: true
                    font.pixelSize: 11
                    font.letterSpacing: 1.3
                }
                Label {
                    text: "Atur identitas visual Miselium"
                    color: themeController.text
                    font.pixelSize: 19
                    font.bold: true
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Visual style"; color: themeController.muted }
                        ComboBox {
                            id: styleBox
                            Layout.fillWidth: true
                            model: themeController.availableStyles
                            currentIndex: 0
                            onActivated: themeController.style = currentText

                            function syncStyleIndex() {
                                currentIndex = Math.max(0,
                                    themeController.availableStyles.indexOf(themeController.style))
                            }

                            Component.onCompleted: syncStyleIndex()
                            Connections {
                                target: themeController
                                function onStyleChanged() { styleBox.syncStyleIndex() }
                            }
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Appearance"; color: themeController.muted }
                        ComboBox {
                            id: appearanceBox
                            Layout.fillWidth: true
                            model: ["System", "Light", "Dark"]
                            currentIndex: 0
                            onActivated: themeController.mode = currentText

                            function syncModeIndex() {
                                currentIndex = Math.max(0, model.indexOf(themeController.mode))
                            }

                            Component.onCompleted: syncModeIndex()
                            Connections {
                                target: themeController
                                function onModeChanged() { appearanceBox.syncModeIndex() }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: themeController.cardRadius
            color: themeController.panel
            border.color: themeController.border
            implicitHeight: paletteContent.implicitHeight + 32

            ColumnLayout {
                id: paletteContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12
                Label {
                    text: "COLOR PALETTE EXPLORER"
                    color: themeController.accent
                    font.bold: true
                    font.pixelSize: 11
                    font.letterSpacing: 1.1
                }
                Label {
                    Layout.fillWidth: true
                    text: "Pilih kombinasi warna berdasarkan harmony, karakter visual, dan mode tampilan. Setiap palet menggunakan empat warna jangkar."
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 660 ? 3 : 1
                    columnSpacing: 8
                    rowSpacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Harmony"; color: themeController.muted; font.pixelSize: 10 }
                        ComboBox {
                            id: harmonyBox
                            Layout.fillWidth: true
                            model: ["All", "Analogous", "Complementary", "Triadic", "Monochromatic", "Split Complementary"]
                            onActivated: studio.harmonyFilter = currentText
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Style / vibe"; color: themeController.muted; font.pixelSize: 10 }
                        ComboBox {
                            id: vibeBox
                            Layout.fillWidth: true
                            model: ["All", "Professional", "Minimal", "Creative", "Organic", "Industrial", "Aurora", "Clay", "Brutalist", "Retro", "Pastel", "Neon", "Monochrome", "Corporate"]
                            onActivated: studio.vibeFilter = currentText
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Compatibility"; color: themeController.muted; font.pixelSize: 10 }
                        ComboBox {
                            id: compatibilityBox
                            Layout.fillWidth: true
                            model: ["Any", "Light", "Dark"]
                            onActivated: studio.compatibilityFilter = currentText
                        }
                    }
                }

                ComboBox {
                    id: paletteBox
                    Layout.fillWidth: true
                    model: studio.filteredPalettes
                    textRole: "name"
                    displayText: currentIndex >= 0 ? currentText : "Pilih palet warna"

                    function syncPaletteIndex() {
                        for (var i = 0; i < studio.filteredPalettes.length; ++i) {
                            if (studio.filteredPalettes[i].name === themeController.palette) {
                                currentIndex = i
                                return
                            }
                        }
                        currentIndex = -1
                    }

                    Component.onCompleted: syncPaletteIndex()
                    onModelChanged: syncPaletteIndex()
                    onActivated: function(index) {
                        var item = studio.filteredPalettes[index]
                        if (themeController.applyPalette(item))
                            studio.paletteFeedback = item.name + " diterapkan"
                    }

                    Connections {
                        target: themeController
                        function onPaletteChanged() { paletteBox.syncPaletteIndex() }
                    }

                    delegate: ItemDelegate {
                        required property var modelData
                        width: paletteBox.width
                        contentItem: RowLayout {
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Label {
                                    text: modelData.name
                                    color: themeController.text
                                    font.bold: true
                                    font.pixelSize: 12
                                }
                                Label {
                                    text: modelData.harmony + " · " + modelData.vibe
                                        + " · " + modelData.compatibility
                                    color: themeController.muted
                                    font.pixelSize: 9
                                }
                            }
                            RowLayout {
                                spacing: 3
                                Repeater {
                                    model: [modelData.brand, modelData.accent,
                                        modelData.background, modelData.border]
                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.preferredWidth: 28
                                        Layout.preferredHeight: 16
                                        radius: 3
                                        color: modelData
                                        border.color: themeController.border
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Label {
                        text: "Palet aktif · " + themeController.palette
                        color: themeController.muted
                        font.pixelSize: 10
                    }
                    Item { Layout.fillWidth: true }
                    Repeater {
                        model: [themeController.brand, themeController.accentAnchor,
                            themeController.backgroundAnchor, themeController.borderAnchor]
                        delegate: Rectangle {
                            required property string modelData
                            Layout.preferredWidth: 38
                            Layout.preferredHeight: 18
                            radius: 3
                            color: modelData
                            border.color: themeController.border
                        }
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: studio.paletteFeedback
                    color: themeController.success
                    font.pixelSize: 10
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: themeController.cardRadius
            color: themeController.panel
            border.color: themeController.border
            implicitHeight: customPaletteContent.implicitHeight + 32

            ColumnLayout {
                id: customPaletteContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Label {
                    text: "CUSTOM FOUR-COLOR PALETTE"
                    color: themeController.accent
                    font.bold: true
                    font.pixelSize: 11
                }
                Label {
                    Layout.fillWidth: true
                    text: "Gunakan color picker atau masukkan kode HEX untuk mengubah setiap jangkar warna."
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 14
                    rowSpacing: 10
                    ColorField {
                        Layout.fillWidth: true
                        themeController: studio.themeController
                        label: "Brand"
                        value: themeController.brand
                        onColorAccepted: function(hex) {
                            studio.paletteFeedback = themeController.applyAnchor("brand", hex)
                                ? "Brand diperbarui" : "Gunakan format HEX #RRGGBB"
                        }
                    }
                    ColorField {
                        Layout.fillWidth: true
                        themeController: studio.themeController
                        label: "Accent"
                        value: themeController.accentAnchor
                        onColorAccepted: function(hex) {
                            studio.paletteFeedback = themeController.applyAnchor("accent", hex)
                                ? "Accent diperbarui" : "Gunakan format HEX #RRGGBB"
                        }
                    }
                    ColorField {
                        Layout.fillWidth: true
                        themeController: studio.themeController
                        label: "Background"
                        value: themeController.backgroundAnchor
                        onColorAccepted: function(hex) {
                            studio.paletteFeedback = themeController.applyAnchor("background", hex)
                                ? "Background diperbarui" : "Gunakan format HEX #RRGGBB"
                        }
                    }
                    ColorField {
                        Layout.fillWidth: true
                        themeController: studio.themeController
                        label: "Border"
                        value: themeController.borderAnchor
                        onColorAccepted: function(hex) {
                            studio.paletteFeedback = themeController.applyAnchor("border", hex)
                                ? "Border diperbarui" : "Gunakan format HEX #RRGGBB"
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: studio.paletteFeedback
                    color: themeController.danger
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                }
                Label {
                    Layout.fillWidth: true
                    text: "Kontras Brand terhadap putih: "
                        + themeController.contrastRatio(themeController.brand, "#FFFFFF").toFixed(2)
                        + ":1"
                        + (themeController.contrastRatio(themeController.brand, "#FFFFFF") >= 4.5
                            ? " · memenuhi AA untuk teks normal"
                            : " · gunakan teks putih besar atau pilih warna brand lebih gelap")
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                }
                Rectangle {
                    Layout.fillWidth: true
                    radius: 10
                    color: themeController.backgroundAnchor
                    border.color: themeController.borderAnchor
                    implicitHeight: 92
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        ColumnLayout {
                            Layout.fillWidth: true
                            Label {
                                text: "Dashboard preview"
                                color: themeController.dark ? "#FFFFFF" : "#202A34"
                                font.bold: true
                            }
                            Label {
                                text: "Brand · Accent · Surface · Border"
                                color: themeController.dark ? "#D5DCE4" : "#596675"
                                font.pixelSize: 10
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 34
                            radius: 8
                            color: themeController.brand
                            Label {
                                anchors.centerIn: parent
                                text: "Action"
                                color: "#FFFFFF"
                                font.bold: true
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            radius: themeController.cardRadius
            color: themeController.panel
            border.color: themeController.border
            implicitHeight: savedContent.implicitHeight + 32
            ColumnLayout {
                id: savedContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 9
                Label {
                    text: "MY THEMES"
                    color: themeController.accent
                    font.bold: true
                    font.pixelSize: 11
                }
                Label {
                    text: "Simpan kombinasi style, palet, dan preferensi tema sebagai tema pribadi."
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                }
                TextField {
                    id: themeNameField
                    Layout.fillWidth: true
                    placeholderText: "Nama tema, misalnya Miselium Ocean"
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "Save theme"
                        onClicked: studio.themeFeedback = themeController.saveTheme(themeNameField.text)
                            ? "Tema tersimpan" : "Masukkan nama tema terlebih dahulu"
                    }
                    Item { Layout.fillWidth: true }
                    Button { text: "Reset all"; onClicked: themeController.reset() }
                }
                ComboBox {
                    id: savedThemeBox
                    Layout.fillWidth: true
                    model: themeController.savedThemes().map(function(item) { return item.name })
                    displayText: currentIndex >= 0 ? currentText : "Pilih tema tersimpan"
                }
                RowLayout {
                    Layout.fillWidth: true
                    Button {
                        text: "Apply"
                        enabled: savedThemeBox.currentIndex >= 0
                        onClicked: studio.themeFeedback = themeController.applySavedTheme(savedThemeBox.currentText)
                            ? "Tema diterapkan" : "Tema tidak ditemukan"
                    }
                    Button {
                        text: "Delete"
                        enabled: savedThemeBox.currentIndex >= 0
                        onClicked: {
                            themeController.deleteSavedTheme(savedThemeBox.currentText)
                            savedThemeBox.currentIndex = -1
                            studio.themeFeedback = "Tema dihapus"
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: studio.themeFeedback
                    color: themeController.success
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
                }
            }
        }
    }
}
