import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtMultimedia
import QtCore
import QtQuick.Dialogs

Page {
    id: page
    required property var themeController
    background: Rectangle { color: themeController.window }

    property color panelColor: themeController.panel
    property color borderColor: themeController.border
    property color accentColor: themeController.accent
    property color mutedColor: themeController.muted

    MediaDevices { id: mediaDevices }
    CameraPermission { id: cameraPermission }

    Camera {
        id: camera
        cameraDevice: mediaDevices.defaultVideoInput
        active: false
        onErrorOccurred: function(error, errorString) {
            appController.reportCameraError(errorString)
        }
    }

    ImageCapture {
        id: imageCapture
        onImageSaved: function(requestId, fileName) {
            appController.cameraImageSaved(fileName)
        }
        onErrorOccurred: function(requestId, error, errorString) {
            appController.reportCameraError(errorString)
        }
    }

    CaptureSession {
        camera: camera
        imageCapture: imageCapture
        videoOutput: viewfinder
    }

    FileDialog {
        id: imagePicker
        title: "Pilih gambar QR / barcode"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.bmp *.webp)", "All files (*)"]
        onAccepted: appController.scanImageFile(selectedFile.toString())
    }

    function requestCameraStart() {
        if (Qt.platform.os === "android") {
            if (cameraPermission.status === Qt.PermissionStatus.Granted) {
                camera.active = true
            } else {
                cameraPermission.request()
            }
        } else {
            camera.active = true
        }
    }

    Connections {
        target: cameraPermission
        function onStatusChanged() {
            if (cameraPermission.status === Qt.PermissionStatus.Granted)
                camera.active = true
        }
    }

    onVisibleChanged: {
        if (!visible)
            camera.active = false
    }

    ScrollView {
        anchors.fill: parent
        clip: true
        contentWidth: availableWidth

        ColumnLayout {
            width: Math.max(0, parent.width - 48)
            x: 24
            spacing: 16

            Item { Layout.preferredHeight: 4 }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Label {
                    text: "Camera & QR / Barcode Scanner"
                    color: themeController.text
                    font.pixelSize: 24
                    font.bold: true
                }
                Label {
                    text: "Preview menggunakan Qt Multimedia. Hasil foto diproses oleh decoder ZXing-C++ di worker thread."
                    color: mutedColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 360
                radius: 18
                color: "#050b14"
                border.color: borderColor
                clip: true

                VideoOutput {
                    id: viewfinder
                    anchors.fill: parent
                    fillMode: VideoOutput.PreserveAspectFit
                }

                Label {
                    anchors.centerIn: parent
                    visible: !camera.active
                    text: appController.cameraAvailable
                        ? "Kamera belum diaktifkan"
                        : "Perangkat kamera belum terdeteksi"
                    color: "#cbd5e1"
                    font.pixelSize: 14
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Button {
                    text: camera.active ? "Matikan kamera" : "Aktifkan kamera"
                    onClicked: {
                        if (camera.active)
                            camera.active = false
                        else
                            page.requestCameraStart()
                    }
                }
                Button {
                    text: "Ambil foto & scan"
                    enabled: camera.active && imageCapture.readyForCapture && !appController.scanBusy
                    onClicked: imageCapture.captureToFile(appController.createCameraCapturePath())
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "Pilih gambar"
                    enabled: !appController.scanBusy
                    onClicked: imagePicker.open()
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: panelColor
                border.color: borderColor
                implicitHeight: statusColumn.implicitHeight + 32
                ColumnLayout {
                    id: statusColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8
                    Label {
                        text: "STATUS PERANGKAT"
                        color: accentColor
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Kamera: " + appController.cameraStatus
                        color: themeController.text
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "Scanner: " + (appController.scannerAvailable ? "ZXing-C++ siap" : "Belum tersedia — pasang requirements/scanner.txt")
                        color: appController.scannerAvailable ? themeController.success : themeController.warning
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: Qt.platform.os === "android" && cameraPermission.status === Qt.PermissionStatus.Denied
                        text: "Izin kamera ditolak. Izinkan akses kamera melalui pengaturan aplikasi Android."
                        color: themeController.warning
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                radius: 14
                color: panelColor
                border.color: borderColor
                implicitHeight: resultsColumn.implicitHeight + 32
                ColumnLayout {
                    id: resultsColumn
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 9
                    RowLayout {
                        Layout.fillWidth: true
                        Label {
                            text: "HASIL PEMINDAIAN"
                            color: accentColor
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.2
                        }
                        Item { Layout.fillWidth: true }
                        BusyIndicator {
                            running: appController.scanBusy
                            visible: appController.scanBusy
                            Layout.preferredWidth: 24
                            Layout.preferredHeight: 24
                        }
                    }
                    Label {
                        Layout.fillWidth: true
                        text: appController.scanMessage
                        color: mutedColor
                        wrapMode: Text.WordWrap
                        font.pixelSize: 12
                    }
                    Repeater {
                        model: JSON.parse(appController.scanResultsJson)
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            radius: 9
                            color: themeController.panelInset
                            border.color: borderColor
                            implicitHeight: resultLayout.implicitHeight + 20
                            ColumnLayout {
                                id: resultLayout
                                anchors.fill: parent
                                anchors.margins: 10
                                spacing: 4
                                Label {
                                    text: modelData.format
                                    color: accentColor
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                                Label {
                                    Layout.fillWidth: true
                                    text: modelData.value
                                    color: themeController.text
                                    wrapMode: Text.WrapAnywhere
                                    font.pixelSize: 13
                                }
                                Button {
                                    text: "Salin hasil"
                                    onClicked: appController.copyText(modelData.value)
                                }
                            }
                        }
                    }
                }
            }

            Item { Layout.preferredHeight: 12 }
        }
    }
}
