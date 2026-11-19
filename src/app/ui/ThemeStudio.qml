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
                            Layout.fillWidth: true
                            model: ["Industrial Professional", "Glassmorphism", "Minimalist",
                                "Claymorphism", "Aurora", "Brutalist", "Industrial Dark"]
                            currentIndex: Math.max(0, model.indexOf(themeController.style))
                            onActivated: themeController.style = currentText
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Appearance"; color: themeController.muted }
                        ComboBox {
                            Layout.fillWidth: true
                            model: ["System", "Light", "Dark"]
                            currentIndex: Math.max(0, model.indexOf(themeController.mode))
                            onActivated: themeController.mode = currentText
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
            implicitHeight: glassContent.implicitHeight + 32

            ColumnLayout {
                id: glassContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    Label {
                        Layout.fillWidth: true
                        text: "GLASSMORPHISM EDITOR"
                        color: themeController.accent
                        font.bold: true
                        font.pixelSize: 11
                        font.letterSpacing: 1.1
                    }
                    Button { text: "Reset"; onClicked: themeController.resetGlass() }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Kontrol ini mengatur material, transparansi, tepi, dan karakter visual permukaan kaca. Efek blur native Qt akan dioptimalkan terpisah dari nilai desainnya."
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 660 ? 2 : 1
                    columnSpacing: 18
                    rowSpacing: 10

                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Blur · " + Math.round(themeController.glassBlur) + " px"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0; to: 40; value: themeController.glassBlur; onMoved: themeController.glassBlur = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Background opacity · " + Math.round(themeController.glassOpacity * 100) + "%"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0.05; to: 0.85; value: themeController.glassOpacity; onMoved: themeController.glassOpacity = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Border opacity · " + Math.round(themeController.glassBorderOpacity * 100) + "%"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0.05; to: 1; value: themeController.glassBorderOpacity; onMoved: themeController.glassBorderOpacity = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Border radius · " + Math.round(themeController.glassRadius) + " px"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0; to: 40; value: themeController.glassRadius; onMoved: themeController.glassRadius = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Saturation · " + Math.round(themeController.glassSaturation) + "%"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0; to: 200; value: themeController.glassSaturation; onMoved: themeController.glassSaturation = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Shadow intensity · " + Math.round(themeController.glassShadow) + "%"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0; to: 80; value: themeController.glassShadow; onMoved: themeController.glassShadow = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Spotlight size · " + Math.round(themeController.glassSpotlightSize) + " px"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 80; to: 600; value: themeController.glassSpotlightSize; onMoved: themeController.glassSpotlightSize = value }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Spotlight opacity · " + Math.round(themeController.glassSpotlightOpacity * 100) + "%"; color: themeController.text }
                        Slider { Layout.fillWidth: true; from: 0; to: 0.6; value: themeController.glassSpotlightOpacity; onMoved: themeController.glassSpotlightOpacity = value }
                    }
                }

                CheckBox {
                    text: "Aktifkan glow spotlight pada preview"
                    checked: themeController.glassGlowEnabled
                    onToggled: themeController.glassGlowEnabled = checked
                }

                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 12
                    rowSpacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Base glass color"; color: themeController.muted }
                        TextField {
                            Layout.fillWidth: true
                            text: themeController.glassBaseColor
                            placeholderText: "#FFFFFF"
                            onEditingFinished: if (themeController.isHex(text)) themeController.glassBaseColor = text.toUpperCase()
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Spotlight color"; color: themeController.muted }
                        TextField {
                            Layout.fillWidth: true
                            text: themeController.glassSpotlightColor
                            placeholderText: "#FFFFFF"
                            onEditingFinished: if (themeController.isHex(text)) themeController.glassSpotlightColor = text.toUpperCase()
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Preview background"; color: themeController.muted }
                        TextField {
                            Layout.fillWidth: true
                            text: themeController.glassPreviewBackground
                            placeholderText: "#6B83A6"
                            onEditingFinished: if (themeController.isHex(text)) themeController.glassPreviewBackground = text.toUpperCase()
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    radius: 16
                    clip: true
                    color: themeController.glassPreviewBackground
                    border.color: Qt.lighter(themeController.glassPreviewBackground, 1.25)
                    Rectangle {
                        width: 150; height: 150; radius: 75
                        x: parent.width * 0.58; y: -35
                        color: themeController.brand
                        opacity: 0.7
                    }
                    Rectangle {
                        width: 120; height: 120; radius: 60
                        x: 20; y: 95
                        color: themeController.accentAnchor
                        opacity: 0.65
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        width: Math.min(parent.width - 32, 360)
                        height: 132
                        radius: themeController.glassRadius
                        color: themeController.glassSurface
                        border.color: themeController.glassBorder
                        border.width: 1
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: themeController.spotlight
                            visible: themeController.glassGlowEnabled
                            opacity: 0.55
                        }
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 5
                            Label { text: "LIVE GLASS PREVIEW"; color: themeController.text; font.bold: true; font.pixelSize: 10 }
                            Label { text: "Miselium Workspace"; color: themeController.text; font.pixelSize: 19; font.bold: true }
                            Label {
                                Layout.fillWidth: true
                                text: "Frosted surface · " + Math.round(themeController.glassBlur) + " px blur · " + Math.round(themeController.glassOpacity * 100) + "% opacity"
                                color: themeController.muted
                                wrapMode: Text.WordWrap
                                font.pixelSize: 11
                            }
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Catatan: preview ini menunjukkan tint, transparansi, border, dan radius. Blur dan saturation disimpan sebagai token; rendering backdrop blur native memerlukan tahap integrasi efek Qt yang terpisah."
                    color: themeController.muted
                    wrapMode: Text.WordWrap
                    font.pixelSize: 10
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
                            model: ["All", "Professional", "Minimal", "Creative", "Organic", "Industrial", "Aurora", "Clay", "Brutalist"]
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
                Repeater {
                    model: themeController.filterPalettes(studio.harmonyFilter, studio.vibeFilter, studio.compatibilityFilter)
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 92
                        radius: themeController.controlRadius
                        color: themeController.palette === modelData.name ? themeController.selected : themeController.panelInset
                        border.color: themeController.palette === modelData.name ? themeController.accent : themeController.border
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 10
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3
                                Label { text: modelData.name; color: themeController.text; font.bold: true; font.pixelSize: 12 }
                                Label { text: modelData.harmony + " · " + modelData.vibe + " · " + modelData.compatibility; color: themeController.muted; font.pixelSize: 9 }
                                RowLayout {
                                    spacing: 3
                                    Repeater {
                                        model: [modelData.brand, modelData.accent, modelData.background, modelData.border]
                                        delegate: Rectangle {
                                            required property string modelData
                                            Layout.preferredWidth: 34
                                            Layout.preferredHeight: 18
                                            radius: 3
                                            color: modelData
                                            border.color: "#667080"
                                        }
                                    }
                                }
                            }
                            Button {
                                text: "Pakai"
                                onClicked: {
                                    themeController.applyPalette(modelData)
                                    studio.paletteFeedback = modelData.name + " diterapkan"
                                }
                            }
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
                Label { text: "CUSTOM FOUR-COLOR PALETTE"; color: themeController.accent; font.bold: true; font.pixelSize: 11 }
                GridLayout {
                    Layout.fillWidth: true
                    columns: width >= 620 ? 2 : 1
                    columnSpacing: 10
                    rowSpacing: 8
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Brand"; color: themeController.muted; font.pixelSize: 10 }
                        TextField { id: brandField; Layout.fillWidth: true; text: themeController.brand; onEditingFinished: { } }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Accent"; color: themeController.muted; font.pixelSize: 10 }
                        TextField { id: accentField; Layout.fillWidth: true; text: themeController.accentAnchor }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Background"; color: themeController.muted; font.pixelSize: 10 }
                        TextField { id: backgroundField; Layout.fillWidth: true; text: themeController.backgroundAnchor }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Label { text: "Border"; color: themeController.muted; font.pixelSize: 10 }
                        TextField { id: borderField; Layout.fillWidth: true; text: themeController.borderAnchor }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.fillWidth: true; text: studio.paletteFeedback; color: themeController.danger; wrapMode: Text.WordWrap; font.pixelSize: 10 }
                    Button {
                        text: "Apply colors"
                        onClicked: {
                            var ok = themeController.applyCustomAnchors(brandField.text, accentField.text, backgroundField.text, borderField.text)
                            studio.paletteFeedback = ok ? "Custom palette diterapkan" : "Gunakan format HEX #RRGGBB untuk keempat warna"
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
            implicitHeight: scaleContent.implicitHeight + 32
            ColumnLayout {
                id: scaleContent
                anchors.fill: parent
                anchors.margins: 16
                spacing: 8
                Label { text: "BRAND SHADE SCALE · 11 STEPS"; color: themeController.accent; font.bold: true; font.pixelSize: 11 }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Repeater {
                        model: themeController.brandScale
                        delegate: Rectangle {
                            required property color modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            color: modelData
                            radius: 3
                        }
                    }
                }
                Label {
                    Layout.fillWidth: true
                    text: "Kontras Brand terhadap putih: " + themeController.contrastRatio(themeController.brand, "#FFFFFF").toFixed(2) + ":1"
                        + (themeController.contrastRatio(themeController.brand, "#FFFFFF") >= 4.5 ? " · memenuhi AA untuk teks normal" : " · gunakan teks putih besar atau pilih warna brand lebih gelap")
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
                            Label { text: "Dashboard preview"; color: themeController.dark ? "#FFFFFF" : "#202A34"; font.bold: true }
                            Label { text: "Brand · Accent · Surface · Border"; color: themeController.dark ? "#D5DCE4" : "#596675"; font.pixelSize: 10 }
                        }
                        Rectangle {
                            Layout.preferredWidth: 78
                            Layout.preferredHeight: 34
                            radius: 8
                            color: themeController.brand
                            Label { anchors.centerIn: parent; text: "Action"; color: "#FFFFFF"; font.bold: true; font.pixelSize: 10 }
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
                Label { text: "MY THEMES"; color: themeController.accent; font.bold: true; font.pixelSize: 11 }
                Label { text: "Simpan kombinasi style, palet, dan seluruh pengaturan Glassmorphism sebagai tema pribadi."; color: themeController.muted; wrapMode: Text.WordWrap; font.pixelSize: 10 }
                TextField { id: themeNameField; Layout.fillWidth: true; placeholderText: "Nama tema, misalnya Miselium Ocean Glass" }
                RowLayout {
                    Layout.fillWidth: true
                    Button { text: "Save theme"; onClicked: studio.themeFeedback = themeController.saveTheme(themeNameField.text) ? "Tema tersimpan" : "Masukkan nama tema terlebih dahulu" }
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
                        onClicked: studio.themeFeedback = themeController.applySavedTheme(savedThemeBox.currentText) ? "Tema diterapkan" : "Tema tidak ditemukan"
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
                Label { Layout.fillWidth: true; text: studio.themeFeedback; color: themeController.success; wrapMode: Text.WordWrap; font.pixelSize: 10 }
            }
        }
    }
}
