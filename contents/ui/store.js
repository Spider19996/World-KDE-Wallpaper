.pragma library
.import "tree.js" as Tree
.import "params.js" as Params
.import "builtin.js" as Builtin

// User data: { collections: { path: values }, themes: { "collection/name": values } }. It is stored as a JSON
// string in the wallpaper config. Built-in data comes from builtin.js and cannot be changed.

function empty() { return { collections: {}, themes: {} }; }

function parse(json) {
    var ud = empty();
    try {
        var d = JSON.parse(json);
        for (var c in d.collections || {}) ud.collections[c] = Params.sanitize(d.collections[c]);
        for (var t in d.themes || {}) if (t.indexOf("/") > 0) ud.themes[t] = Params.sanitize(d.themes[t]);
    } catch (e) {
    }
    return ud;
}

function stringify(ud) { return JSON.stringify(ud); }
function clone(ud) { return JSON.parse(JSON.stringify(ud)); }

function isBuiltinCollection(path) { return Builtin.collections.hasOwnProperty(path) || hasBuiltinBelow(path); }
function hasBuiltinBelow(path) {
    for (var k in Builtin.themes) if (Tree.within(Tree.collectionOf(k), path)) return true;
    return false;
}
function isBuiltinTheme(key) { return Builtin.themes.hasOwnProperty(key); }
function hasUserCollection(ud, path) { return ud.collections.hasOwnProperty(path); }

// Every collection path with all its ancestors
function withAncestors(paths) {
    var seen = {}, out = [];
    paths.forEach(function (p) {
        for (var q = p; q !== ""; q = Tree.parentOf(q)) if (!seen[q]) { seen[q] = true; out.push(q); }
    });
    out.sort(function (a, b) {
        var x = a.split("/"), y = b.split("/");
        for (var i = 0; i < Math.min(x.length, y.length); i++)
            if (x[i] !== y[i]) return x[i].localeCompare(y[i]);
        return x.length - y.length;
    });
    return out;
}

// Defaults set by a collection itself (built-in values first, then the user's)
function ownCollectionValues(ud, path) {
    var v = {}, b = Builtin.collections[path] || {}, u = ud.collections[path] || {};
    for (var k in b) v[k] = b[k];
    for (var k2 in u) v[k2] = u[k2];
    return v;
}

function chain(path) {
    var list = [];
    for (var p = path; p !== ""; p = Tree.parentOf(p)) list.unshift(p);
    return list;
}

function ownThemeValues(ud, key) {
    return ud.themes[key] || Builtin.themes[key] || {};
}

// All values of a theme or a collection with everything inherited filled in
function effective(ud, collection, ownValues) {
    var v = Params.defaults();
    chain(collection).forEach(function (p) {
        var c = ownCollectionValues(ud, p);
        for (var k in c) v[k] = c[k];
    });
    for (var k2 in ownValues) v[k2] = ownValues[k2];
    return Params.sanitize(v);
}

function catalog(ud, hideBuiltin) {
    var themes = [], paths = [];
    if (!hideBuiltin) {
        for (var bk in Builtin.themes) themes.push(makeTheme(ud, bk, true));
        for (var bc in Builtin.collections) paths.push(bc);
    }
    var user = Object.keys(ud.themes).sort();
    user.forEach(function (k) { if (!(!hideBuiltin && isBuiltinTheme(k))) themes.push(makeTheme(ud, k, false)); });
    for (var uc in ud.collections) paths.push(uc);
    themes.forEach(function (t) { paths.push(t.collection); });
    var collections = withAncestors(paths);
    themes.sort(function (a, b) {
        var ia = collections.indexOf(a.collection), ib = collections.indexOf(b.collection);
        if (ia !== ib) return ia - ib;
        if (a.builtin !== b.builtin) return a.builtin ? -1 : 1;
        return a.name.localeCompare(b.name);
    });
    return { collections: collections, themes: themes };
}

function makeTheme(ud, key, builtin) {
    var collection = Tree.collectionOf(key);
    var own = builtin ? Builtin.themes[key] : ud.themes[key];
    return { key: key, collection: collection, name: key.substring(collection.length + 1), builtin: builtin,
             own: own, config: effective(ud, collection, own) };
}

// Where a value of a theme/collection comes from: "own", the path of a collection, or "" for the default
function source(ud, scope, id, key) {
    var collection = scope === "theme" ? Tree.collectionOf(id) : id;
    if (scope === "theme") {
        if (ownThemeValues(ud, id).hasOwnProperty(key)) return "own";
    } else if (ownCollectionValues(ud, id).hasOwnProperty(key)) {
        return "own";
    }
    var path = scope === "theme" ? collection : Tree.parentOf(collection);
    for (var p = path; p !== ""; p = Tree.parentOf(p))
        if (ownCollectionValues(ud, p).hasOwnProperty(key)) return p;
    return "";
}

// ---- Editing (each returns a changed copy) ------------------------------------------------------------

