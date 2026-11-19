import QtQuick
import QtCore

QtObject {
    id: controller
    property Settings preferences: Settings {
        category: "appearance"
        property string appearanceMode: "System"
        property string visualStyle: "Industrial Professional"
        property string colorPalette: "Office Blue"
        property bool useCustomAccent: false
        property string customAccentHex: "#245EA8"
    }

    property string mode: preferences.appearanceMode
    property string style: preferences.visualStyle
    property string palette: preferences.colorPalette
    property bool customAccentEnabled: preferences.useCustomAccent
    property string customAccent: preferences.customAccentHex

    readonly property bool dark: mode === "Dark"
        || (mode === "System" && Qt.styleHints.colorScheme === Qt.ColorScheme.Dark)
    readonly property bool glass: style === "Glassmorphism"
    readonly property bool minimal: style === "Minimalist"

    readonly property var palettes: ({
        "Office Blue": { accent: "#245EA8", accentSoft: "#D9E6F5", accentDark: "#8AB4F8" },
        "Teal": { accent: "#087F8C", accentSoft: "#D5F0EC", accentDark: "#55C7BE" },
        "Violet": { accent: "#7256B5", accentSoft: "#E9E1F8", accentDark: "#B9A5F0" },
        "Warm Earth": { accent: "#B56B25", accentSoft: "#F7E7D4", accentDark: "#E6AD70" },
        "Forest": { accent: "#39734D", accentSoft: "#DDEEE2", accentDark: "#8BC49B" }
    })

    readonly property var activePalette: palettes[palette] || palettes["Office Blue"]
    readonly property bool customAccentValid: /^#[0-9A-Fa-f]{6}$/.test(customAccent)
    readonly property color accent: customAccentEnabled && customAccentValid ? Qt.color(customAccent)
        : Qt.color(dark ? activePalette.accentDark : activePalette.accent)
    readonly property color window: dark ? "#171B20" : (glass ? "#EAF0F5" : "#F3F5F7")
    readonly property color surface: glass
        ? (dark ? "#CC252E38" : "#DDFBFDFF")
        : (dark ? "#22282F" : "#FFFFFF")
    readonly property color surfaceAlt: dark ? "#2B333C" : "#E9EDF1"
    readonly property color sidebar: glass
        ? (dark ? "#99252E38" : "#BFE7EEF5")
        : (dark ? "#202830" : "#E8EDF2")
    readonly property color panel: glass
        ? (dark ? "#AA303B49" : "#CCFFFFFF")
        : (dark ? "#22282F" : "#FFFFFF")
    readonly property color panelInset: dark ? "#202830" : "#F0F3F6"
    readonly property color text: dark ? "#EDF1F5" : "#202A34"
    readonly property color muted: dark ? "#A5B0BB" : "#65717D"
    readonly property color border: glass
        ? (dark ? "#668B9AAA" : "#99FFFFFF")
        : (dark ? "#3A4652" : "#D4DBE2")
    readonly property color selected: dark ? Qt.darker(accent, 2.2) : Qt.lighter(accent, 1.65)
    readonly property color status: dark ? "#9AA7B3" : "#687582"
    readonly property color success: dark ? "#86D6A2" : "#287A49"
    readonly property color warning: dark ? "#F2C36B" : "#986515"
    readonly property color danger: dark ? "#F18B8B" : "#B33B3B"

    readonly property int cornerRadius: minimal ? 8 : (glass ? 18 : 12)
    readonly property int cardRadius: minimal ? 10 : (glass ? 22 : 16)
    readonly property int controlRadius: minimal ? 6 : (glass ? 12 : 8)
    // Translucent surfaces are used instead of mandatory blur shaders for mobile performance.
    readonly property bool useHeavyEffects: false

    function setCustomAccent(enabled, hex) {
        customAccentEnabled = enabled
        if (hex !== undefined && /^#[0-9A-Fa-f]{6}$/.test(hex))
            customAccent = hex
    }
    function reset() {
        mode = "System"
        style = "Industrial Professional"
        palette = "Office Blue"
        customAccentEnabled = false
        customAccent = "#245EA8"
    }

    onModeChanged: preferences.appearanceMode = mode
    onStyleChanged: preferences.visualStyle = style
    onPaletteChanged: preferences.colorPalette = palette
    onCustomAccentEnabledChanged: preferences.useCustomAccent = customAccentEnabled
    onCustomAccentChanged: preferences.customAccentHex = customAccent
}
