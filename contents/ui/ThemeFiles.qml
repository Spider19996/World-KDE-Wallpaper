import QtQuick
import org.kde.plasma.plasma5support as P5Support

import "store.js" as Store

// The theme folder (~/.local/share/world-wallpaper/themes) is where the themes live: one folder per collection, one
// JSON file per theme with only the values it changes, "_collection.json" for the defaults of a collection.
// QML cannot read or write files itself, so this runs small shell commands through the "executable" data engine.
// `ud` always holds what is in the folder (plus what was just written). Nothing watches the folder in the background: whoever
// needs the current state calls reload() (the desktop when the settings are applied, the settings when the theme manager
// saved or was opened).
Item {
    id: root

    signal committed()
    property var ud: Store.empty()
    property bool loaded: false

    readonly property string dir: 'D="${XDG_DATA_HOME:-$HOME/.local/share}/world-wallpaper/themes"; '
    readonly property var emptyData: ({ collections: {}, themes: {} })
    property int nonce: 0
    property var pending: ({})
    property int writing: 0

    function q(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    P5Support.DataSource {
        id: shell
        engine: "executable"
        connectedSources: []
        onNewData: function (source, d) {
            disconnectSource(source);
            var cb = root.pending[source];
            delete root.pending[source];
            if (cb) cb(String(d["stdout"] || ""), d["exit code"]);
        }
    }

    function run(cmd, callback) {
        var c = cmd + " # " + (++nonce);
        if (callback) pending[c] = callback;
        shell.connectSource(c);
    }

    // Writes are counted, so a read of the folder never sees a half-written state
    function write(cmd) {
        writing++;
        run(cmd, function () { writing--; });
    }

    // JSON with only ASCII characters, so it can travel base64 encoded
    function ascii(value) {
        return JSON.stringify(value, null, 2).replace(/[\u0080-￿]/g, function (c) {
            return "\\u" + ("0000" + c.charCodeAt(0).toString(16)).slice(-4);
        });
    }

    function writeFile(rel, value) {
        write(dir + 'F="$D"/' + q(rel) + '; mkdir -p "$(dirname "$F")" && printf %s ' + q(Qt.btoa(ascii(value))) + ' | base64 -d > "$F"');
    }

    function removeFile(rel) {
        write(dir + 'F="$D"/' + q(rel) + '; rm -f "$F"; rmdir -p --ignore-fail-on-non-empty "$(dirname "$F")" 2>/dev/null; true');
    }

    // Writes what changed from `before` to `after`
    function sync(before, after) {
        for (var c in after.collections)
            if (JSON.stringify(after.collections[c]) !== JSON.stringify(before.collections[c])) writeFile(c + "/_collection.json", after.collections[c]);
        for (var t in after.themes)
            if (JSON.stringify(after.themes[t]) !== JSON.stringify(before.themes[t])) writeFile(t + ".json", after.themes[t]);
        for (var oc in before.collections) if (!after.collections.hasOwnProperty(oc)) removeFile(oc + "/_collection.json");
        for (var ot in before.themes) if (!after.themes.hasOwnProperty(ot)) removeFile(ot + ".json");
    }

    // Writes the change to the folder and takes it over at once
    function commit(after) {
        sync(ud, after);
        ud = after;
        committed();
    }

    function openFolder(sub) {
        run(dir + 'mkdir -p "$D"/' + q(sub || "") + ' && xdg-open "$D"/' + q(sub || ""));
    }

    // Reads the whole folder; the callback gets [{ path, values }]
    function readAll(callback) {
        run(dir + 'cd "$D" 2>/dev/null && find . -name "*.json" | sort | while IFS= read -r f; do printf "%s\\t" "$f"; base64 -w0 "$f"; echo; done', function (out) {
            var list = [];
            out.split("\n").forEach(function (line) {
                var i = line.indexOf("\t");
                if (i < 0) return;
                try { list.push({ path: line.substring(0, i), values: JSON.parse(Qt.atob(line.substring(i + 1))) }); } catch (e) {}
            });
            callback(list);
        });
    }

    // Takes over what is in the folder
    function reload(callback) {
        readAll(function (list) {
            if (root.writing > 0) return;
            // Only a real change replaces `ud`, so nothing that depends on it starts over for nothing
            var fresh = Store.importEntries(Store.empty(), list).ud;
            if (JSON.stringify(fresh) !== JSON.stringify(root.ud)) root.ud = fresh;
            root.loaded = true;
            if (callback) callback();
        });
    }

    Component.onCompleted: reload()
}
