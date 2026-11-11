import QtQuick
import QtQuick.Window
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

import "assistant.js" as Generator
import "params.js" as Params
import "store.js" as Store

// Asks for the basics (background, colors, ...) and rolls the rest. Shows a live preview of the current roll
// and creates one or many themes in a collection.
Window {
    id: assistant

    title: i18nd("plasma_wallpaper_de.robin.world", "Theme assistant")
    width: Kirigami.Units.gridUnit * 52
    height: Kirigami.Units.gridUnit * 38
    minimumWidth: Kirigami.Units.gridUnit * 40
    minimumHeight: Kirigami.Units.gridUnit * 30
    color: Kirigami.Theme.backgroundColor

    // The user data of the theme manager: where themes can go and what a collection hands down
    property var ud: Store.empty()
    // Themes to create: the collection, the values of each theme and the name they start with
    signal create(string collection, var themes, string baseName)

    property var generated: ({})
    property string customBackground: "#1e1e3c"

    function options() {
        return {
            bg: backgroundBox.currentValue,
            customBg: assistant.customBackground,
            palette: paletteBox.currentValue,
            colors: colorCountBox.value,
            rainbow: rainbowBox.checked,
            borders: bordersBox.currentValue,
            view: viewBox.currentValue,
            density: densityBox.currentValue,
            speed: speedBox.currentValue,
            explosions: explosionsBox.currentValue,
            variation: variationSlider.value,
            accentHue: Math.max(0, Kirigami.Theme.highlightColor.hslHue) * 360
        };
    }

    function roll() { generated = Generator.generate(options()); }

    // Existing collections that take new themes
    readonly property var existing: {
        var list = Store.catalog(ud, false).collections.filter(function (c) { return !Store.isBuiltinCollection(c); });
        if (list.indexOf("My themes") < 0) list.unshift("My themes");
        return list;
    }
    // The choices of the collection popup: a new one first, then the existing ones
    readonly property var targets: [{ text: i18nd("plasma_wallpaper_de.robin.world", "New collection…"), value: "" }].concat(
        existing.map(function (c) { return { text: c, value: c }; }))
    // New collections can go inside an existing one (and inherit its defaults)
    readonly property var parents: [{ text: i18nd("plasma_wallpaper_de.robin.world", "(top level)"), value: "" }].concat(
        existing.map(function (c) { return { text: c, value: c }; }))

    readonly property bool makeCollection: targetBox.currentValue === ""
    readonly property string newCollectionPath: {
        var name = collectionField.text.trim();
        var parent = parentBox.currentValue || "";
        return parent ? parent + "/" + name : name;
    }
    readonly property string collectionPath: makeCollection ? newCollectionPath : targetBox.currentValue
    readonly property bool canCreate: makeCollection
        ? Store.validName(collectionField.text.trim()) && Store.catalog(ud, false).collections.indexOf(newCollectionPath) < 0
          && !Store.isBuiltinCollection(newCollectionPath)
        : collectionPath !== ""

    // What the preview looks like in the chosen collection: its defaults under the rolled settings
    readonly property var previewConfig: Object.assign({}, Params.defaults(),
        Store.effective(ud, makeCollection ? (parentBox.currentValue || "") : collectionPath, {}), generated)

    function start(collection) {
        var i = existing.indexOf(collection);
        targetBox.currentIndex = i >= 0 ? i + 1 : 0;
        parentBox.currentIndex = 0;
        collectionField.text = i18nd("plasma_wallpaper_de.robin.world", "Generated");
        nameField.text = i18nd("plasma_wallpaper_de.robin.world", "Generated");
        roll();
        show();
        raise();
        requestActivate();
    }

    function doCreate() {
        if (!canCreate) return;
        var list = [generated];
        for (var i = 1; i < countBox.value; i++) list.push(Generator.generate(options()));
        create(collectionPath, list, nameField.text.trim() || i18nd("plasma_wallpaper_de.robin.world", "Generated"));
        close();
    }

    // Rolling again after every change would be wasteful while a slider moves
    Timer { id: rollSoon; interval: 250; onTriggered: assistant.roll() }

    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ---- questions -----------------------------------------------------------------------------------
        QQC2.ScrollView {
            id: scroll
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 24
            contentWidth: availableWidth

            Kirigami.FormLayout {
                width: scroll.availableWidth

                QQC2.ComboBox {
                    id: backgroundBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Background:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Black"), value: "black" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "White"), value: "white" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Dark tone"), value: "dark" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Light tone"), value: "light" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Own color"), value: "custom" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    onActivated: rollSoon.restart()
                }
                QQC2.Button {
                    visible: backgroundBox.currentValue === "custom"
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Background color:")
                    onClicked: { backgroundDialog.selectedColor = assistant.customBackground; backgroundDialog.open(); }
                    contentItem: RowLayout {
                        Rectangle {
                            implicitWidth: Kirigami.Units.iconSizes.medium
                            implicitHeight: Kirigami.Units.iconSizes.small
                            radius: 3
                            color: assistant.customBackground
                            border.color: Kirigami.Theme.textColor
                        }
                        QQC2.Label { text: i18nd("plasma_wallpaper_de.robin.world", "Choose…") }
                    }
                }

                QQC2.ComboBox {
                    id: paletteBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Colors:")
                    enabled: !rainbowBox.checked
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Random mix"), value: "random" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Neighbouring hues"), value: "analogous" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Complementary"), value: "complementary" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Triad"), value: "triadic" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "One hue, many shades"), value: "monochrome" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Warm"), value: "warm" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Cool"), value: "cool" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Pastel"), value: "pastel" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Neon"), value: "neon" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Around the Plasma accent color"), value: "accent" }]
                    onActivated: rollSoon.restart()
                }
                QQC2.SpinBox {
                    id: colorCountBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Number of colors:")
                    enabled: !rainbowBox.checked
                    from: 1; to: 8; value: 2
                    editable: true
                    onValueModified: rollSoon.restart()
                }
                QQC2.CheckBox {
                    id: rainbowBox
                    text: i18nd("plasma_wallpaper_de.robin.world", "Rainbow lines")
                    onToggled: rollSoon.restart()
                }

                QQC2.ComboBox {
                    id: bordersBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Country borders:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Off"), value: "off" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Subtle"), value: "subtle" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Normal"), value: "normal" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Strong"), value: "strong" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    currentIndex: 4
                    onActivated: rollSoon.restart()
                }
                QQC2.ComboBox {
                    id: viewBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "View:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Automatic tilt"), value: "auto" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Flat"), value: "flat" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    onActivated: rollSoon.restart()
                }
                QQC2.ComboBox {
                    id: densityBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Data density:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Few"), value: "few" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Normal"), value: "normal" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Many"), value: "many" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    currentIndex: 3
                    onActivated: rollSoon.restart()
                }
                QQC2.ComboBox {
                    id: speedBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Speed:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Slow"), value: "slow" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Normal"), value: "normal" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Fast"), value: "fast" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    currentIndex: 3
                    onActivated: rollSoon.restart()
                }
                QQC2.ComboBox {
                    id: explosionsBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Explosions:")
                    textRole: "text"; valueRole: "value"
                    model: [{ text: i18nd("plasma_wallpaper_de.robin.world", "Off"), value: "off" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Rare"), value: "rare" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Often"), value: "often" },
                            { text: i18nd("plasma_wallpaper_de.robin.world", "Random"), value: "random" }]
                    currentIndex: 3
                    onActivated: rollSoon.restart()
                }

                ColumnLayout {
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Randomness:")
                    Layout.fillWidth: true
                    QQC2.Slider {
                        id: variationSlider
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 5; value: 40
                        onMoved: rollSoon.restart()
                    }
                    QQC2.Label {
                        Layout.fillWidth: true
                        text: i18nd("plasma_wallpaper_de.robin.world", "How far density, speed and explosions may wander from their typical values: %1 %", variationSlider.value)
                        font: Kirigami.Theme.smallFont
                        opacity: 0.7
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ---- preview and creation --------------------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 10
                color: "black"
                clip: true

                WorldScene {
                    anchors.fill: parent
                    running: assistant.visible
                    p: assistant.previewConfig
                    fps: 30
                    aircraftDemo: true
                }

                QQC2.Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    text: i18nd("plasma_wallpaper_de.robin.world", "Preview")
                    color: Params.luminance(Params.toRgb(assistant.previewConfig.BgColor)) > 0.5 ? "black" : "white"
                    opacity: 0.6
                }
            }

            QQC2.Button {
                Layout.alignment: Qt.AlignHCenter
                text: i18nd("plasma_wallpaper_de.robin.world", "Roll again")
                icon.name: "roll"
                onClicked: assistant.roll()
            }

            Kirigami.FormLayout {
                Layout.fillWidth: true

                QQC2.ComboBox {
                    id: targetBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Collection:")
                    textRole: "text"
                    valueRole: "value"
                    model: assistant.targets
                }

                QQC2.TextField {
                    id: collectionField
                    visible: assistant.makeCollection
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Collection name:")
                    text: i18nd("plasma_wallpaper_de.robin.world", "Generated")
                    color: assistant.canCreate ? Kirigami.Theme.textColor : Kirigami.Theme.negativeTextColor
                }

                QQC2.ComboBox {
                    id: parentBox
                    visible: assistant.makeCollection
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "Inside:")
                    textRole: "text"
                    valueRole: "value"
                    model: assistant.parents
                }

                QQC2.TextField {
                    id: nameField
                    Kirigami.FormData.label: countBox.value > 1 ? i18nd("plasma_wallpaper_de.robin.world", "Theme name:") : i18nd("plasma_wallpaper_de.robin.world", "Name:")
                    text: i18nd("plasma_wallpaper_de.robin.world", "Generated")
                }

                QQC2.SpinBox {
                    id: countBox
                    Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", "How many:")
                    from: 1
                    to: 30
                    value: 1
                    editable: true
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                text: (countBox.value > 1
                       ? i18nd("plasma_wallpaper_de.robin.world", "The preview becomes the first theme, the others are rolled with the same answers. ")
                       : "") + (assistant.makeCollection
                       ? i18nd("plasma_wallpaper_de.robin.world", "The collection is created first; the themes inherit what the assistant does not set from the collection they are inside.")
                       : i18nd("plasma_wallpaper_de.robin.world", "The themes inherit everything this assistant does not set from their collection."))
                font: Kirigami.Theme.smallFont
                opacity: 0.7
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true

                Item { Layout.fillWidth: true }
                QQC2.Button {
                    text: countBox.value > 1 ? i18nd("plasma_wallpaper_de.robin.world", "Create %1 themes", countBox.value) : i18nd("plasma_wallpaper_de.robin.world", "Create theme")
                    icon.name: "list-add"
                    enabled: assistant.canCreate
                    onClicked: assistant.doCreate()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Cancel")
                    icon.name: "dialog-cancel"
                    onClicked: assistant.close()
                }
            }
        }
    }

    ColorDialog {
        id: backgroundDialog
        onAccepted: { assistant.customBackground = String(selectedColor).substring(0, 7); rollSoon.restart(); }
    }
}
