.pragma library

// Built-in collections hold defaults for everything below them, themes only list what they change.
// Themes are keyed "<collection>/<name>". These cannot be edited, "Duplicate" makes an own copy.
// Like in Substrate there are two collections (OLED black and Bright). Each has the variants Calm and Explosions, and
// Flat with the same two inside. Every look has a character of its own: colors, speed, density, arc height, node size, map style.

var collections = {
    "OLED": { BgColor: "#000000" },
    "OLED/Calm": {},
    "OLED/Explosions": { ExplosionChance: 35, ExplosionSparks: 36 },
    "OLED/Flat": { Tilt: 90, ShowBorders: true, ShowCountryNames: true },
    "OLED/Flat/Calm": {},
    "OLED/Flat/Explosions": { ExplosionChance: 35, ExplosionSparks: 36 },
    "OLED/Flights": { ShowAircraft: true, AircraftLabelMax: 15 },
    "OLED/Flights/Flat": { Tilt: 90, ShowBorders: true },
    "Bright": { BgColor: "#eef1f6", LandColor: "#2a3550", MapOpacity: 85, BorderColor: "#2a3550", ArcOpacity: 45,
                RainbowLightness: 0.4, RainbowSaturation: 0.8, CountryNameColor: "#2a3550", AircraftColor: "#c98a00", AircraftLabelColor: "#d6243a" },
    "Bright/Calm": {},
    "Bright/Explosions": { ExplosionChance: 35, ExplosionSparks: 36 },
    "Bright/Flat": { Tilt: 90, ShowBorders: true, ShowCountryNames: true },
    "Bright/Flat/Calm": {},
    "Bright/Flat/Explosions": { ExplosionChance: 35, ExplosionSparks: 36 },
    "Bright/Flights": { ShowAircraft: true, AircraftLabelMax: 15 },
    "Bright/Flights/Flat": { Tilt: 90, ShowBorders: true },
};

