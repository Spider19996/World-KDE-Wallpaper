.pragma library
.import "tree.js" as Tree

// The theme selection is a list of entries: "all", "c:<collection>" (with everything below it) or
// "t:<collection>/<name>". It is stored as a JSON string in the wallpaper config.
// catalog = { collections: [paths], themes: [{ key, collection }] }

function parse(json) {
    try {
        var list = JSON.parse(json);
        if (Array.isArray(list)) return list;
    } catch (e) {
    }
    return [];
}

function stringify(list) {
    return JSON.stringify(list);
}

function includesCollection(sel, path) {
    if (sel.indexOf("all") >= 0) return true;
    for (var i = 0; i < sel.length; i++)
        if (sel[i].indexOf("c:") === 0 && Tree.within(path, sel[i].substring(2))) return true;
    return false;
}

function includesTheme(sel, key, collection) {
    return includesCollection(sel, collection) || sel.indexOf("t:" + key) >= 0;
}

// Part of a collection is selected, but not all of it
function partial(sel, path) {
    if (includesCollection(sel, path)) return false;
    for (var i = 0; i < sel.length; i++) {
        var e = sel[i];
        if (e.indexOf("t:") === 0 && Tree.within(Tree.collectionOf(e.substring(2)), path)) return true;
        if (e.indexOf("c:") === 0 && Tree.within(e.substring(2), path)) return true;
    }
    return false;
}

// "all" is only shorthand for the top-level collections, edits work on explicit entries
function normalize(sel, catalog) {
    var out = sel.filter(function (e) { return e !== "all"; });
    if (sel.indexOf("all") < 0) return out;
    catalog.collections.forEach(function (c) {
        if (c.indexOf("/") < 0 && out.indexOf("c:" + c) < 0) out.push("c:" + c);
    });
    return out;
}

function coveringEntry(out, collection) {
    for (var i = 0; i < out.length; i++)
        if (out[i].indexOf("c:") === 0 && Tree.within(collection, out[i].substring(2))) return out[i].substring(2);
    return null;
}

// "c:X" is no longer selected as a whole: list everything in it one level at a time, except the target
function splitOut(out, X, targetCollection, skipCollection, skipKey, catalog) {
    catalog.themes.forEach(function (t) {
        if (t.collection === X && t.key !== skipKey) out.push("t:" + t.key);
    });
    catalog.collections.forEach(function (c) {
        if (Tree.parentOf(c) !== X || c === skipCollection) return;
        if (Tree.within(targetCollection, c)) splitOut(out, c, targetCollection, skipCollection, skipKey, catalog);
        else out.push("c:" + c);
    });
}

function dropBelow(out, path) {
    return out.filter(function (e) {
        if (e.indexOf("c:") === 0) return !Tree.within(e.substring(2), path);
        if (e.indexOf("t:") === 0) return !Tree.within(Tree.collectionOf(e.substring(2)), path);
        return true;
    });
}

function setCollection(sel, path, on, catalog) {
    var out = normalize(sel, catalog);
    if (on) {
        var covered = coveringEntry(out, path);
        out = dropBelow(out, path);
        if (covered === null) out.push("c:" + path);
        else out.push("c:" + covered); // already part of a selected collection
        return out.filter(function (e, i) { return out.indexOf(e) === i; });
    }
    var cover = coveringEntry(out, path);
    if (cover !== null) {
        out = out.filter(function (e) { return e !== "c:" + cover; });
        splitOut(out, cover, path, path, "", catalog);
    }
    return dropBelow(out, path);
}

function setTheme(sel, key, collection, on, catalog) {
    var out = normalize(sel, catalog);
    if (on) {
        if (!includesTheme(out, key, collection)) out.push("t:" + key);
        return out;
    }
    var cover = coveringEntry(out, collection);
    if (cover !== null) {
        out = out.filter(function (e) { return e !== "c:" + cover; });
        splitOut(out, cover, collection, "", key, catalog);
    }
    return out.filter(function (e) { return e !== "t:" + key; });
}
