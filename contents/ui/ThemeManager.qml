import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs
import org.kde.kirigami as Kirigami

import "params.js" as Params
import "store.js" as Store
import "tree.js" as Tree
import "persist.js" as Persist

// Window to browse, edit, create, duplicate and delete themes and theme collections.
//
// A collection holds default values for all themes in it and in its subcollections. A theme only stores the
// values it changes, everything else is inherited. Click a collection to edit its defaults.
QQC2.ApplicationWindow {
    id: win

    title: i18nd("plasma_wallpaper_de.robin.world", "World themes")
    width: Kirigami.Units.gridUnit * 64
    height: Kirigami.Units.gridUnit * 44
    minimumWidth: Kirigami.Units.gridUnit * 44
    minimumHeight: Kirigami.Units.gridUnit * 28
    color: Kirigami.Theme.backgroundColor

    // What is in the theme folder; the theme being edited is a draft until it is saved
    ThemeFiles { id: files; onCommitted: win.saved() }
    signal saved()
    readonly property var ud: files.ud
    property bool dirty: false
    property var draftOwn: ({})          // the values the selected theme or collection sets itself
    property string draftName: ""

    property string kind: "theme"        // what is edited: "theme" or the defaults of a "collection"
    property string selected: ""         // key of the theme, path of the collection
    property var pending: null           // selection waiting for the "discard changes?" answer
    property var collapsed: ({})
    property string viewRoot: ""         // the collection the list shows ("" = all of them)
    property string target: ""           // for the dialogs: the theme or collection they act on
    property string notice: ""

    // A theme changed its key (newKey is empty when it was deleted), so the selection can follow it
    signal themeKeyChanged(string oldKey, string newKey)
    signal collectionRemoved(string path)

    readonly property string ownCollection: "My themes"   // a name, not translated: it is part of the keys
    readonly property var catalog: Store.catalog(ud, ThemeSettings.hideBuiltin)
    readonly property bool readOnly: kind === "theme" ? Store.isBuiltinTheme(selected) : Store.isBuiltinCollection(selected)
    // The theme or collection as it looks with the draft: everything it inherits plus its own values
    readonly property var effectiveP: {
        if (readOnly || !dirty) {
            if (kind === "theme") {
                for (var i = 0; i < catalog.themes.length; i++) if (catalog.themes[i].key === selected) return catalog.themes[i].config;
                return Params.defaults();
            }
            return Store.effective(ud, selected, {});
        }
        if (kind === "theme") return Store.effective(ud, Tree.collectionOf(selected), draftOwn);
        var withDraft = Store.clone(ud);
        withDraft.collections[selected] = draftOwn;
        return Store.effective(withDraft, selected, {});
    }
    readonly property var rows: Tree.rows(catalog.collections, catalog.themes, collapsed, function (t, depth) {
        return { type: "theme", key: t.key, collection: t.collection, title: t.name, depth: depth, builtin: t.builtin, config: t.config };
    }, viewRoot)

    // Entries of the list filter: every collection, indented by its depth
    readonly property var viewChoices: {
        var list = [{ path: "", text: i18nd("plasma_wallpaper_de.robin.world", "All collections"), depth: 0 }];
        catalog.collections.forEach(function (c) { list.push({ path: c, text: Tree.labelOf(c), depth: Tree.depthOf(c) + 1 }); });
        return list;
    }

    Component.onCompleted: {
        var c = {};
        Persist.getList("managerFolds").forEach(function (name) { c[name] = true; });
        collapsed = c;
        viewRoot = Persist.get("managerView", "");
    }

    function show() {
        files.reload(function () {
            var t = catalog.themes;
            if (t.length > 0) open("theme", t[0].key);
            else open("collection", catalog.collections.length > 0 ? catalog.collections[0] : "");
        });
        visible = true;
        raise();
        requestActivate();
    }

    // Loads a theme or collection into the editor
    function open(k, id) {
        kind = k;
        selected = id;
        notice = "";
        draftOwn = JSON.parse(JSON.stringify(k === "theme" ? Store.ownThemeValues(ud, id) : Store.ownCollectionValues(ud, id)));
        draftName = k === "theme" ? id.substring(Tree.collectionOf(id).length + 1) : "";
        dirty = false;
    }

    // Selecting something else while there are unsaved changes asks first
    function select(k, id) {
        if (k === kind && id === selected && !dirty) return;
        if (dirty) { pending = { kind: k, id: id }; discardDialog.open(); return; }
        open(k, id);
    }

    // The folder changed on disk (or an own write came back): keep what is shown up to date
    Connections {
        target: files
        function onUdChanged() {
            if (win.dirty || !win.visible) return;
            if (win.kind === "theme" ? win.themeByKey(win.selected) : win.catalog.collections.indexOf(win.selected) >= 0) win.open(win.kind, win.selected);
        }
    }

    // Structure changes (create, delete, move, copy) are written to the theme folder at once
    function change(newUd) { files.commit(newUd); }

    function toggleFold(path) {
        var c = Object.assign({}, collapsed);
        c[path] = !c[path];
        collapsed = c;
        Persist.setList("managerFolds", Object.keys(c).filter(function (k) { return c[k]; }));
    }
    function setViewRoot(path) {
        viewRoot = path;
        Persist.set("managerView", path);
    }

    // Move a theme into another collection (drag and drop)
    function moveThemeTo(key, collection) {
        var t = themeByKey(key);
        if (!t || t.builtin || Store.isBuiltinCollection(collection) || t.collection === collection) return;
        var newKey = collection + "/" + key.substring(t.collection.length + 1);
        if (themeByKey(newKey)) { notice = i18nd("plasma_wallpaper_de.robin.world", "There is already a theme with this name in that collection."); return; }
        change(Store.moveTheme(ud, key, collection));
        themeKeyChanged(key, newKey);
        if (selected === key) open("theme", newKey);
    }

    function importFromFolder() {
        files.reload(function () { win.notice = i18nd("plasma_wallpaper_de.robin.world", "Read the theme folder again."); });
    }

    function openThemeFolder() {
        var path = kind === "collection" ? selected : Tree.collectionOf(selected);
        files.openFolder(Store.isBuiltinCollection(path) ? "" : path);
    }

    // ---- the draft of the selected theme or collection ----
    function setValue(key, value) {
        if (readOnly) return;
        var d = Object.assign({}, draftOwn);
        d[key] = value;
        draftOwn = d;
        dirty = true;
    }
    function resetValue(key) {
        if (readOnly) return;
        var d = Object.assign({}, draftOwn);
        delete d[key];
        draftOwn = d;
        dirty = true;
    }
    function inheritAll() {
        if (readOnly) return;
        draftOwn = ({});
        dirty = true;
    }
    function isOwn(key) { return !readOnly && dirty ? draftOwn.hasOwnProperty(key) : sourceOfSaved(key) === "own"; }
    function sourceOfSaved(key) { return Store.source(ud, kind, selected, key); }
    function sourceOf(key) {
        if (readOnly || !dirty) return sourceOfSaved(key);
        if (draftOwn.hasOwnProperty(key)) return "own";
        for (var p = kind === "theme" ? Tree.collectionOf(selected) : Tree.parentOf(selected); p !== ""; p = Tree.parentOf(p))
            if (Store.ownCollectionValues(ud, p).hasOwnProperty(key)) return p;
        return "";
    }
    function sourceText(key) {
        var src = sourceOf(key);
        if (src === "own") return kind === "collection" ? i18nd("plasma_wallpaper_de.robin.world", "set here") : i18nd("plasma_wallpaper_de.robin.world", "changed");
        return src === "" ? i18nd("plasma_wallpaper_de.robin.world", "default") : i18nd("plasma_wallpaper_de.robin.world", "from \"%1\"", Tree.labelOf(src));
    }
    // The theme or collection sets values of its own
    readonly property bool hasOwn: Object.keys(draftOwn).length > 0
    readonly property string currentCollection: kind === "collection" ? selected : Tree.collectionOf(selected)
    readonly property string folderPath: "~/.local/share/world-wallpaper/themes/"
    property bool newInside: false

    function themeByKey(key) {
        for (var i = 0; i < catalog.themes.length; i++) if (catalog.themes[i].key === key) return catalog.themes[i];
        return null;
    }
    function creatableCollection(path) { return path !== "" && !Store.isBuiltinCollection(path); }

    function newTheme(collection) {
        var coll = creatableCollection(collection) ? collection : ownCollection;
        var name = Store.uniqueName(ud, coll, i18nd("plasma_wallpaper_de.robin.world", "New theme"));
        change(Store.addTheme(ud, coll, name, {}));
        open("theme", coll + "/" + name);
    }

    function duplicateTheme(key) {
        var t = themeByKey(key);
        if (!t) return;
        var coll = creatableCollection(t.collection) ? t.collection : ownCollection;
        var name = Store.uniqueName(ud, coll, t.name + " " + i18nd("plasma_wallpaper_de.robin.world", "copy"));
        // Into another collection the copy carries all its values, so it looks the same there
        change(Store.addTheme(ud, coll, name, coll === t.collection ? t.own : t.config));
        open("theme", coll + "/" + name);
    }

    function validPath(path) {
        return path.length > 0 && path.charAt(0) !== "/" && path.charAt(path.length - 1) !== "/" && path.indexOf("//") < 0;
    }

    function createCollection(path) {
        if (!validPath(path) || catalog.collections.indexOf(path) >= 0 || Store.isBuiltinCollection(Tree.parentOf(path))) {
            notice = i18nd("plasma_wallpaper_de.robin.world", "This collection name is not possible.");
            return;
        }
        change(Store.addCollection(ud, path));
        open("collection", path);
    }

    function copyCollection(from, to) {
        if (!validPath(to) || catalog.collections.indexOf(to) >= 0 || Store.isBuiltinCollection(Tree.parentOf(to))) {
            notice = i18nd("plasma_wallpaper_de.robin.world", "This collection name is not possible.");
            return;
        }
        change(Store.duplicateCollection(ud, from, to));
        open("collection", to);
    }

    function afterDelete() {
        var t = catalog.themes;
        if (t.length > 0) open("theme", t[0].key); else open("collection", "");
    }

    // Saving writes the selected theme or collection to its file at once
    function doSave() {
        if (readOnly || !dirty) return;
        var u = Store.clone(ud);
        if (kind === "theme") {
            var name = draftName.trim();
            var key = Tree.collectionOf(selected) + "/" + name;
            if (!Store.validName(name) || (key !== selected && themeByKey(key))) { notice = i18nd("plasma_wallpaper_de.robin.world", "This theme name is not possible."); return; }
            if (key !== selected) { delete u.themes[selected]; themeKeyChanged(selected, key); }
            u.themes[key] = Params.sanitize(draftOwn);
            files.commit(u);
            open("theme", key);
        } else {
            u.collections[selected] = Params.sanitize(draftOwn);
            files.commit(u);
            open("collection", selected);
        }
    }

    function doRevert() { open(kind, selected); }

    onClosing: function (close) {
        if (dirty) {
            close.accepted = false;
            unsavedDialog.open();
        }
    }

    // ---- Layout -------------------------------------------------------------------------------------------
    RowLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing

        // ---- Left: the themes -----------------------------------------------------------------------------
        ColumnLayout {
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            Layout.fillHeight: true

            // Which collection the list below shows
            QQC2.ComboBox {
                id: viewBox
                Layout.fillWidth: true
                model: win.viewChoices
                textRole: "text"
                displayText: win.viewRoot ? win.viewRoot : i18nd("plasma_wallpaper_de.robin.world", "All collections")
                currentIndex: {
                    for (var i = 0; i < win.viewChoices.length; i++)
                        if (win.viewChoices[i].path === win.viewRoot) return i;
                    return 0;
                }
                onActivated: function (index) { win.setViewRoot(win.viewChoices[index].path); }
                delegate: QQC2.ItemDelegate {
                    width: viewBox.width
                    text: modelData.text
                    leftPadding: Kirigami.Units.largeSpacing + modelData.depth * Kirigami.Units.gridUnit
                    highlighted: viewBox.highlightedIndex === index
                    font.bold: modelData.depth <= 1
                }
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true

                ListView {
                    id: list
                    clip: true
                    model: win.rows
                    delegate: QQC2.ItemDelegate {
                        id: row
                        readonly property bool isHeader: modelData.type === "header"
                        readonly property string collectionName: isHeader ? modelData.name : modelData.collection
                        width: ListView.view.width
                        highlighted: isHeader ? (win.kind === "collection" && win.selected === modelData.name)
                                              : (win.kind === "theme" && win.selected === modelData.key)
                        leftPadding: Kirigami.Units.smallSpacing + modelData.depth * Kirigami.Units.gridUnit
                        onClicked: {
                            if (isHeader) win.select("collection", modelData.name);
                            else win.select("theme", modelData.key);
                        }
                        onDoubleClicked: if (isHeader) win.toggleFold(modelData.name)

                        // Right click: actions for this entry, selected or not
                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            onTapped: {
                                contextMenu.row = modelData;
                                contextMenu.popup();
                            }
                        }

                        // Drag a theme onto a collection (or a theme in it) to move it there
                        Drag.dragType: Drag.Automatic
                        Drag.supportedActions: Qt.MoveAction
                        Drag.proposedAction: Qt.MoveAction
                        Drag.mimeData: isHeader ? ({}) : ({ "application/x-world-theme": modelData.key })
                        DragHandler {
                            enabled: !row.isHeader && !modelData.builtin
                            target: null
                            onActiveChanged: {
                                if (active) row.grabToImage(function (r) { row.Drag.imageSource = r.url; });
                                row.Drag.active = active;
                            }
                        }
                        DropArea {
                            id: dropArea
                            anchors.fill: parent
                            onEntered: function (drag) {
                                drag.accepted = !Store.isBuiltinCollection(row.collectionName)
                                                && drag.formats.indexOf("application/x-world-theme") >= 0;
                            }
                            onDropped: function (drop) {
                                win.moveThemeTo(drop.getDataAsString("application/x-world-theme"), row.collectionName);
                                drop.accept(Qt.MoveAction);
                            }
                        }
                        background: Rectangle {
                            color: dropArea.containsDrag ? Qt.alpha(Kirigami.Theme.highlightColor, 0.35)
                                 : row.highlighted ? Kirigami.Theme.highlightColor
                                 : row.hovered ? Qt.alpha(Kirigami.Theme.highlightColor, 0.15) : "transparent"
                        }
                        contentItem: RowLayout {
                            Kirigami.Icon {
                                visible: row.isHeader
                                source: win.collapsed[modelData.name] ? "arrow-right" : "arrow-down"
                                implicitWidth: Kirigami.Units.iconSizes.small
                                implicitHeight: implicitWidth

                                // A click on the arrow folds the collection
                                TapHandler {
                                    acceptedButtons: Qt.LeftButton
                                    onTapped: win.toggleFold(modelData.name)
                                }
                            }
                            Rectangle {
                                visible: !row.isHeader
                                width: Kirigami.Units.iconSizes.small
                                height: width
                                radius: 3
                                color: row.isHeader ? "transparent" : modelData.config.BgColor
                                border.color: Kirigami.Theme.disabledTextColor
                                Row {
                                    anchors.centerIn: parent
                                    Repeater {
                                        model: row.isHeader ? [] : (modelData.config.Rainbow ? ["#ff4040", "#40ff60", "#4060ff"]
                                                                                               : modelData.config.AccentColor ? [String(Kirigami.Theme.highlightColor)]
                                                                                               : modelData.config.LineColors.slice(0, 3))
                                        Rectangle { width: 3; height: 8; color: modelData }
                                    }
                                }
                            }
                            QQC2.Label {
                                text: row.isHeader ? modelData.label : modelData.title
                                font.bold: row.isHeader
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            QQC2.Label {
                                text: row.isHeader ? modelData.count : (modelData.builtin ? i18nd("plasma_wallpaper_de.robin.world", "built-in") : i18nd("plasma_wallpaper_de.robin.world", "own"))
                                font: Kirigami.Theme.smallFont
                                opacity: 0.6
                            }
                        }
                    }
                }
            }

            GridLayout {
                columns: 2
                Layout.fillWidth: true
                QQC2.Button {
                    Layout.fillWidth: true
                    icon.name: "list-add"
                    text: i18nd("plasma_wallpaper_de.robin.world", "New theme")
                    onClicked: win.newTheme(win.kind === "collection" ? win.selected : Tree.collectionOf(win.selected))
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    icon.name: "folder-new"
                    text: i18nd("plasma_wallpaper_de.robin.world", "New collection…")
                    onClicked: { win.newInside = false; newCollectionDialog.open(); }
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    icon.name: win.kind === "collection" ? "folder-copy" : "edit-copy"
                    text: i18nd("plasma_wallpaper_de.robin.world", "Duplicate")
                    enabled: win.selected !== ""
                    onClicked: {
                        if (win.kind === "theme") win.duplicateTheme(win.selected);
                        else { win.target = win.selected; copyCollectionField.text = win.selected + " " + i18nd("plasma_wallpaper_de.robin.world", "copy"); copyCollectionDialog.open(); }
                    }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: win.kind === "collection" ? i18nd("plasma_wallpaper_de.robin.world", "Copy the whole collection") : i18nd("plasma_wallpaper_de.robin.world", "Copy the selected theme")
                }
                QQC2.Button {
                    Layout.fillWidth: true
                    icon.name: win.kind === "collection" ? "folder-remove" : "edit-delete"
                    text: i18nd("plasma_wallpaper_de.robin.world", "Delete")
                    enabled: !win.readOnly && win.selected !== ""
                    onClicked: { win.target = win.selected; (win.kind === "theme" ? deleteThemeDialog : deleteCollectionDialog).open(); }
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: win.kind === "collection" ? i18nd("plasma_wallpaper_de.robin.world", "Delete the collection with your own themes and subcollections in it")
                                                                  : i18nd("plasma_wallpaper_de.robin.world", "Delete the selected theme")
                }
                QQC2.Button {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    icon.name: "tools-wizard"
                    text: i18nd("plasma_wallpaper_de.robin.world", "Assistant…")
                    onClicked: assistantDialog.start(win.kind === "collection" ? win.selected : Tree.collectionOf(win.selected))
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Answer a few questions and let the rest be rolled")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.Button {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    icon.name: "folder-open"
                    text: i18nd("plasma_wallpaper_de.robin.world", "Open theme folder")
                    onClicked: win.openThemeFolder()
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Your themes are the files in this folder. Edit or share them, then use \"Reload from theme folder\" here; the desktop takes them over when you apply the settings.")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.Button {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    icon.name: "view-refresh"
                    text: i18nd("plasma_wallpaper_de.robin.world", "Reload from theme folder")
                    onClicked: win.importFromFolder()
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Reads the theme folder again, for example after you edited or added files")
                    QQC2.ToolTip.visible: hovered
                }
                QQC2.CheckBox {
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    text: i18nd("plasma_wallpaper_de.robin.world", "Disable built-in themes")
                    checked: ThemeSettings.hideBuiltin
                    onToggled: ThemeSettings.hideBuiltin = checked
                }
            }
        }

        Kirigami.Separator { Layout.fillHeight: true }

        // ---- Right: the editor -----------------------------------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Information
                text: win.notice
                visible: text.length > 0
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Kirigami.Units.gridUnit * 14
                color: "black"
                clip: true

                WorldScene {
                    anchors.fill: parent
                    // Only runs while the window is shown
                    running: win.visible
                    p: win.effectiveP
                    fps: 30
                    aircraftDemo: true
                }

                QQC2.Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: Kirigami.Units.smallSpacing
                    text: i18nd("plasma_wallpaper_de.robin.world", "Preview")
                    color: Params.luminance(Params.toRgb(win.effectiveP.BgColor)) > 0.5 ? "black" : "white"
                    opacity: 0.6
                }
            }

            // Theme: its name. Collection: what its defaults are for.
            GridLayout {
                columns: 3
                Layout.fillWidth: true
                visible: win.kind === "theme"

                QQC2.Label { text: i18nd("plasma_wallpaper_de.robin.world", "Name:") }
                QQC2.TextField {
                    id: nameField
                    Layout.fillWidth: true
                    enabled: !win.readOnly
                    text: win.draftName
                    onTextEdited: { win.draftName = text; win.dirty = true; }
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Inherit everything")
                    icon.name: "edit-clear-all"
                    enabled: !win.readOnly && win.hasOwn
                    onClicked: win.inheritAll()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Remove all own values, the theme then looks like its collection")
                }
            }

            RowLayout {
                Layout.fillWidth: true
                visible: win.kind === "collection"

                Kirigami.Heading {
                    level: 3
                    text: i18nd("plasma_wallpaper_de.robin.world", "Defaults of \"%1\"", win.selected)
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Clear defaults")
                    icon.name: "edit-clear-all"
                    visible: !win.readOnly && win.hasOwn
                    onClicked: win.inheritAll()
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Remove all defaults of this collection")
                }
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: win.kind === "collection"
                text: win.readOnly
                      ? i18nd("plasma_wallpaper_de.robin.world", "The defaults of a built-in collection cannot be changed. Use \"Duplicate collection…\" to make an own copy.")
                      : i18nd("plasma_wallpaper_de.robin.world", "These values apply to every theme in this collection and its subcollections, unless a theme sets its own.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: win.kind === "theme" && win.readOnly
                text: i18nd("plasma_wallpaper_de.robin.world", "Built-in themes are not changed. Use \"Duplicate\" to make an editable copy.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

            QQC2.Label {
                Layout.fillWidth: true
                visible: win.kind === "theme"
                text: i18nd("plasma_wallpaper_de.robin.world", "Values marked \"from …\" or \"default\" are inherited. Change one to give this theme its own value; the arrow takes it back.")
                wrapMode: Text.WordWrap
                font: Kirigami.Theme.smallFont
                opacity: 0.7
            }

    // Asks each service once, with a request that costs next to nothing
                    QtObject {
                id: tester
                property bool busy: false
                property var results: []
                readonly property bool allOk: results.length > 0 && results.every(function (r) { return r.ok; })
                readonly property string text: results.map(function (r) {
                    return (r.ok ? "✓ " : "✗ ") + r.name + (r.ok ? "" : " (" + (r.status === 0 ? i18nd("plasma_wallpaper_de.robin.world","not reachable") : i18nd("plasma_wallpaper_de.robin.world","error %1", r.status)) + ")");
                }).join("\n")

                function run() {
                    busy = true;
                    results = [];
                    var list = [ { name: "OpenSky Network", url: "https://opensky-network.org/api/states/all?icao24=000000" },
                                 { name: "adsbdb.com", url: "https://api.adsbdb.com/v0/callsign/DLH400" } ];
                    var left = list.length, out = [];
                    list.forEach(function (item) {
                        var x = new XMLHttpRequest();
                        x.open("GET", item.url);
                        x.timeout = 15000;
                        x.onreadystatechange = function () {
                            if (x.readyState !== XMLHttpRequest.DONE) return;
                            out.push({ name: item.name, ok: x.status === 200 || x.status === 404, status: x.status });
                            if (--left === 0) { out.sort(function (a, b) { return a.name < b.name ? -1 : 1; }); results = out; busy = false; }
                        };
                        x.send();
                    });
                }
            }

            QQC2.TabBar {
                id: tabBar
                Layout.fillWidth: true
                Repeater {
                    model: Params.tabs()
                    QQC2.TabButton { text: i18nd("plasma_wallpaper_de.robin.world", modelData) }
                }
            }

            QQC2.ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth

                // All settings, one tab per group
                Kirigami.FormLayout {
                    width: parent.width

                    Repeater {
                        model: Params.sections[tabBar.currentIndex] ? Params.sections[tabBar.currentIndex].params : []

                        RowLayout {
                            id: paramRow
                            enabled: !win.readOnly
                            readonly property var param: modelData
                            readonly property bool own: win.sourceOf(param.key) === "own"
                            Kirigami.FormData.label: i18nd("plasma_wallpaper_de.robin.world", param.label) + ":"

                            Loader {
                                id: editor
                                sourceComponent: paramRow.param.type === "bool" ? boolEditor
                                               : paramRow.param.type === "enum" ? enumEditor
                                               : paramRow.param.type === "color" ? colorEditor
                                               : paramRow.param.type === "colors" ? colorsEditor
                                               : paramRow.param.type === "text" ? textEditor
                                               : numberEditor

                                Component {
                                    id: boolEditor
                                    QQC2.CheckBox {
                                        checked: win.effectiveP[paramRow.param.key] === true
                                        onToggled: win.setValue(paramRow.param.key, checked)
                                    }
                                }

                                Component {
                                    id: textEditor
                                    QQC2.TextField {
                                        implicitWidth: Kirigami.Units.gridUnit * 16
                                        text: String(win.effectiveP[paramRow.param.key])
                                        onEditingFinished: win.setValue(paramRow.param.key, text)
                                    }
                                }

                                Component {
                                    id: enumEditor
                                    QQC2.ComboBox {
                                        model: paramRow.param.options.map(function (o) { return { value: o.value, text: i18nd("plasma_wallpaper_de.robin.world", o.text) }; })
                                        textRole: "text"
                                        valueRole: "value"
                                        currentIndex: Math.max(0, indexOfValue(win.effectiveP[paramRow.param.key]))
                                        onActivated: win.setValue(paramRow.param.key, currentValue)
                                    }
                                }

                                Component {
                                    id: colorEditor
                                    QQC2.Button {
                                        onClicked: colorDialog.edit(paramRow.param.key, -1, win.effectiveP[paramRow.param.key])
                                        contentItem: RowLayout {
                                            spacing: Kirigami.Units.smallSpacing
                                            Kirigami.Icon {
                                                source: "color-picker"
                                                implicitWidth: Kirigami.Units.iconSizes.small
                                                implicitHeight: implicitWidth
                                            }
                                            Rectangle {
                                                implicitWidth: Kirigami.Units.iconSizes.medium
                                                implicitHeight: Kirigami.Units.iconSizes.small
                                                radius: 3
                                                color: win.effectiveP[paramRow.param.key]
                                                border.color: Kirigami.Theme.textColor
                                            }
                                            QQC2.Label { text: win.effectiveP[paramRow.param.key] }
                                        }
                                    }
                                }

                                Component {
                                    id: colorsEditor
                                    Flow {
                                        width: Kirigami.Units.gridUnit * 22
                                        spacing: Kirigami.Units.smallSpacing
                                        Repeater {
                                            model: win.effectiveP[paramRow.param.key]
                                            delegate: Rectangle {
                                                required property int index
                                                required property string modelData
                                                width: Kirigami.Units.gridUnit * 2.4
                                                height: Kirigami.Units.gridUnit * 2
                                                radius: 4
                                                color: modelData
                                                border.color: Kirigami.Theme.textColor
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    onClicked: colorDialog.edit(paramRow.param.key, index, modelData)
                                                }
                                                QQC2.ToolButton {
                                                    anchors.right: parent.right
                                                    anchors.top: parent.top
                                                    width: parent.width / 2
                                                    height: width
                                                    padding: 0
                                                    icon.name: "edit-delete-remove"
                                                    visible: win.effectiveP[paramRow.param.key].length > 1
                                                    onClicked: {
                                                        var l = win.effectiveP[paramRow.param.key].slice();
                                                        l.splice(index, 1);
                                                        win.setValue(paramRow.param.key, l);
                                                    }
                                                    QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Remove color")
                                                    QQC2.ToolTip.visible: hovered
                                                }
                                            }
                                        }
                                        QQC2.Button {
                                            icon.name: "list-add"
                                            text: i18nd("plasma_wallpaper_de.robin.world", "Color")
                                            onClicked: {
                                                var l = win.effectiveP[paramRow.param.key].slice();
                                                l.push("#ffffff");
                                                win.setValue(paramRow.param.key, l);
                                                colorDialog.edit(paramRow.param.key, l.length - 1, "#ffffff");
                                            }
                                        }
                                    }
                                }

                                Component {
                                    id: numberEditor
                                    // SpinBox only knows integers, so real values are scaled
                                    QQC2.SpinBox {
                                        readonly property var param: paramRow.param
                                        readonly property real factor: param.type === "int" ? 1 : 1000
                                        readonly property int decimals: param.type === "int" ? 0
                                                                      : param.step < 0.1 ? 2 : param.step < 1 ? 1 : 0
                                        from: Math.round(param.min * factor)
                                        to: Math.round(param.max * factor)
                                        stepSize: Math.max(1, Math.round((param.step || 1) * factor))
                                        editable: true
                                        value: Math.round(Number(win.effectiveP[param.key]) * factor)
                                        onValueModified: win.setValue(param.key, param.type === "int" ? value : value / factor)
                                        textFromValue: function (v, locale) {
                                            if (param.key === "Tilt" && v === 0) return i18nd("plasma_wallpaper_de.robin.world", "Auto");
                                            return Number(v / factor).toLocaleString(locale, "f", decimals);
                                        }
                                        valueFromText: function (text, locale) {
                                            var n = Number.fromLocaleString(locale, text);
                                            return isNaN(n) ? 0 : Math.round(n * factor);
                                        }
                                    }
                                }
                            }

                            QQC2.Label {
                                text: win.sourceText(paramRow.param.key)
                                font: Kirigami.Theme.smallFont
                                opacity: paramRow.own ? 1 : 0.6
                            }

                            QQC2.ToolButton {
                                icon.name: "edit-undo"
                                visible: paramRow.own && !win.readOnly
                                onClicked: win.resetValue(paramRow.param.key)
                                QQC2.ToolTip.text: i18nd("plasma_wallpaper_de.robin.world", "Use the inherited value")
                                QQC2.ToolTip.visible: hovered
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true

                // The aircraft come from the internet: a way to see whether the services answer. It sits here, at the
                // end, and shows on the Aircraft tab only, so nothing above it moves.
                QQC2.Button {
                    readonly property bool onAircraftTab: Params.sections[tabBar.currentIndex] && Params.sections[tabBar.currentIndex].title === "Aircraft"
                    visible: onAircraftTab
                    text: i18nd("plasma_wallpaper_de.robin.world", "Test connection")
                    icon.name: "network-connect"
                    enabled: !tester.busy
                    onClicked: tester.run()
                }
                QQC2.Label {
                    visible: tester.busy || tester.results.length > 0
                    text: tester.busy ? "…" : tester.text.replace(/\n/g, "   ")
                    color: tester.busy || !tester.allOk ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                }
                QQC2.Label {
                    Layout.fillWidth: true
                    text: win.readOnly ? "" : win.folderPath + (win.kind === "collection" ? win.selected + "/_collection.json" : win.selected + ".json")
                    elide: Text.ElideMiddle
                    font: Kirigami.Theme.smallFont
                    opacity: 0.6
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Revert")
                    icon.name: "edit-undo"
                    enabled: win.dirty
                    onClicked: win.doRevert()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Save")
                    icon.name: "document-save"
                    enabled: win.dirty
                    onClicked: win.doSave()
                }
                QQC2.Button {
                    text: i18nd("plasma_wallpaper_de.robin.world", "Close")
                    icon.name: "window-close"
                    onClicked: win.close()
                }
            }
        }
    }

    // ---- Shared color dialog ----------------------------------------------------------------------------------
    ColorDialog {
        id: colorDialog
        property string key: ""
        property int index: -1
        function edit(k, i, current) { key = k; index = i; selectedColor = current; open(); }
        onAccepted: {
            var c = String(selectedColor).substring(0, 7);
            if (index < 0) { win.setValue(key, c); return; }
            var l = win.effectiveP[key].slice();
            l[index] = c;
            win.setValue(key, l);
        }
    }

    // ---- Context menu ------------------------------------------------------------------------------------------
    QQC2.Menu {
        id: contextMenu
        property var row: ({ type: "theme", key: "", name: "" })
        readonly property bool isHeader: row.type === "header"
        readonly property string collection: isHeader ? row.name : (row.collection || "")

        QQC2.MenuItem {
            visible: !contextMenu.isHeader
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "Duplicate")
            icon.name: "edit-copy"
            onTriggered: win.duplicateTheme(contextMenu.row.key)
        }
        QQC2.MenuItem {
            visible: !contextMenu.isHeader && !contextMenu.row.builtin
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "Delete")
            icon.name: "edit-delete"
            onTriggered: { win.target = contextMenu.row.key; deleteThemeDialog.open(); }
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && win.creatableCollection(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "New theme here")
            icon.name: "list-add"
            onTriggered: win.newTheme(contextMenu.collection)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && win.creatableCollection(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "New subcollection…")
            icon.name: "folder-new"
            onTriggered: { win.select("collection", contextMenu.collection); win.newInside = true; newCollectionDialog.open(); }
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "Duplicate collection…")
            icon.name: "edit-copy"
            onTriggered: { win.target = contextMenu.collection; copyCollectionField.text = contextMenu.collection + " " + i18nd("plasma_wallpaper_de.robin.world", "copy"); copyCollectionDialog.open(); }
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader
            height: visible ? implicitHeight : 0
            text: win.collapsed[contextMenu.collection] ? i18nd("plasma_wallpaper_de.robin.world", "Expand") : i18nd("plasma_wallpaper_de.robin.world", "Collapse")
            icon.name: win.collapsed[contextMenu.collection] ? "arrow-right" : "arrow-down"
            onTriggered: win.toggleFold(contextMenu.collection)
        }
        QQC2.MenuItem {
            visible: contextMenu.isHeader && !Store.isBuiltinCollection(contextMenu.collection)
            height: visible ? implicitHeight : 0
            text: i18nd("plasma_wallpaper_de.robin.world", "Delete collection")
            icon.name: "edit-delete"
            onTriggered: { win.target = contextMenu.collection; deleteCollectionDialog.open(); }
        }
        QQC2.MenuItem {
            text: i18nd("plasma_wallpaper_de.robin.world", "Open folder")
            icon.name: "folder-open"
            onTriggered: files.openFolder(Store.isBuiltinCollection(contextMenu.collection) ? "" : contextMenu.collection)
        }
    }

    // ---- Dialogs -------------------------------------------------------------------------------------------------
    QQC2.Dialog {
        id: deleteThemeDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "Delete theme")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18nd("plasma_wallpaper_de.robin.world", "Delete the theme \"%1\"?", Tree.labelOf(win.target))
        }
        onAccepted: { win.change(Store.deleteTheme(win.ud, win.target)); win.themeKeyChanged(win.target, ""); win.afterDelete(); }
    }

    QQC2.Dialog {
        id: deleteCollectionDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "Delete collection")
        standardButtons: QQC2.Dialog.Yes | QQC2.Dialog.No
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: i18nd("plasma_wallpaper_de.robin.world", "Delete your collection \"%1\" with its defaults, all its own themes and all its subcollections?", win.target)
        }
        onAccepted: { win.change(Store.deleteCollection(win.ud, win.target)); win.collectionRemoved(win.target); win.afterDelete(); }
    }

    QQC2.Dialog {
        id: copyCollectionDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "Duplicate collection")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { copyCollectionField.forceActiveFocus(); copyCollectionField.selectAll(); }
        onAccepted: win.copyCollection(win.target, copyCollectionField.text.trim())
        ColumnLayout {
            width: parent.width
            QQC2.Label {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: i18nd("plasma_wallpaper_de.robin.world", "Copy \"%1\" with its defaults, themes and subcollections to a new collection of your own. Use a path like \"parent/name\" to put it into another collection.", win.target)
            }
            QQC2.TextField {
                id: copyCollectionField
                Layout.fillWidth: true
                onAccepted: copyCollectionDialog.accept()
            }
        }
    }

    QQC2.Dialog {
        id: newCollectionDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "New collection")
        standardButtons: QQC2.Dialog.Ok | QQC2.Dialog.Cancel
        onOpened: { newCollectionField.text = ""; newInsideBox.checked = win.newInside; newCollectionField.forceActiveFocus(); }
        onAccepted: {
            var name = newCollectionField.text.trim();
            win.createCollection(newInsideBox.visible && newInsideBox.checked ? win.currentCollection + "/" + name : name);
        }
        ColumnLayout {
            width: parent.width
            QQC2.TextField {
                id: newCollectionField
                Layout.fillWidth: true
                placeholderText: i18nd("plasma_wallpaper_de.robin.world", "Name")
                onAccepted: newCollectionDialog.accept()
            }
            QQC2.CheckBox {
                id: newInsideBox
                visible: win.creatableCollection(win.currentCollection)
                text: i18nd("plasma_wallpaper_de.robin.world", "Inside \"%1\" (inherits its defaults)", win.currentCollection)
            }
        }
    }

    QQC2.Dialog {
        id: discardDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "Unsaved changes")
        standardButtons: QQC2.Dialog.Discard | QQC2.Dialog.Cancel
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: win.kind === "collection" ? i18nd("plasma_wallpaper_de.robin.world", "Discard the changes to the defaults of \"%1\"?", win.selected)
                                            : i18nd("plasma_wallpaper_de.robin.world", "Discard the changes to \"%1\"?", win.draftName)
        }
        onDiscarded: {
            win.dirty = false;
            if (win.pending) win.open(win.pending.kind, win.pending.id);
            win.pending = null;
            close();
        }
    }

    QQC2.Dialog {
        id: unsavedDialog
        parent: QQC2.Overlay.overlay
        anchors.centerIn: parent
        width: Kirigami.Units.gridUnit * 24
        modal: true
        title: i18nd("plasma_wallpaper_de.robin.world", "Unsaved changes")
        standardButtons: QQC2.Dialog.Save | QQC2.Dialog.Discard | QQC2.Dialog.Cancel
        QQC2.Label {
            width: parent.width
            wrapMode: Text.WordWrap
            text: win.kind === "collection" ? i18nd("plasma_wallpaper_de.robin.world", "Save the changes to the defaults of \"%1\"?", win.selected) : i18nd("plasma_wallpaper_de.robin.world", "Save the changes to \"%1\"?", win.draftName)
        }
        onAccepted: { win.doSave(); win.visible = false; }
        onDiscarded: { win.doRevert(); win.visible = false; }
    }

    ThemeAssistant {
        id: assistantDialog
        ud: win.ud
        onCreate: function (collection, list, baseName) {
            var u = win.ud;
            if (!win.collectionExists(collection)) u = Store.addCollection(u, collection);
            var first = "";
            for (var i = 0; i < list.length; i++) {
                var name = Store.uniqueName(u, collection, list.length > 1 ? baseName + " " + (i + 1) : baseName);
                u = Store.addTheme(u, collection, name, list[i]);
                if (first === "") first = collection + "/" + name;
            }
            win.change(u);
            win.open("theme", first);
        }
    }
    function collectionExists(path) { return catalog.collections.indexOf(path) >= 0; }
}
