import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 1080
    height: 800
    minimumWidth: 760
    minimumHeight: 620
    title: appController.appName
    color: "#0b1220"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        TabBar {
            id: navigation
            Layout.fillWidth: true
            background: Rectangle { color: "#111c2f" }
            TabButton { text: "Dashboard" }
            TabButton { text: "Camera & Scanner" }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: navigation.currentIndex

            DashboardPage { }
            CameraPage { }
        }
    }
}
