.pragma library

// Marks a text for translation; the QML side passes it through i18n() when it is shown
function N_(text) { return text; }

// Every setting a theme can change, in the order of the theme manager.
// type: color | colors | bool | int | real | enum | text
var sections = [
    { title: N_("Colors"), params: [
        { key: "BgColor", label: N_("Background"), type: "color", def: "#000000" },
        { key: "LandColor", label: N_("Map"), type: "color", def: "#bec8d7" },
        { key: "LineColors", label: N_("Line colors"), type: "colors", def: ["#ff3c32"] },
        { key: "AccentColor", label: N_("Use the Plasma accent color for the lines"), type: "bool", def: false },
        { key: "Rainbow", label: N_("Rainbow (every connection gets its own color)"), type: "bool", def: false },
        { key: "RainbowSaturation", label: N_("Rainbow saturation"), type: "real", min: 0, max: 1, step: 0.05, def: 0.6 },
        { key: "RainbowLightness", label: N_("Rainbow lightness (lower on bright backgrounds)"), type: "real", min: 0.1, max: 0.9, step: 0.05, def: 0.58 }
    ] },
    { title: N_("Map"), params: [
        { key: "MapOpacity", label: N_("Coast line opacity (%)"), type: "real", min: 5, max: 100, step: 1, def: 70 },
        { key: "MapLineWidth", label: N_("Coast line width (px)"), type: "real", min: 0.3, max: 6, step: 0.1, def: 1.4 },
        { key: "ShowBorders", label: N_("Show country borders"), type: "bool", def: false },
        { key: "BorderColor", label: N_("Border color"), type: "color", def: "#bec8d7" },
        { key: "BorderWidth", label: N_("Border width (px)"), type: "real", min: 0.2, max: 6, step: 0.1, def: 1 },
        { key: "BorderOpacity", label: N_("Border opacity (%)"), type: "real", min: 5, max: 100, step: 1, def: 60 },
        { key: "ShowCountryNames", label: N_("Show country names"), type: "bool", def: false },
        { key: "CountryNameLanguage", label: N_("Language of the names"), type: "enum", def: "auto",
          options: [ { value: "auto", text: N_("System language") }, { value: "en", text: N_("English") }, { value: "de", text: "Deutsch" },
                     { value: "fr", text: "Français" }, { value: "es", text: "Español" }, { value: "it", text: "Italiano" },
                     { value: "pt", text: "Português" }, { value: "ru", text: "Русский" }, { value: "ja", text: "日本語" },
                     { value: "zh", text: "中文" } ] },
        { key: "CountryNameColor", label: N_("Color of the names"), type: "color", def: "#bec8d7" },
        { key: "CountryNameSize", label: N_("Size of the names (px)"), type: "real", min: 6, max: 30, step: 0.5, def: 12 },
        { key: "CountryNameOpacity", label: N_("Opacity of the names (%)"), type: "real", min: 5, max: 100, step: 1, def: 55 },
        { key: "ShowGraticule", label: N_("Faint grid of longitudes and latitudes"), type: "bool", def: true }
    ] },
    { title: N_("Data stream"), params: [
        { key: "Density", label: N_("Density (%)"), type: "real", min: 0, max: 100, step: 1, def: 50 },
        { key: "Speed", label: N_("Speed (%)"), type: "real", min: 20, max: 300, step: 5, def: 100 },
        { key: "ArcHeight", label: N_("Arc height (%)"), type: "real", min: 20, max: 250, step: 5, def: 100 },
        { key: "ArcOpacity", label: N_("Opacity of the arcs (%)"), type: "real", min: 0, max: 100, step: 1, def: 28 },
        { key: "ExplosionChance", label: N_("Explosion on impact (chance in %)"), type: "real", min: 0, max: 100, step: 1, def: 0 },
        { key: "ExplosionSparks", label: N_("Sparks per explosion"), type: "int", min: 0, max: 200, def: 30 },
        { key: "ExplosionSize", label: N_("Size of the explosions (%)"), type: "real", min: 30, max: 300, step: 5, def: 100 },
        { key: "Cities", label: N_("Cities (% of the places)"), type: "real", min: 10, max: 100, step: 5, def: 70 },
        { key: "NodeSize", label: N_("Size of the nodes (%)"), type: "real", min: 20, max: 300, step: 5, def: 100 }
    ] },
    { title: N_("Aircraft"), params: [
        { key: "ShowAircraft", label: N_("Show live aircraft (needs the internet)"), type: "bool", def: false },
        { key: "AircraftRefreshMinutes", label: N_("Update the aircraft every (minutes)"), type: "int", min: 10, max: 120, def: 15 },
        { key: "AircraftMax", label: N_("Most aircraft shown, as far apart as possible (0 = all)"), type: "int", min: 0, max: 30000, def: 2500 },
        { key: "AircraftColor", label: N_("Aircraft color"), type: "color", def: "#ffd23c" },
        { key: "AircraftLabelColor", label: N_("Color of the labeled aircraft and their text"), type: "color", def: "#ff4a3c" },
        { key: "AircraftSize", label: N_("Size of the aircraft (%)"), type: "real", min: 30, max: 300, step: 5, def: 100 },
        { key: "AircraftOpacity", label: N_("Opacity of the aircraft (%)"), type: "real", min: 10, max: 100, step: 1, def: 85 },
        { key: "AircraftRoutes", label: N_("Dashed route of the labeled aircraft"), type: "bool", def: true },
        { key: "AircraftLabels", label: N_("Labels (switch off to show no text at all)"), type: "bool", def: true },
        { key: "AircraftLabelMax", label: N_("Labeled aircraft"), type: "int", min: 0, max: 100, def: 15 },
        { key: "AircraftLabelSize", label: N_("Size of the labels (px)"), type: "real", min: 6, max: 30, step: 0.5, def: 11 },
        { key: "AircraftInfoRoute", label: N_("Label: departure and destination"), type: "bool", def: true },
        { key: "AircraftInfoType", label: N_("Label: aircraft type and registration"), type: "bool", def: true },
        { key: "AircraftInfoOperator", label: N_("Label: airline or owner"), type: "bool", def: true },
        { key: "AircraftInfoAltitude", label: N_("Label: altitude and speed"), type: "bool", def: true }
    ] },
    { title: N_("View"), params: [
        { key: "Projection", label: N_("Map projection"), type: "enum", def: "miller",
          options: [ { value: "miller", text: N_("Miller (poles not squashed)") },
                     { value: "equirect", text: N_("Equirectangular (plain)") } ] },
        { key: "Tilt", label: N_("Tilt (°, 0 = automatic, 90 = flat)"), type: "int", min: 0, max: 90, def: 0 },
        { key: "MapScale", label: N_("Map size (%)"), type: "real", min: 40, max: 100, step: 1, def: 100 },
        { key: "VerticalPos", label: N_("Vertical position (%)"), type: "real", min: 0, max: 100, step: 1, def: 50 },
    ] }
];

