.pragma library
.import QtQuick.LocalStorage as Sql

// Small per-user memory for things like folded collections (kept outside the wallpaper settings, so folding a
// collection does not count as a change that has to be applied).

function db() { return Sql.LocalStorage.openDatabaseSync("world-wallpaper", "1.0", "World wallpaper", 100000); }

function get(name, fallback) {
    try {
        var value = fallback;
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS memory (name TEXT PRIMARY KEY, value TEXT)");
            var r = tx.executeSql("SELECT value FROM memory WHERE name = ?", [name]);
            if (r.rows.length > 0) value = r.rows.item(0).value;
        });
        return value;
    } catch (e) {
        return fallback;
    }
}

function set(name, value) {
    try {
        db().transaction(function (tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS memory (name TEXT PRIMARY KEY, value TEXT)");
            tx.executeSql("INSERT OR REPLACE INTO memory VALUES (?, ?)", [name, value]);
        });
    } catch (e) {
    }
}

function getList(name) {
    try { var l = JSON.parse(get(name, "[]")); return Array.isArray(l) ? l : []; } catch (e) { return []; }
}
function setList(name, list) { set(name, JSON.stringify(list)); }
