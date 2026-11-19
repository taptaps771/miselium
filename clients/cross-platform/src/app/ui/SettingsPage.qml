import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: page
    anchors.fill: parent

    property color panelColor: "#111c2f"
    property color borderColor: "#26364d"
    property color accentColor: "#7dd3fc"
    property color mutedColor: "#9aabc2"

    property string selectedModuleCode: ""
    property string selectedModuleTitle: ""
    property string selectedModuleDescription: ""

    // Presentation registry for the Settings shell. Each module owns its
    // implementation/page; adding a module does not change Main.qml navigation.
    property var settingsSections: [
        {
            code: "operations",
            title: "OPERASIONAL",
            description: "Master data dan konfigurasi kegiatan usaha.",
            modules: [
                { code: "inventory", title: "Bahan Baku & Persediaan",
                  description: "Master bahan baku, satuan, saldo awal, dan import CSV/Excel.",
                  detail: "Modul ini menjadi tempat onboarding bahan baku dan saldo awal persediaan. Import akan menggunakan template yang dapat diunduh, preview, validasi per baris, dan konfirmasi sebelum membuat dokumen saldo awal." },
                { code: "production_machines", title: "Mesin Produksi",
                  description: "Master mesin, overhead operasional, dan penyusutan aset.",
                  detail: "Kelola Mixer, Press Baglog, Steamer, Autoclave, dan Pompa Sprayer. Tarif overhead ditentukan per mesin dan dapat memakai basis estimasi baglog, baglog aktual, durasi, siklus, konsumsi aktual, atau input manual." },
                { code: "kumbungs", title: "Kumbung",
                  description: "Nama, lokasi, pemilik, dan kapasitas kumbung.",
                  detail: "Kelola master kumbung per lokasi. Kapasitas terpakai akan dihitung dari ledger penempatan, bukan angka okupansi yang diedit manual." },
                { code: "production_recipes", title: "Preset Adonan",
                  description: "Formula berbasis bahan baku utama dan estimasi hasil mixing.",
                  detail: "Pilih satu bahan utama sebagai basis formula. Takaran bahan lain dan estimasi hasil baglog dihitung proporsional. Estimasi hanya berlaku pada Mixing dan tidak membuat stok baglog." }
            ]
        },
        {
            code: "devices",
            title: "PERANGKAT",
            description: "Integrasi perangkat keras dan otomasi.",
            modules: [
                { code: "fingerprint", title: "Mesin Fingerprint",
                  description: "Konfigurasi perangkat absensi dan sinkronisasi.",
                  detail: "Ruang pengaturan perangkat fingerprint. Koneksi, kredensial, sinkronisasi, dan log perangkat akan dikelola melalui adapter dan penyimpanan rahasia yang aman." },
                { code: "iot", title: "IoT",
                  description: "Sensor, gateway, perangkat, dan otomasi lokal.",
                  detail: "Ruang pengaturan perangkat IoT. Otomasi lokal harus tetap berjalan ketika koneksi internet atau cloud terputus." }
            ]
        },
        {
            code: "interface",
            title: "ANTARMUKA",
            description: "Preferensi tampilan aplikasi.",
            modules: [
                { code: "appearance", title: "Tampilan",
                  description: "Tema, ukuran huruf, dan preferensi antarmuka.",
                  detail: "Pengaturan tema, ukuran huruf, dan preferensi tampilan. Preferensi ini disimpan per pengguna atau per tenant sesuai cakupan pengaturannya." }
            ]
        }
    ]

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
                    color: "#f8fafc"
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
                                radius: 15
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
                                        color: "#f8fafc"
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
                radius: 16
                color: "#0c1728"
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
                        color: "#f8fafc"
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
                        color: "#a7f3d0"
                        wrapMode: Text.WordWrap
                        font.pixelSize: 11
                    }
                }
            }

            Item { Layout.preferredHeight: 12 }
        }
    }
}
