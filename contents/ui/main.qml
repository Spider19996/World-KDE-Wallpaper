import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

import "params.js" as Params
import "selection.js" as Sel
import "store.js" as Store

WallpaperItem {
    id: root

    readonly property var config: wallpaper.configuration
    readonly property bool covered: coveredLoader.item ? coveredLoader.item.covered : false
    readonly property bool onBattery: powerLoader.item ? powerLoader.item.onBattery : false
    readonly property bool locked: powerLoader.item ? powerLoader.item.screenLocked : false

    // Reasons not to draw
    readonly property bool paused: (config.BatteryMode === "pause" && onBattery)
                                   || (config.PauseWhenLocked && locked)
                                   || (config.PauseWhenCovered && covered)

    // Frame limit: the chosen one (0 = screen refresh rate), lower on battery if asked for
    readonly property int frameLimit: {
        var limit = config.Fps;
        if (config.BatteryMode === "limit" && onBattery)
            limit = limit > 0 ? Math.min(limit, config.BatteryFps) : config.BatteryFps;
        return limit;
    }

    // The themes that take turns (nothing ticked = the default theme)
    // Your themes are the files in the theme folder
    // Nothing watches the folder (like in Substrate there is no polling). The desktop reads it at the start, when the settings are applied (also after a save in
    // the theme manager) and when it runs again after a pause.
    ThemeFiles { id: files }
    Connections {
        target: root.config
        function onValueChanged() { ThemeSettings.refresh(); files.reload(); }
    }
    onPausedChanged: if (!paused) { ThemeSettings.refresh(); files.reload(); }
    readonly property var catalog: Store.catalog(files.ud, ThemeSettings.hideBuiltin)
    readonly property var themes: Store.selectedThemes(catalog, Sel.parse(config.ThemeSelection))

    property int index: 0
    property var current: Store.fallbackConfig()

    // A change of the settings shows at once, a rotation fades
    onThemesChanged: applyTheme(index)
    function applyTheme(i) {
        index = themes.length > 0 ? ((i % themes.length) + themes.length) % themes.length : 0;
        current = themes.length > 0 ? themes[index].config : Store.fallbackConfig();
    }

    function nextTheme() {
        if (themes.length < 2) return;
        var i = index + 1;
        if (config.RotateRandom) {
            i = Math.floor(Math.random() * (themes.length - 1));
            if (i >= index) i++;
        }
        var fade = config.FadeSeconds;
        if (fade <= 0) { applyTheme(i); return; }
        fader.target = i;
        fader.restart();
    }

    Component.onCompleted: applyTheme(config.RotateRandom ? Math.floor(Math.random() * Math.max(1, themes.length)) : 0)

    contextualActions: [
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_de.robin.world", "Next World Theme")
            icon.name: "go-next"
            onTriggered: root.nextTheme()
        },
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_de.robin.world", "Refresh Aircraft")
            icon.name: "airplane-mode"
            visible: feed.enabled
            onTriggered: feed.refresh()
        },
        PlasmaCore.Action {
            text: i18nd("plasma_wallpaper_de.robin.world", "Restart World Data Stream")
            icon.name: "view-refresh"
            onTriggered: scene.restart()
        }
    ]

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    // Live aircraft; nothing is requested while the wallpaper is paused or switched off
    AircraftFeed {
        id: feed
        // Everything comes from the theme that runs now
        readonly property var t: root.current
        enabled: t.ShowAircraft === true
        active: !root.paused
        refreshAll: t.AircraftRefreshMinutes * 60
        maxPlanes: t.AircraftMax
        labelMax: t.AircraftLabels ? t.AircraftLabelMax : 0
        lookupRoute: t.AircraftInfoRoute && t.AircraftLabels && t.AircraftLabelMax > 0
        lookupAircraft: (t.AircraftInfoType || t.AircraftInfoOperator) && t.AircraftLabels && t.AircraftLabelMax > 0
    }

    WorldScene {
        id: scene
        anchors.fill: parent
        aircraft: feed.enabled ? feed.planes : []
        p: root.current
        fps: root.frameLimit
        resolution: Math.max(0.1, Math.min(2, root.config.ResolutionPercent / 100))
        running: !root.paused
        pixelShift: root.config.PixelShift
    }

    // Fade out, switch the theme, fade in
    SequentialAnimation {
        id: fader
        property int target: 0
        NumberAnimation { target: scene; property: "opacity"; to: 0; duration: root.config.FadeSeconds * 500; easing.type: Easing.InOutQuad }
        ScriptAction { script: root.applyTheme(fader.target) }
        NumberAnimation { target: scene; property: "opacity"; to: 1; duration: root.config.FadeSeconds * 500; easing.type: Easing.InOutQuad }
    }

    Timer {
        interval: Math.max(5, root.config.RotateSeconds) * 1000
        repeat: true
        running: root.config.RotateSeconds > 0 && root.themes.length > 1 && !root.paused
        onTriggered: root.nextTheme()
    }

    // Battery and screen lock; a missing module only turns this off
    Loader {
        id: powerLoader
        active: root.config.BatteryMode !== "normal" || root.config.PauseWhenLocked
        source: "PowerMonitor.qml"
        onLoaded: item.watchLock = Qt.binding(function () { return root.config.PauseWhenLocked; })
    }

    // Frame rate and resource use overlay, on a dark box so it stays readable on bright themes
    Rectangle {
        visible: root.config.ShowFps
        z: 100
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 16
        width: usageLabel.implicitWidth + 16
        height: usageLabel.implicitHeight + 8
        radius: 4
        color: "#99000000"

        Text {
            id: usageLabel
            anchors.centerIn: parent
            font.family: "monospace"
            font.pixelSize: 16
            color: "white"
            // The data stream is all this wallpaper does on the CPU; what is sent to the GPU is its picture and
            // the explosion sparks are drawn on top
            readonly property var usage: scene.stats
            text: "FPS: " + usage.fps + (root.paused ? " (paused)" : "")
                  + "\nCPU: " + usage.load.toFixed(1) + " % of a core (" + usage.ms.toFixed(2) + " ms/frame)"
                  + "\nRAM: " + Math.round(usage.mb) + " MB"
                  + "\nGPU: " + Math.round(usage.uploadMb) + " MB/s sent, " + usage.sparks + " sparks"
                  + (feed.enabled ? "\nAIR: " + usage.planes + " aircraft, " + usage.planeMs.toFixed(1) + " ms per update" : "")
        }
    }

    // Why no aircraft are shown, only while aircraft are switched on and the service is in use
    Rectangle {
        readonly property string message: root.errorText(feed.error) || root.errorText(feed.lookupError)
        visible: feed.enabled && message.length > 0
        z: 99
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: 16
        width: Math.min(parent.width - 32, errorLabel.implicitWidth + 16)
        height: errorLabel.implicitHeight + 8
        radius: 4
        color: "#99000000"

        Text {
            id: errorLabel
            anchors.centerIn: parent
            width: parent.width - 16
            wrapMode: Text.WordWrap
            font.pixelSize: 14
            color: "#ffb4a8"
            text: parent.message
        }
    }

    function errorText(e) {
        if (!e) return "";
        var d = "plasma_wallpaper_de.robin.world";
        switch (e.kind) {
        case "limit": return e.minutes > 0 ? i18nd(d, "Aircraft: %1 refuses more requests for now, next try in %2 min.", e.service, e.minutes)
                                          : i18nd(d, "Aircraft: %1 refuses more requests for now.", e.service);
        case "offline": return i18nd(d, "Aircraft: %1 is not reachable. Is there an internet connection?", e.service);
        case "data": return i18nd(d, "Aircraft: %1 sent an answer that cannot be read.", e.service);
        default: return i18nd(d, "Aircraft: %1 answered with error %2.", e.service, e.status);
        }
    }

    Loader {
        id: coveredLoader
        active: root.config.PauseWhenCovered
        source: "CoveredDetector.qml"
    }
}
