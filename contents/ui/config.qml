import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "selection.js" as Selection
import "version.js" as Ver
import "store.js" as Store

ColumnLayout {
    id: page

    property string cfg_ThemeSelection
    property int cfg_ThemeRevision
    property alias cfg_RotateSeconds: rotateBox.value
    property alias cfg_RotateRandom: randomBox.checked
    property real cfg_FadeSeconds
    property alias cfg_Fps: fpsBox.value
    property alias cfg_ResolutionPercent: resolutionBox.value
    property alias cfg_PixelShift: pixelShiftBox.checked
    property alias cfg_ShowFps: showFpsBox.checked
    property string cfg_BatteryMode
    property alias cfg_BatteryFps: batteryFpsBox.value
    property alias cfg_PauseWhenLocked: lockedBox.checked
    property alias cfg_PauseWhenCovered: coveredBox.checked

    // Set by Plasma's wallpaper settings page
    property var configDialog
    property var wallpaperConfiguration
    signal configurationChanged()

    readonly property var selection: Selection.parse(cfg_ThemeSelection)
    readonly property var catalog: Store.catalog(files.ud, ThemeSettings.hideBuiltin)
    readonly property int sideMargin: Kirigami.Units.gridUnit

    // Another part of the desktop may not see the change at once (it does when the engine is shared); applying makes sure
    Connections {
        target: ThemeSettings
        function onHideBuiltinChanged() { page.cfg_ThemeRevision++; }
    }

    // The themes are the files in the theme folder
    ThemeFiles { id: files }

    QQC2.TabBar {
        id: tabs
        Layout.fillWidth: true
        Layout.leftMargin: page.sideMargin
        Layout.rightMargin: page.sideMargin
        QQC2.TabButton { text: i18nd("plasma_wallpaper_de.robin.world", "Themes") }
        QQC2.TabButton { text: i18nd("plasma_wallpaper_de.robin.world", "Performance") }
        QQC2.TabButton { text: i18nd("plasma_wallpaper_de.robin.world", "Power") }
    }

    StackLayout {
        currentIndex: tabs.currentIndex
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.leftMargin: page.sideMargin
        Layout.rightMargin: page.sideMargin

        // ---- Themes -----------------------------------------------------------------------------------
        RowLayout {
            spacing: Kirigami.Units.largeSpacing

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                Layout.preferredWidth: Kirigami.Units.gridUnit * 15
                Layout.maximumWidth: Kirigami.Units.gridUnit * 15
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Heading {
                    level: 2
                    text: i18nd("plasma_wallpaper_de.robin.world", "World %1", Ver.version)
                }

                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Manage themes…")
                    icon.name: "document-edit"
                    Layout.fillWidth: true
                    onClicked: manager.show()
                }
                QQC2.CheckBox {
                    id: hideBox
                    checked: ThemeSettings.hideBuiltin
                    onToggled: ThemeSettings.hideBuiltin = checked
                    text: i18nd("plasma_wallpaper_de.robin.world", "Disable built-in themes")
                }

                Kirigami.Separator { Layout.fillWidth: true }

                QQC2.Label { text: i18nd("plasma_wallpaper_de.robin.world", "Change the theme every:") }
                RowLayout {
                    QQC2.SpinBox {
                        id: rotateBox
                        from: 0
                        to: 86400
                        stepSize: 10
                        editable: true
                        textFromValue: function (value) { return value === 0 ? i18nd("plasma_wallpaper_de.robin.world", "Never") : i18nd("plasma_wallpaper_de.robin.world", "%1 s", value); }
                        valueFromText: function (text) { var n = parseInt(text); return isNaN(n) ? 0 : n; }
                    }
                }
                QQC2.CheckBox {
                    id: randomBox
                    text: i18nd("plasma_wallpaper_de.robin.world", "Random order")
                }
                RowLayout {
                    QQC2.Label { text: i18nd("plasma_wallpaper_de.robin.world", "Fade:") }
                    QQC2.SpinBox {
                        id: fadeBox
                        from: 0
                        to: 100
                        stepSize: 5
                        value: Math.round(page.cfg_FadeSeconds * 10)
                        onValueModified: page.cfg_FadeSeconds = value / 10
                        textFromValue: function (value) { return value === 0 ? i18nd("plasma_wallpaper_de.robin.world", "Off") : i18nd("plasma_wallpaper_de.robin.world", "%1 s", (value / 10).toFixed(1)); }
                        valueFromText: function (text) { var n = parseFloat(text); return isNaN(n) ? 0 : Math.round(n * 10); }
                    }
                }

                QQC2.Label {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Choose which collections and themes run on your desktop. Tick a whole collection or single themes from it. The ticked ones take turns. If nothing is ticked, the default theme runs.")
                    font: Kirigami.Theme.smallFont
                    opacity: 0.7
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }

            ThemeSelector {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 16
                selection: page.selection
                catalog: page.catalog
                onSelectionEdited: function (list) { page.cfg_ThemeSelection = Selection.stringify(list); }
            }
        }

        // ---- Performance ------------------------------------------------------------------------------
        Kirigami.FormLayout {
            QQC2.SpinBox {
                id: fpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Maximum frame rate:")
                from: 0
                to: 1000
                stepSize: 10
                editable: true
                textFromValue: function (value) { return value === 0 ? i18nd("plasma_wallpaper_de.robin.world", "Screen refresh rate") : i18nd("plasma_wallpaper_de.robin.world", "%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 0; }
            }
            QQC2.Label {
                text: i18nd("plasma_wallpaper_de.robin.world", "Lower values save power. The map itself is drawn only once, only the data stream is animated.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.SpinBox {
                id: resolutionBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Resolution:")
                from: 10
                to: 200
                stepSize: 5
                editable: true
                textFromValue: function (value) { return value + " %"; }
                valueFromText: function (text) { return Math.max(10, Math.min(200, parseInt(text) || 100)); }
            }
            QQC2.Label {
                text: i18nd("plasma_wallpaper_de.robin.world", "Share of the screen size the picture is calculated at. Lower values use less memory and power but look coarser.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.CheckBox {
                id: pixelShiftBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Burn-in protection:")
                text: i18nd("plasma_wallpaper_de.robin.world", "Move the picture a few pixels now and then")
            }
            QQC2.Label {
                text: i18nd("plasma_wallpaper_de.robin.world", "For OLED screens: once a minute the whole picture shifts by up to 6 pixels, so no line stays on the same pixels for months.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }

            QQC2.CheckBox {
                id: showFpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Overlay:")
                text: i18nd("plasma_wallpaper_de.robin.world", "Show frame rate and resource use")
            }
            QQC2.Label {
                text: i18nd("plasma_wallpaper_de.robin.world", "Shows frames per second and what this wallpaper costs: CPU time of the data stream, memory for the picture, and the data sent to the GPU per second.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }
        }

        // ---- Power ------------------------------------------------------------------------------------
        Kirigami.FormLayout {
            QQC2.ComboBox {
                id: batteryModeBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "On battery:")
                textRole: "text"
                valueRole: "value"
                model: [
                    { text: i18nd("plasma_wallpaper_de.robin.world", "Keep running normally"), value: "normal" },
                    { text: i18nd("plasma_wallpaper_de.robin.world", "Limit the frame rate"), value: "limit" },
                    { text: i18nd("plasma_wallpaper_de.robin.world", "Pause"), value: "pause" }
                ]
                function sync() { currentIndex = Math.max(0, indexOfValue(page.cfg_BatteryMode)); }
                Component.onCompleted: sync()
                Connections {
                    target: page
                    function onCfg_BatteryModeChanged() { batteryModeBox.sync(); }
                }
                onActivated: page.cfg_BatteryMode = currentValue
            }
            QQC2.SpinBox {
                id: batteryFpsBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Battery frame rate:")
                enabled: page.cfg_BatteryMode === "limit"
                from: 1
                to: 240
                stepSize: 5
                editable: true
                textFromValue: function (value) { return i18nd("plasma_wallpaper_de.robin.world", "%1 FPS", value); }
                valueFromText: function (text) { return parseInt(text) || 15; }
            }
            QQC2.CheckBox {
                id: lockedBox
                Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Pause while:")
                text: i18nd("plasma_wallpaper_de.robin.world", "the screen is locked")
            }
            QQC2.CheckBox {
                id: coveredBox
                text: i18nd("plasma_wallpaper_de.robin.world", "a maximized or fullscreen window covers the desktop")
            }
            QQC2.Label {
                text: i18nd("plasma_wallpaper_de.robin.world", "Pausing keeps the picture as it is and costs no power. Drawing continues where it stopped.")
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
                Layout.maximumWidth: Kirigami.Units.gridUnit * 26
            }
        }
    }

    QQC2.Button {
        Layout.leftMargin: page.sideMargin
        Layout.bottomMargin: Kirigami.Units.smallSpacing
        icon.name: "edit-undo"
        text: i18nd("plasma_wallpaper_de.robin.world", "Restore defaults")
        onClicked: {
            page.cfg_ThemeSelection = "[]";
            ThemeSettings.hideBuiltin = false;
            page.cfg_RotateSeconds = 60;
            page.cfg_RotateRandom = true;
            page.cfg_FadeSeconds = 1.5;
            page.cfg_Fps = 30;
            page.cfg_ResolutionPercent = 100;
            page.cfg_PixelShift = true;
            page.cfg_ShowFps = false;
            page.cfg_BatteryMode = "limit";
            page.cfg_BatteryFps = 15;
            page.cfg_PauseWhenLocked = true;
            page.cfg_PauseWhenCovered = true;
        }
        QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Your own themes are kept")
        QQC2.ToolTip.visible: hovered
    }

    ThemeManager {
        id: manager
        onSaved: { page.cfg_ThemeRevision++; files.reload(); }
        onThemeKeyChanged: function (oldKey, newKey) {
            var list = page.selection.map(function (e) { return e === "t:" + oldKey ? (newKey === "" ? "" : "t:" + newKey) : e; })
                           .filter(function (e) { return e !== ""; });
            if (JSON.stringify(list) !== JSON.stringify(page.selection)) page.cfg_ThemeSelection = Selection.stringify(list);
        }
        onCollectionRemoved: function (path) {
            var list = page.selection.filter(function (e) {
                return !(e.indexOf("c:") === 0 && (e.substring(2) === path || e.substring(2).indexOf(path + "/") === 0))
                       && !(e.indexOf("t:") === 0 && e.substring(2).indexOf(path + "/") === 0);
            });
            if (list.length !== page.selection.length) page.cfg_ThemeSelection = Selection.stringify(list);
        }
    }
}
