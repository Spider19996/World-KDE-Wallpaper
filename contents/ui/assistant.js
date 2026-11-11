.pragma library
.import "params.js" as Params

// Random theme generator behind the assistant. The asked-for basics are fixed (or picked from a short
// list when set to "random"), the rest is rolled; "variation" says how far the numbers may wander from
// their typical values. Only the settings the assistant cares about are returned.

var palettes = ["random", "analogous", "complementary", "triadic", "monochrome", "warm", "cool", "pastel", "neon"];

function pick(list) { return list[Math.floor(Math.random() * list.length) % list.length]; }
function between(a, b) { return a + Math.random() * (b - a); }

// Numbers wander by up to +-50 % at full variation
function jitter(value, variation) { return value * (1 + (Math.random() * 2 - 1) * 0.5 * variation / 100); }
function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)); }

function hslToRgb(h, s, l) {
    h = ((h % 360) + 360) % 360 / 360;
    var q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    function channel(t) {
        t = (t + 1) % 1;
        if (t < 1 / 6) return p + (q - p) * 6 * t;
        if (t < 1 / 2) return q;
        if (t < 2 / 3) return p + (q - p) * (2 / 3 - t) * 6;
        return p;
    }
    return [channel(h + 1 / 3) * 255, channel(h) * 255, channel(h - 1 / 3) * 255];
}

function background(choice, custom) {
    if (choice === "random") choice = pick(["black", "white", "dark", "light"]);
    switch (choice) {
    case "white": return [255, 255, 255];
    case "dark": return hslToRgb(between(0, 360), between(0.25, 0.5), between(0.05, 0.12));
    case "light": return hslToRgb(between(0, 360), between(0.2, 0.4), between(0.91, 0.96));
    case "custom": return Params.toRgb(custom, [30, 30, 60]);
    default: return [0, 0, 0];
    }
}

function hues(kind, base, n) {
    var list = [];
    for (var i = 0; i < n; i++) {
        switch (kind) {
        case "analogous": list.push(base + (i % 2 ? 1 : -1) * Math.ceil(i / 2) * 28); break;
        case "accent": list.push(base + (i % 2 ? 1 : -1) * Math.ceil(i / 2) * 18); break;
        case "complementary": list.push(base + (i % 2) * 180 + Math.floor(i / 2) * 20); break;
        case "triadic": list.push(base + (i % 3) * 120 + Math.floor(i / 3) * 15); break;
        case "monochrome": list.push(base); break;
        case "warm": list.push(between(0, 60)); break;
        case "cool": list.push(between(170, 280)); break;
        default: list.push(between(0, 360));
        }
    }
    return list;
}

// opts: { bg, customBg, palette, colors, rainbow, borders, view, density, speed, explosions, variation, accentHue }
function generate(opts) {
    var v = {}, variation = opts.variation === undefined ? 50 : opts.variation;
    var bg = background(opts.bg, opts.customBg);
    var light = Params.luminance(bg) > 0.5;
    v.BgColor = Params.toHex(bg);
    var kind = opts.palette === "random" ? pick(palettes.slice(1)) : opts.palette;
    var base = kind === "accent" ? opts.accentHue : between(0, 360);

    v.AccentColor = false;
    v.Rainbow = opts.rainbow === true;
    if (!v.Rainbow) {
        var n = clamp(opts.colors, 1, 8);
        v.LineColors = hues(kind, base, n).map(function (h, i) {
            var s = kind === "pastel" ? 0.55 : kind === "neon" ? 1 : between(0.7, 1);
            var l = kind === "pastel" ? (light ? 0.55 : 0.75) : light ? between(0.35, 0.5)
                  : (kind === "monochrome" ? 0.45 + i * 0.1 : between(0.5, 0.62));
            return Params.toHex(hslToRgb(h, s, Math.min(0.9, l)));
        });
    }
    v.LandColor = Params.toHex(light ? hslToRgb(base, 0.25, 0.28) : hslToRgb(base, 0.15, 0.75));
    v.BorderColor = v.LandColor;

    var borders = opts.borders === "random" ? pick(["off", "subtle", "normal", "strong"]) : opts.borders;
    v.ShowBorders = borders !== "off";
    if (borders === "subtle") { v.BorderOpacity = 35; v.BorderWidth = 0.8; }
    if (borders === "normal") { v.BorderOpacity = 60; v.BorderWidth = 1; }
    if (borders === "strong") { v.BorderOpacity = 90; v.BorderWidth = 1.6; }

    var view = opts.view === "random" ? pick(["auto", "flat", "auto"]) : opts.view;
    v.Tilt = view === "flat" ? 90 : 0;

    var density = opts.density === "random" ? pick(["few", "normal", "many"]) : opts.density;
    v.Density = Math.round(clamp(jitter({ few: 25, normal: 50, many: 85 }[density], variation), 5, 100));
    var speed = opts.speed === "random" ? pick(["slow", "normal", "fast"]) : opts.speed;
    v.Speed = Math.round(clamp(jitter({ slow: 60, normal: 100, fast: 170 }[speed], variation), 20, 300));

    var boom = opts.explosions === "random" ? pick(["off", "rare", "often"]) : opts.explosions;
    v.ExplosionChance = boom === "off" ? 0 : Math.round(clamp(jitter(boom === "rare" ? 12 : 40, variation), 1, 100));
    if (boom !== "off") {
        v.ExplosionSparks = Math.round(clamp(jitter(30, variation), 5, 120));
        v.ExplosionSize = Math.round(clamp(jitter(100, variation), 40, 250));
    }
    return v;
}
