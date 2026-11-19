import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// M12.2 visual prototype: one inventory workflow, adapted for phone and desktop.
// This is presentation-only sample data; it is not connected to inventory APIs.
ApplicationWindow {
    id: window
    visible: true
    width: 1180
    height: 820
    minimumWidth: 360
    minimumHeight: 600
    title: "Miselium — Persediaan"
    color: "#f3f5f7"

    readonly property bool compact: width < 720
    readonly property bool medium: width >= 720 && width < 1080

    property var stockItems: [
        { name: "Serbuk kayu", category: "Bahan utama", quantity: "1.250", unit: "kg", status: "Aman", color: "#16845b" },
        { name: "Dedak padi", category: "Bahan tambahan", quantity: "180", unit: "kg", status: "Menipis", color: "#bd7918" },
        { name: "Kapur", category: "Bahan tambahan", quantity: "42", unit: "kg", status: "Aman", color: "#16845b" },
        { name: "Plastik baglog", category: "Kemasan", quantity: "3.400", unit: "pcs", status: "Aman", color: "#16845b" }
    ]

    component MetricCard: Rectangle {
        required property string caption
        required property string value
        required property string detail
        Layout.fillWidth: true
        implicitHeight: 102
        radius: 12
        color: "#ffffff"
        border.color: "#e1e6eb"
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 5
            Label { text: caption; color: "#647181"; font.pixelSize: 12 }
            Label { text: value; color: "#172331"; font.pixelSize: 24; font.weight: Font.DemiBold }
            Label { text: detail; color: "#647181"; font.pixelSize: 11 }
        }
    }

    component ActionButton: Button {
        required property string symbol
        required property string caption
        Layout.fillWidth: true
        implicitHeight: 48
        text: symbol + "   " + caption
        font.pixelSize: 13
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 62
            color: "#ffffff"
            border.color: "#e1e6eb"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: window.compact ? 16 : 28
                anchors.rightMargin: window.compact ? 16 : 28
                Label {
                    text: "miselium"
                    color: "#172331"
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
                Label {
                    visible: !window.compact
                    text: " / Operasional / Persediaan"
                    color: "#647181"
                    font.pixelSize: 13
                }
                Item { Layout.fillWidth: true }
                Label { text: "Gudang Utama"; color: "#526170"; font.pixelSize: 12 }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: "#e9eef3"
                    Label { anchors.centerIn: parent; text: "A"; color: "#344454"; font.weight: Font.DemiBold }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            Rectangle {
                visible: !window.compact
                Layout.fillHeight: true
                Layout.preferredWidth: window.medium ? 76 : 220
                color: "#202d3b"
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8
                    Repeater {
                        model: [
                            { icon: "⌂", name: "Beranda" },
                            { icon: "▦", name: "Operasional" },
                            { icon: "▤", name: "Persediaan" },
                            { icon: "▥", name: "Produksi" },
                            { icon: "⚙", name: "Pengaturan" }
                        ]
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 44
                            radius: 8
                            color: modelData.name === "Persediaan" ? "#34485b" : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                spacing: 12
                                Label { text: modelData.icon; color: "#ffffff"; font.pixelSize: 18 }
                                Label {
                                    visible: !window.medium
                                    text: modelData.name
                                    color: "#ffffff"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Label {
                        visible: !window.medium
                        text: "Miselium v0.1"
                        color: "#9eacb9"
                        font.pixelSize: 11
                    }
                }
            }

            ScrollView {
                id: contentScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true

                ColumnLayout {
                    width: contentScroll.availableWidth
                    spacing: 18
                    anchors.margins: window.compact ? 16 : 28

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Label {
                                text: "Persediaan"
                                color: "#172331"
                                font.pixelSize: window.compact ? 23 : 28
                                font.weight: Font.DemiBold
                            }
                            Label {
                                text: "Pantau stok dan catat pergerakan bahan."
                                color: "#647181"
                                font.pixelSize: 12
                                wrapMode: Text.WordWrap
                            }
                        }
                        Button {
                            visible: !window.compact
                            text: "+ Terima barang"
                            highlighted: true
                        }
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: window.compact ? 1 : (window.medium ? 2 : 3)
                        columnSpacing: 12
                        rowSpacing: 12
                        MetricCard { caption: "Total jenis bahan"; value: "24"; detail: "4 kategori aktif" }
                        MetricCard { caption: "Stok perlu perhatian"; value: "3"; detail: "Di bawah batas minimum" }
                        MetricCard { visible: !window.compact; caption: "Nilai persediaan"; value: "Rp 18,4 jt"; detail: "Berdasarkan harga rata-rata" }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        ActionButton { symbol: "＋"; caption: "Barang masuk"; highlighted: true }
                        ActionButton { symbol: "−"; caption: "Barang keluar" }
                        ActionButton { visible: !window.compact; symbol: "⇄"; caption: "Penyesuaian" }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 54
                        radius: 10
                        color: "#ffffff"
                        border.color: "#e1e6eb"
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            Label { text: "⌕"; color: "#647181"; font.pixelSize: 20 }
                            TextField {
                                Layout.fillWidth: true
                                placeholderText: "Cari nama bahan atau kategori..."
                                background: null
                            }
                            ToolButton { text: "Filter" }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "Daftar bahan"
                            color: "#172331"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                            Layout.fillWidth: true
                        }
                        Label { text: "Terakhir diperbarui 08.30"; color: "#7a8794"; font.pixelSize: 11; visible: !window.compact }
                    }

                    // Phone: readable record cards. Expanded: aligned table-like rows.
                    Repeater {
                        model: window.stockItems
                        delegate: Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: window.compact ? 92 : 62
                            radius: 10
                            color: "#ffffff"
                            border.color: "#e1e6eb"

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 12
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Label { text: modelData.name; color: "#172331"; font.pixelSize: 14; font.weight: Font.DemiBold }
                                    Label { text: modelData.category; color: "#7a8794"; font.pixelSize: 11 }
                                }
                                ColumnLayout {
                                    spacing: 3
                                    Label { text: modelData.quantity + " " + modelData.unit; color: "#172331"; font.pixelSize: 14; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignRight }
                                    Label { text: modelData.status; color: modelData.color; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                                }
                                ToolButton { text: "⋯"; onClicked: itemMenu.popup() }
                                Menu {
                                    id: itemMenu
                                    MenuItem { text: "Lihat detail" }
                                    MenuItem { text: "Catat pergerakan" }
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            visible: window.compact
            Layout.fillWidth: true
            implicitHeight: 66
            color: "#ffffff"
            border.color: "#e1e6eb"
            RowLayout {
                anchors.fill: parent
                Repeater {
                    model: [
                        { icon: "⌂", name: "Beranda" },
                        { icon: "▦", name: "Operasional" },
                        { icon: "▤", name: "Stok" },
                        { icon: "⚙", name: "Pengaturan" }
                    ]
                    delegate: ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Label { text: modelData.icon; color: modelData.name === "Stok" ? "#176b55" : "#647181"; font.pixelSize: 19; Layout.alignment: Qt.AlignHCenter }
                        Label { text: modelData.name; color: modelData.name === "Stok" ? "#176b55" : "#647181"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                    }
                }
            }
        }
    }
}