function setThemeValue(ud, key, k, v) {
    var c = clone(ud);
    if (!c.themes[key]) c.themes[key] = Builtin.themes[key] ? JSON.parse(JSON.stringify(Builtin.themes[key])) : {};
    c.themes[key][k] = v;
    return c;
}
function resetThemeValue(ud, key, k) {
    var c = clone(ud);
    if (c.themes[key]) delete c.themes[key][k];
    return c;
}
function clearTheme(ud, key) {
    var c = clone(ud);
    if (c.themes[key]) c.themes[key] = {};
    return c;
}
function setCollectionValue(ud, path, k, v) {
    var c = clone(ud);
    if (!c.collections[path]) c.collections[path] = {};
    c.collections[path][k] = v;
    return c;
}
function resetCollectionValue(ud, path, k) {
    var c = clone(ud);
    if (c.collections[path]) delete c.collections[path][k];
    return c;
}
function clearCollection(ud, path) {
    var c = clone(ud);
    c.collections[path] = {};
    return c;
}

function validName(name) { return name.length > 0 && name.indexOf("/") < 0 && name.trim() === name; }

function uniqueName(ud, collection, base) {
    var themes = catalog(ud, false).themes.map(function (t) { return t.key; });
    var name = base, n = 2;
    while (themes.indexOf(collection + "/" + name) >= 0) name = base + " " + n++;
    return name;
}

function addTheme(ud, collection, name, values) {
    var c = clone(ud);
    c.themes[collection + "/" + name] = Params.sanitize(values || {});
    if (!isBuiltinCollection(collection) && !c.collections[collection]) c.collections[collection] = {};
    return c;
}

function renameTheme(ud, key, newKey) {
    if (key === newKey) return ud;
    var c = clone(ud);
    c.themes[newKey] = c.themes[key] || {};
    delete c.themes[key];
    return c;
}

// Deletes a user theme; a theme that overrides a built-in one goes back to the built-in version
function deleteTheme(ud, key) {
    var c = clone(ud);
    delete c.themes[key];
    return c;
}

function addCollection(ud, path) {
    var c = clone(ud);
    if (!c.collections[path]) c.collections[path] = {};
    return c;
}

function deleteCollection(ud, path) {
    var c = clone(ud);
    for (var p in c.collections) if (Tree.within(p, path)) delete c.collections[p];
    for (var t in c.themes) if (Tree.within(Tree.collectionOf(t), path)) delete c.themes[t];
    return c;
}

function duplicateCollection(ud, from, to) {
    var c = clone(ud), cat = catalog(ud, false);
    cat.collections.forEach(function (p) {
        if (!Tree.within(p, from)) return;
        var target = to + p.substring(from.length);
        c.collections[target] = JSON.parse(JSON.stringify(ownCollectionValues(ud, p)));
    });
    cat.themes.forEach(function (t) {
        if (!Tree.within(t.collection, from)) return;
        c.themes[to + t.key.substring(from.length)] = JSON.parse(JSON.stringify(t.own || {}));
    });
    // The copy no longer sits below the parents of the original, so it carries everything it inherited
    c.collections[to] = effective(ud, from, {});
    return c;
}

function moveTheme(ud, key, collection) {
    var name = key.substring(Tree.collectionOf(key).length + 1);
    var target = collection + "/" + name;
    if (target === key) return ud;
    var c = clone(ud);
    var own = c.themes[key] ? c.themes[key] : (Builtin.themes[key] || {});
    c.themes[target] = JSON.parse(JSON.stringify(own));
    delete c.themes[key];
    return c;
}

// ---- Which themes take turns ---------------------------------------------------------------------------

// selection: list of "all", "c:<collection>" and "t:<key>". Nothing ticked means the default theme only.
function selectedThemes(cat, selection) {
    var out = [];
    cat.themes.forEach(function (t) {
        if (selection.indexOf("all") >= 0 || selection.indexOf("t:" + t.key) >= 0) { out.push(t); return; }
        for (var i = 0; i < selection.length; i++)
            if (selection[i].indexOf("c:") === 0 && Tree.within(t.collection, selection[i].substring(2))) { out.push(t); return; }
    });
    if (out.length > 0) return out;
    for (var j = 0; j < cat.themes.length; j++) if (cat.themes[j].key === Builtin.defaultKey) return [cat.themes[j]];
    return cat.themes.length > 0 ? [cat.themes[0]] : [];
}

// A theme made of the defaults only, used when no theme exists at all
function fallbackConfig() { return Params.defaults(); }

// Themes and collections read from the theme folder: entries are { path: "./A/B/Name.json", values }.
// A file "_collection.json" holds the defaults of its folder. Built-in names are left alone.
function importEntries(ud, entries) {
    var c = clone(ud), n = 0;
    entries.forEach(function (e) {
        var rel = String(e.path).replace(/^\.\//, "");
        if (!/\.json$/i.test(rel)) return;
        rel = rel.substring(0, rel.length - 5);
        var name = rel.substring(rel.lastIndexOf("/") + 1);
        var values = Params.sanitize(e.values || {});
        if (name === "_collection") {
            var path = Tree.parentOf(rel);
            if (path !== "" && !isBuiltinCollection(path)) { c.collections[path] = values; n++; }
        } else if (rel.indexOf("/") > 0 && !isBuiltinTheme(rel) && !isBuiltinCollection(Tree.collectionOf(rel))) {
            c.themes[rel] = values;
            for (var p = Tree.collectionOf(rel); p !== ""; p = Tree.parentOf(p)) if (!c.collections[p]) c.collections[p] = {};
            n++;
        }
    });
    return { ud: c, count: n };
}