// name: { dark: values on black, bright: values on a light background, both: what the look does everywhere,
//         boom: how it explodes in the Explosions variants }
var looks = {
    "Classic": {
        dark: { LandColor: "#bec8d7", LineColors: ["#ff3c32"] },
        bright: { LineColors: ["#e0243a"] },
        both: { CountryNameSize: 12, CountryNameOpacity: 55, Cities: 70 }, boom: { ExplosionChance: 35, ExplosionSparks: 36 }
    },
    "Ocean": {
        dark: { LandColor: "#9db8cc", LineColors: ["#28b4ff", "#00e5c8"] },
        bright: { BgColor: "#e6eff7", LandColor: "#1f3b57", BorderColor: "#1f3b57", LineColors: ["#0a74d6", "#00a896"] },
        both: { CountryNameSize: 12, CountryNameOpacity: 50, Cities: 60, Speed: 80, ArcHeight: 130, Density: 45, NodeSize: 110 }, boom: { ExplosionChance: 28, ExplosionSparks: 30, ExplosionSize: 110 }
    },
    "Fire": {
        dark: { LandColor: "#d7c8aa", LineColors: ["#ff6a28", "#ffd23c", "#ff3c32"] },
        bright: { BgColor: "#f7efe6", LandColor: "#4a3a28", BorderColor: "#4a3a28", LineColors: ["#e2571a", "#d99a00", "#d6322a"] },
        both: { CountryNameSize: 12, CountryNameOpacity: 60, Cities: 85, Speed: 140, Density: 70, NodeSize: 130, ArcOpacity: 34 }, boom: { ExplosionChance: 55, ExplosionSparks: 50, ExplosionSize: 130 }
    },
    "Forest": {
        dark: { LandColor: "#a9c9b0", LineColors: ["#3cff78", "#b4ff3c"] },
        bright: { BgColor: "#eaf3ea", LandColor: "#234a2f", BorderColor: "#234a2f", LineColors: ["#12a150", "#6fae0a"] },
        both: { CountryNameSize: 13, CountryNameOpacity: 50, Cities: 50, Speed: 70, Density: 38, ArcHeight: 70, MapLineWidth: 1.8, NodeSize: 120 }, boom: { ExplosionChance: 25, ExplosionSparks: 28, ExplosionSize: 90 }
    },
    "Ice": {
        dark: { LandColor: "#d4e6f2", LineColors: ["#bfe9ff", "#ffffff"] },
        bright: { BgColor: "#eef4f8", LandColor: "#3b5568", BorderColor: "#3b5568", LineColors: ["#3a8fc4", "#6aa9c8"] },
        both: { CountryNameSize: 11, CountryNameOpacity: 42, Cities: 35, Speed: 60, MapOpacity: 55, MapLineWidth: 1, ArcOpacity: 40, NodeSize: 80, Density: 42 }, boom: { ExplosionChance: 15, ExplosionSparks: 22, ExplosionSize: 80 }
    },
    "Sunset": {
        dark: { LandColor: "#d9bfc4", LineColors: ["#ff8a3c", "#ff3c8a", "#a03cff"] },
        bright: { BgColor: "#f7ece9", LandColor: "#5a3340", BorderColor: "#5a3340", LineColors: ["#e8590c", "#d6246e", "#7a2fd1"] },
        both: { CountryNameSize: 12, CountryNameOpacity: 55, Cities: 60, ArcHeight: 170, Speed: 90, Density: 52 }, boom: { ExplosionChance: 40, ExplosionSparks: 40, ExplosionSize: 120 }
    },
    "Pastel": {
        dark: { LandColor: "#cfc9dd", LineColors: ["#ff9ec7", "#9ee7ff", "#c9ff9e", "#ffe59e"] },
        bright: { BgColor: "#f4f0f7", LandColor: "#5b5470", BorderColor: "#5b5470", ArcOpacity: 55,
                  LineColors: ["#e0709f", "#4aa8d8", "#6bbf5a", "#d9a21a"] },
        both: { CountryNameSize: 13, CountryNameOpacity: 62, Cities: 55, NodeSize: 170, ArcOpacity: 38, Density: 55, MapOpacity: 60, MapLineWidth: 1.2 }, boom: { ExplosionChance: 30, ExplosionSparks: 24, ExplosionSize: 90 }
    },
    "Rainbow": {
        dark: { Rainbow: true, RainbowSaturation: 0.75 },
        bright: { BgColor: "#f5f5f5", LandColor: "#333333", BorderColor: "#333333", Rainbow: true },
        both: { CountryNameSize: 12, CountryNameOpacity: 55, Cities: 90, Density: 65, Speed: 120 }, boom: { ExplosionChance: 45, ExplosionSparks: 40, ExplosionSize: 110 }
    },
    "Cobweb": {
        dark: { LandColor: "#8f99a8", LineColors: ["#9fb4d6"] },
        bright: { BgColor: "#f2f2f2", LandColor: "#444444", BorderColor: "#444444", LineColors: ["#4a6fa5"] },
        both: { ShowCountryNames: true, CountryNameSize: 10, CountryNameOpacity: 45, Cities: 100, Projection: "equirect", ShowBorders: true, BorderOpacity: 70, MapOpacity: 45, Density: 90, ArcOpacity: 16, ArcHeight: 45,
                 NodeSize: 60, Speed: 90 }, boom: { ExplosionChance: 20, ExplosionSparks: 16, ExplosionSize: 70 }
    }
};

var themes = {};
(function () {
    function merge() {
        var out = {};
        for (var i = 0; i < arguments.length; i++) for (var k in arguments[i]) out[k] = arguments[i][k];
        return out;
    }
    ["OLED", "Bright"].forEach(function (mode) {
        var tone = mode === "OLED" ? "dark" : "bright";
        Object.keys(looks).forEach(function (name) {
            var look = looks[name];
            // The names are drawn in the color of the map
            if (look[tone].LandColor) look = { dark: look.dark, bright: look.bright, both: merge({ CountryNameColor: look[tone].LandColor }, look.both), boom: look.boom };
            themes[mode + "/Calm/" + name] = merge(look[tone], look.both);
            themes[mode + "/Explosions/" + name] = merge(look[tone], look.both, look.boom);
            themes[mode + "/Flat/Calm/" + name] = merge(look[tone], look.both);
            themes[mode + "/Flat/Explosions/" + name] = merge(look[tone], look.both, look.boom);
            // The flights are the show here: a calmer data stream, no explosions, 
            var quiet = { Density: Math.round((look.both.Density || 50) * 0.45), ExplosionChance: 0, ArcOpacity: Math.min(look.both.ArcOpacity || 28, 22) };
            themes[mode + "/Flights/" + name] = merge(look[tone], look.both, quiet);
            themes[mode + "/Flights/Flat/" + name] = merge(look[tone], look.both, quiet);
        });
    });
    // The color of the Plasma accent color scheme
    themes["OLED/Calm/Accent"] = { LandColor: "#bec8d7", AccentColor: true };
})();

// The theme shown when nothing is ticked
var defaultKey = "OLED/Calm/Classic";
