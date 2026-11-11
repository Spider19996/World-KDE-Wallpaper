.pragma library

// Collections form a tree: a collection path is "a", "a/b", "a/b/c", a theme key is "<collection>/<name>"

function parentOf(path) {
    var i = path.lastIndexOf("/");
    return i < 0 ? "" : path.substring(0, i);
}

function labelOf(path) {
    return path.substring(path.lastIndexOf("/") + 1);
}

function depthOf(path) {
    return path === "" ? 0 : path.split("/").length - 1;
}

// True for the collection itself and everything below it
function within(path, ancestor) {
    return path === ancestor || path.indexOf(ancestor + "/") === 0;
}

function collectionOf(key) {
    return key.substring(0, key.lastIndexOf("/"));
}

// Hidden by a folded collection above it (only collections inside the shown root count)
function hidden(path, collapsed, root) {
    for (var p = parentOf(path); p !== "" && (!root || within(p, root)); p = parentOf(p))
        if (collapsed[p]) return true;
    return false;
}

// Rows of a tree list: a header per collection followed by its own themes, subcollections after that.
// Folded collections hide everything below them. makeTheme(theme, depth) builds a theme row.
// With root set, only that collection and everything below it is listed, starting at depth 0.
function rows(collections, themes, collapsed, makeTheme, root) {
    var result = [];
    var base = root ? depthOf(root) : 0;
    for (var c = 0; c < collections.length; c++) {
        var path = collections[c];
        if (root && !within(path, root)) continue;
        if (hidden(path, collapsed, root)) continue;
        var depth = depthOf(path) - base;
        var below = 0;
        for (var i = 0; i < themes.length; i++)
            if (within(themes[i].collection, path)) below++;
        result.push({ type: "header", name: path, label: labelOf(path), depth: depth, count: below });
        if (collapsed[path]) continue;
        for (var j = 0; j < themes.length; j++)
            if (themes[j].collection === path) result.push(makeTheme(themes[j], depth + 1));
    }
    return result;
}
