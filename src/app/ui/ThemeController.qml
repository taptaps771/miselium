import QtQuick
import QtCore

QtObject {
    id: controller

    // User preference is persisted locally by Qt. "System" follows the OS
    // color scheme where Qt exposes it; otherwise it safely falls back to Light.
    Settings {
        id: preferences
        category: "appearance"
        property string themeMode: "System"
    }

    property string mode: preferences.themeMode
    readonly property bool dark: mode === "Dark"
                                 || (mode === "System"
                                     && Qt.styleHints.colorScheme === Qt.ColorScheme.Dark)

    readonly property color window: dark ? "#171b20" : "#f3f5f7"
    readonly property color surface: dark ? "#22282f" : "#ffffff"
    readonly property color surfaceAlt: dark ? "#2b333c" : "#e9edf1"
    readonly property color sidebar: dark ? "#202830" : "#e8edf2"
    readonly property color text: dark ? "#edf1f5" : "#202a34"
    readonly property color muted: dark ? "#a5b0bb" : "#65717d"
    readonly property color border: dark ? "#3a4652" : "#d4dbe2"
    readonly property color accent: dark ? "#8ab4f8" : "#245ea8"
    readonly property color selected: dark ? "#35485c" : "#d9e6f5"
    readonly property color status: dark ? "#9aa7b3" : "#687582"

    onModeChanged: preferences.themeMode = mode
}
