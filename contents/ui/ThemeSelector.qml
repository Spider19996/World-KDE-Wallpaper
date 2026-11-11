import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

import "params.js" as Params
import "persist.js" as Persist
import "selection.js" as Sel
import "tree.js" as Tree

// Pick any mix of whole collections (with their subcollections) and single themes that take turns.
// selection: list of "all", "c:<collection>" and "t:<collection>/<name>" entries
Rectangle {
    id: root

    property var selection: []
    property var catalog: ({ collections: [], themes: [] })
    signal selectionEdited(var selection)

    property var collapsed: ({})

    color: Kirigami.Theme.backgroundColor
    border.color: Kirigami.Theme.disabledTextColor
    radius: 4
    implicitHeight: Kirigami.Units.gridUnit * 16
    implicitWidth: Kirigami.Units.gridUnit * 22

    function collectionChecked(path) { return Sel.includesCollection(selection, path); }
    function themeChecked(key, collection) { return Sel.includesTheme(selection, key, collection); }
    function someChecked(path) { return Sel.partial(selection, path); }
    function setCollection(path, on) { selectionEdited(Sel.setCollection(selection, path, on, catalog)); }
    function setTheme(key, collection, on) { selectionEdited(Sel.setTheme(selection, key, collection, on, catalog)); }

    readonly property var rows: Tree.rows(catalog.collections, catalog.themes, collapsed, function (t, depth) {
        return { type: "theme", key: t.key, collection: t.collection, title: t.name, depth: depth, config: t.config };
    })

    function toggleFold(path) {
        var c = Object.assign({}, collapsed);
        c[path] = !c[path];
        collapsed = c;
        Persist.setList("selectorFolds", Object.keys(c).filter(function (k) { return c[k]; }));
    }

    // Folded collections are remembered
    Component.onCompleted: {
        var c = {};
        Persist.getList("selectorFolds").forEach(function (name) { c[name] = true; });
        collapsed = c;
    }

    QQC2.ScrollView {
        anchors.fill: parent
        anchors.margins: 1

        ListView {
            clip: true
            model: root.rows
            delegate: QQC2.ItemDelegate {
                id: row
                readonly property bool isHeader: modelData.type === "header"
                width: ListView.view.width
                leftPadding: Kirigami.Units.smallSpacing + modelData.depth * Kirigami.Units.gridUnit
                topPadding: 0
                bottomPadding: 0

                contentItem: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.CheckBox {
                        tristate: row.isHeader
                        checkState: row.isHeader
                                    ? (root.collectionChecked(modelData.name) ? Qt.Checked
                                       : root.someChecked(modelData.name) ? Qt.PartiallyChecked : Qt.Unchecked)
                                    : (root.themeChecked(modelData.key, modelData.collection) ? Qt.Checked : Qt.Unchecked)
                        nextCheckState: function () { return checkState; }
                        onClicked: {
                            if (row.isHeader) root.setCollection(modelData.name, !root.collectionChecked(modelData.name));
                            else root.setTheme(modelData.key, modelData.collection,
                                               !root.themeChecked(modelData.key, modelData.collection));
                        }
                    }

                    Rectangle {
                        visible: !row.isHeader
                        width: Kirigami.Units.iconSizes.small
                        height: Kirigami.Units.iconSizes.small
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
                        visible: row.isHeader
                        text: row.isHeader ? modelData.count : ""
                        font: Kirigami.Theme.smallFont
                        opacity: 0.6
                    }
                    Kirigami.Icon {
                        visible: row.isHeader
                        source: root.collapsed[modelData.name] ? "arrow-right" : "arrow-down"
                        implicitWidth: Kirigami.Units.iconSizes.small
                        implicitHeight: implicitWidth
                    }
                }

                onClicked: {
                    if (isHeader) root.toggleFold(modelData.name);
                    else root.setTheme(modelData.key, modelData.collection, !root.themeChecked(modelData.key, modelData.collection));
                }
            }
        }
    }
}
