import QtQuick
import QtCore

QtObject {
    id: controller

    property Settings preferences: Settings {
        category: "appearance"
        property string appearanceMode: "System"
        property string visualStyle: "Industrial Professional"
        property string colorPalette: "Office Blue"
        property string brandColor: "#245EA8"
        property string accentColor: "#3B82F6"
        property string backgroundColor: "#F3F6FA"
        property string borderColor: "#D7E0EA"
        property string savedThemesJson: "[]"
        property real glassBlur: 12
        property real glassOpacity: 0.15
        property real glassBorderOpacity: 0.30
        property real glassRadius: 16
        property real glassSaturation: 100
        property real glassShadow: 20
        property bool glassGlowEnabled: true
        property real glassSpotlightSize: 300
        property real glassSpotlightOpacity: 0.15
        property string glassSpotlightColor: "#FFFFFF"
        property string glassBaseColor: "#FFFFFF"
        property string glassPreviewBackground: "#6B83A6"
        property string glassPreviewImage: ""
    }

    property string mode: preferences.appearanceMode
    property string style: preferences.visualStyle
    property string palette: preferences.colorPalette
    property string brand: preferences.brandColor
    property string accentAnchor: preferences.accentColor
    property string backgroundAnchor: preferences.backgroundColor
    property string borderAnchor: preferences.borderColor
    property string savedThemesJson: preferences.savedThemesJson

    property real glassBlur: preferences.glassBlur
    property real glassOpacity: preferences.glassOpacity
    property real glassBorderOpacity: preferences.glassBorderOpacity
    property real glassRadius: preferences.glassRadius
    property real glassSaturation: preferences.glassSaturation
    property real glassShadow: preferences.glassShadow
    property bool glassGlowEnabled: preferences.glassGlowEnabled
    property real glassSpotlightSize: preferences.glassSpotlightSize
    property real glassSpotlightOpacity: preferences.glassSpotlightOpacity
    property string glassSpotlightColor: preferences.glassSpotlightColor
    property string glassBaseColor: preferences.glassBaseColor
    property string glassPreviewBackground: preferences.glassPreviewBackground
    property string glassPreviewImage: preferences.glassPreviewImage

    readonly property bool dark: mode === "Dark"
        || (mode === "System" && (style === "Industrial Dark" || style === "Aurora"
            || Qt.styleHints.colorScheme === Qt.ColorScheme.Dark))
    readonly property bool glass: style === "Glassmorphism"
    readonly property bool minimal: style === "Minimalist"
    readonly property bool clay: style === "Claymorphism"
    readonly property bool aurora: style === "Aurora"
    readonly property bool brutalist: style === "Brutalist"
    readonly property bool customAnchorsValid: isHex(brand) && isHex(accentAnchor)
        && isHex(backgroundAnchor) && isHex(borderAnchor)

    readonly property var paletteCatalog: [
        { name: "Office Blue", harmony: "Analogous", vibe: "Professional", compatibility: "Both", brand: "#245EA8", accent: "#3B82F6", background: "#F3F6FA", border: "#D7E0EA" },
        { name: "Ocean Teal", harmony: "Analogous", vibe: "Minimal", compatibility: "Both", brand: "#087F8C", accent: "#31B7A8", background: "#EFF8F7", border: "#C9E2DF" },
        { name: "Violet Focus", harmony: "Complementary", vibe: "Creative", compatibility: "Both", brand: "#6546A5", accent: "#D18BCB", background: "#F6F2FA", border: "#DED5EA" },
        { name: "Warm Earth", harmony: "Analogous", vibe: "Organic", compatibility: "Light", brand: "#A65E2E", accent: "#D69A55", background: "#FBF5ED", border: "#E8D8C5" },
        { name: "Forest System", harmony: "Analogous", vibe: "Organic", compatibility: "Both", brand: "#39734D", accent: "#8ABF78", background: "#F1F7F1", border: "#D3E2D2" },
        { name: "Graphite Lime", harmony: "Complementary", vibe: "Industrial", compatibility: "Both", brand: "#374151", accent: "#A3C644", background: "#F3F5F4", border: "#D5DAD8" },
        { name: "Aurora", harmony: "Triadic", vibe: "Aurora", compatibility: "Dark", brand: "#7356C5", accent: "#38C9C0", background: "#17182B", border: "#41415E" },
        { name: "Clay Studio", harmony: "Split Complementary", vibe: "Clay", compatibility: "Light", brand: "#B86F62", accent: "#D9A66F", background: "#F7EEE8", border: "#E7D5CB" },
        { name: "Brutalist Signal", harmony: "Complementary", vibe: "Brutalist", compatibility: "Both", brand: "#202020", accent: "#E9E13B", background: "#F4F1E8", border: "#B9B4A7" },
        { name: "Arctic", harmony: "Monochromatic", vibe: "Minimal", compatibility: "Both", brand: "#426A83", accent: "#8CB8CC", background: "#F1F7FA", border: "#D1E0E8" },
        { name: "Rose Quartz", harmony: "Analogous", vibe: "Creative", compatibility: "Light", brand: "#A84E72", accent: "#E49AB2", background: "#FBF1F5", border: "#EAD5DF" },
        { name: "Midnight Mint", harmony: "Triadic", vibe: "Aurora", compatibility: "Dark", brand: "#2B8C83", accent: "#B1E6C9", background: "#152522", border: "#35524C" }
    ]

    readonly property var activePalette: ({
        name: palette,
        brand: brand,
        accent: accentAnchor,
        background: backgroundAnchor,
        border: borderAnchor
    })

    readonly property color accent: Qt.color(brand)
    readonly property color window: glass ? Qt.color(glassPreviewBackground)
        : (dark ? "#171B20" : (clay ? "#F7EEE8" : Qt.color(backgroundAnchor)))
    readonly property color surface: glass ? glassSurface
        : (clay ? "#F4E8DF" : (dark ? "#22282F" : "#FFFFFF"))
    readonly property color surfaceAlt: dark ? "#2B333C" : Qt.lighter(Qt.color(backgroundAnchor), 1.025)
    readonly property color sidebar: glass ? glassSurface
        : (dark ? "#202830" : Qt.darker(Qt.color(backgroundAnchor), 1.025))
    readonly property color panel: glass ? glassSurface
        : (clay ? "#F4E8DF" : (dark ? "#22282F" : "#FFFFFF"))
    readonly property color panelInset: dark ? "#202830" : Qt.lighter(Qt.color(backgroundAnchor), 1.015)
    readonly property color text: dark ? "#EDF1F5" : "#202A34"
    readonly property color muted: dark ? "#A5B0BB" : "#65717D"
    readonly property color border: glass ? glassBorder
        : (brutalist ? Qt.color(brand) : (dark ? "#3A4652" : Qt.color(borderAnchor)))
    readonly property color selected: dark ? Qt.darker(accent, 2.2) : Qt.lighter(accent, 1.65)
    readonly property color status: dark ? "#9AA7B3" : "#687582"
    readonly property color success: dark ? "#86D6A2" : "#287A49"
    readonly property color warning: dark ? "#F2C36B" : "#986515"
    readonly property color danger: dark ? "#F18B8B" : "#B33B3B"

    readonly property color glassSurface: withAlpha(glassBaseColor, glassOpacity)
    readonly property color glassBorder: withAlpha(glassBaseColor, glassBorderOpacity)
    readonly property color spotlight: withAlpha(glassSpotlightColor, glassSpotlightOpacity)
    readonly property int cornerRadius: brutalist ? 0 : (minimal ? 8 : (glass ? glassRadius : 12))
    readonly property int cardRadius: brutalist ? 0 : (clay ? 22 : (minimal ? 10 : (glass ? glassRadius + 6 : 16)))
    readonly property int controlRadius: brutalist ? 0 : (minimal ? 6 : (glass ? Math.max(8, glassRadius - 4) : 8))
    readonly property var brandScale: makeScale(brand)
    readonly property var accentScale: makeScale(accentAnchor)
    readonly property var backgroundScale: makeScale(backgroundAnchor)
    readonly property var borderScale: makeScale(borderAnchor)
    readonly property real brandTextContrast: contrastRatio(brand, dark ? "#FFFFFF" : "#FFFFFF")
    readonly property bool useHeavyEffects: false

    function isHex(value) {
        return typeof value === "string" && /^#[0-9A-Fa-f]{6}$/.test(value)
    }

    function withAlpha(hex, alpha) {
        var c = Qt.color(isHex(hex) ? hex : "#FFFFFF")
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, alpha)))
    }

    function makeScale(hex) {
        var c = Qt.color(isHex(hex) ? hex : "#245EA8")
        return [
            Qt.lighter(c, 2.55), Qt.lighter(c, 2.15), Qt.lighter(c, 1.8),
            Qt.lighter(c, 1.5), Qt.lighter(c, 1.25), c,
            Qt.darker(c, 1.18), Qt.darker(c, 1.4), Qt.darker(c, 1.7),
            Qt.darker(c, 2.05), Qt.darker(c, 2.45)
        ]
    }

    function luminance(hex) {
        if (!isHex(hex))
            return 0
        var c = Qt.color(hex)
        function channel(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b)
    }

    function contrastRatio(first, second) {
        var a = luminance(first)
        var b = luminance(second)
        return (Math.max(a, b) + 0.05) / (Math.min(a, b) + 0.05)
    }

    function applyPalette(item) {
        if (!item || !isHex(item.brand) || !isHex(item.accent)
                || !isHex(item.background) || !isHex(item.border))
            return false
        palette = item.name
        if (item.compatibility === "Dark")
            mode = "Dark"
        else if (item.compatibility === "Light")
            mode = "Light"
        brand = item.brand
        accentAnchor = item.accent
        backgroundAnchor = item.background
        borderAnchor = item.border
        return true
    }

    function filterPalettes(harmony, vibe, compatibility) {
        var result = []
        for (var i = 0; i < paletteCatalog.length; ++i) {
            var item = paletteCatalog[i]
            if (harmony !== "All" && item.harmony !== harmony)
                continue
            if (vibe !== "All" && item.vibe !== vibe)
                continue
            if (compatibility !== "Any" && item.compatibility !== "Both"
                    && item.compatibility !== compatibility)
                continue
            result.push(item)
        }
        return result
    }

    function applyCustomAnchors(brandHex, accentHex, backgroundHex, borderHex) {
        if (!isHex(brandHex) || !isHex(accentHex)
                || !isHex(backgroundHex) || !isHex(borderHex))
            return false
        palette = "Custom"
        brand = brandHex.toUpperCase()
        accentAnchor = accentHex.toUpperCase()
        backgroundAnchor = backgroundHex.toUpperCase()
        borderAnchor = borderHex.toUpperCase()
        return true
    }

    function savedThemes() {
        try {
            var parsed = JSON.parse(savedThemesJson)
            return Array.isArray(parsed) ? parsed : []
        } catch (error) {
            return []
        }
    }

    function saveTheme(name) {
        var cleanName = name.trim()
        if (!cleanName.length)
            return false
        var items = savedThemes()
        var snapshot = {
            name: cleanName, style: style, mode: mode, palette: palette,
            brand: brand, accent: accentAnchor, background: backgroundAnchor,
            border: borderAnchor, glassBlur: glassBlur, glassOpacity: glassOpacity,
            glassBorderOpacity: glassBorderOpacity, glassRadius: glassRadius,
            glassSaturation: glassSaturation, glassShadow: glassShadow,
            glassGlowEnabled: glassGlowEnabled, glassSpotlightSize: glassSpotlightSize,
            glassSpotlightOpacity: glassSpotlightOpacity,
            glassSpotlightColor: glassSpotlightColor, glassBaseColor: glassBaseColor,
            glassPreviewBackground: glassPreviewBackground,
            glassPreviewImage: glassPreviewImage
        }
        var replaced = false
        for (var i = 0; i < items.length; ++i) {
            if (items[i].name === cleanName) {
                items[i] = snapshot
                replaced = true
                break
            }
        }
        if (!replaced)
            items.push(snapshot)
        savedThemesJson = JSON.stringify(items)
        return true
    }

    function applySavedTheme(name) {
        var items = savedThemes()
        for (var i = 0; i < items.length; ++i) {
            var item = items[i]
            if (item.name !== name)
                continue
            style = item.style || "Industrial Professional"
            mode = item.mode || "System"
            palette = item.palette || "Custom"
            applyCustomAnchors(item.brand, item.accent, item.background, item.border)
            glassBlur = Number(item.glassBlur)
            glassOpacity = Number(item.glassOpacity)
            glassBorderOpacity = Number(item.glassBorderOpacity)
            glassRadius = Number(item.glassRadius)
            glassSaturation = Number(item.glassSaturation)
            glassShadow = Number(item.glassShadow)
            glassGlowEnabled = Boolean(item.glassGlowEnabled)
            glassSpotlightSize = Number(item.glassSpotlightSize)
            glassSpotlightOpacity = Number(item.glassSpotlightOpacity)
            glassSpotlightColor = item.glassSpotlightColor || "#FFFFFF"
            glassBaseColor = item.glassBaseColor || "#FFFFFF"
            glassPreviewBackground = item.glassPreviewBackground || "#6B83A6"
            glassPreviewImage = item.glassPreviewImage || ""
            return true
        }
        return false
    }

    function deleteSavedTheme(name) {
        var items = savedThemes()
        var filtered = []
        for (var i = 0; i < items.length; ++i) {
            if (items[i].name !== name)
                filtered.push(items[i])
        }
        savedThemesJson = JSON.stringify(filtered)
    }

    function resetGlass() {
        glassBlur = 12
        glassOpacity = 0.15
        glassBorderOpacity = 0.30
        glassRadius = 16
        glassSaturation = 100
        glassShadow = 20
        glassGlowEnabled = true
        glassSpotlightSize = 300
        glassSpotlightOpacity = 0.15
        glassSpotlightColor = "#FFFFFF"
        glassBaseColor = "#FFFFFF"
        glassPreviewBackground = "#6B83A6"
        glassPreviewImage = ""
    }

    function reset() {
        mode = "System"
        style = "Industrial Professional"
        applyPalette(paletteCatalog[0])
        resetGlass()
    }

    onModeChanged: preferences.appearanceMode = mode
    onStyleChanged: preferences.visualStyle = style
    onPaletteChanged: preferences.colorPalette = palette
    onBrandChanged: preferences.brandColor = brand
    onAccentAnchorChanged: preferences.accentColor = accentAnchor
    onBackgroundAnchorChanged: preferences.backgroundColor = backgroundAnchor
    onBorderAnchorChanged: preferences.borderColor = borderAnchor
    onSavedThemesJsonChanged: preferences.savedThemesJson = savedThemesJson
    onGlassBlurChanged: preferences.glassBlur = glassBlur
    onGlassOpacityChanged: preferences.glassOpacity = glassOpacity
    onGlassBorderOpacityChanged: preferences.glassBorderOpacity = glassBorderOpacity
    onGlassRadiusChanged: preferences.glassRadius = glassRadius
    onGlassSaturationChanged: preferences.glassSaturation = glassSaturation
    onGlassShadowChanged: preferences.glassShadow = glassShadow
    onGlassGlowEnabledChanged: preferences.glassGlowEnabled = glassGlowEnabled
    onGlassSpotlightSizeChanged: preferences.glassSpotlightSize = glassSpotlightSize
    onGlassSpotlightOpacityChanged: preferences.glassSpotlightOpacity = glassSpotlightOpacity
    onGlassSpotlightColorChanged: preferences.glassSpotlightColor = glassSpotlightColor
    onGlassBaseColorChanged: preferences.glassBaseColor = glassBaseColor
    onGlassPreviewBackgroundChanged: preferences.glassPreviewBackground = glassPreviewBackground
    onGlassPreviewImageChanged: preferences.glassPreviewImage = glassPreviewImage
}