function tabs() {
    var t = [];
    for (var s = 0; s < sections.length; s++) t.push(sections[s].title);
    return t;
}

function defaults() {
    var c = {};
    for (var s = 0; s < sections.length; s++)
        for (var p = 0; p < sections[s].params.length; p++) {
            var d = sections[s].params[p].def;
            c[sections[s].params[p].key] = Array.isArray(d) ? d.slice() : d;
        }
    return c;
}

var _index = null;
function param(key) {
    if (!_index) {
        _index = {};
        for (var s = 0; s < sections.length; s++)
            for (var p = 0; p < sections[s].params.length; p++) _index[sections[s].params[p].key] = sections[s].params[p];
    }
    return _index[key];
}

// Keeps only known keys with the right type, so a broken config cannot break the scene
function sanitize(values) {
    var out = {};
    for (var k in values) {
        var def = param(k), v = values[k];
        if (!def) continue;
        switch (def.type) {
        case "color": if (/^#[0-9a-f]{6}$/i.test(String(v))) out[k] = String(v); break;
        case "colors":
            if (Array.isArray(v)) {
                var l = v.filter(function (c) { return /^#[0-9a-f]{6}$/i.test(String(c)); });
                if (l.length > 0) out[k] = l;
            }
            break;
        case "bool": out[k] = v === true || v === "true"; break;
        case "int": case "real":
            var n = Number(v);
            if (isFinite(n)) out[k] = Math.max(def.min, Math.min(def.max, n));
            break;
        case "enum":
            if (def.options.some(function (o) { return o.value === v; })) out[k] = v;
            break;
        case "text": out[k] = String(v).substring(0, 200); break;
        default: out[k] = v;
        }
    }
    return out;
}

// "#rrggbb" <-> [r, g, b]
function toRgb(hex, fallback) {
    var m = /^#?([0-9a-f]{6})$/i.exec(String(hex).trim());
    if (!m) return fallback || [0, 0, 0];
    var v = parseInt(m[1], 16);
    return [(v >> 16) & 255, (v >> 8) & 255, v & 255];
}

function toHex(rgb) {
    function h(n) { var s = Math.max(0, Math.min(255, Math.round(n))).toString(16); return s.length < 2 ? "0" + s : s; }
    return "#" + h(rgb[0]) + h(rgb[1]) + h(rgb[2]);
}

function luminance(rgb) {
    return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
}
