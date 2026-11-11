import QtQuick
import QtTest

import "../contents/ui/store.js" as Store
import "../contents/ui/params.js" as Params
import "../contents/ui/selection.js" as Sel
import "../contents/ui/builtin.js" as Builtin
import "../contents/ui/geo.js" as Geo
import "../contents/ui/countries.js" as Countries
import "../contents/ui/aircraft.js" as Air

// Logic tests for the themes: inheritance, editing, selection, import. Run with tools/test-package.sh.
TestCase {
    name: "Themes"

    function test_builtin_themes_are_complete() {
        var cat = Store.catalog(Store.empty(), false);
        verify(cat.themes.length > 0);
        cat.themes.forEach(function (t) {
            var def = Params.defaults();
            for (var k in def) verify(t.config.hasOwnProperty(k), t.key + " lacks " + k);
            verify(t.config.LineColors.length >= 1, t.key);
            verify(/^#[0-9a-f]{6}$/i.test(t.config.BgColor), t.key);
        });
        verify(cat.themes.some(function (t) { return t.key === Builtin.defaultKey; }), "default theme exists");
    }

    function test_builtin_collections_have_themes_and_parents() {
        var cat = Store.catalog(Store.empty(), false);
        cat.collections.forEach(function (c) {
            if (c.indexOf("/") >= 0) verify(cat.collections.indexOf(c.substring(0, c.lastIndexOf("/"))) >= 0, c + " has no parent");
        });
        verify(cat.themes.some(function (t) { return t.config.ExplosionChance > 0; }), "explosions are shown in the built-in themes");
        verify(cat.themes.length >= 50, "a good number of built-in themes");
    }

    function test_builtin_themes_differ() {
        var cat = Store.catalog(Store.empty(), false);
        var seen = {};
        cat.themes.filter(function (t) { return t.key.indexOf("OLED/Calm/") === 0 && !t.config.AccentColor; }).forEach(function (t) {
            var sig = JSON.stringify([t.config.LineColors, t.config.Rainbow, t.config.Speed, t.config.Density, t.config.ArcHeight, t.config.NodeSize, t.config.Projection]);
            verify(!seen[sig], t.key + " looks like another theme");
            seen[sig] = true;
        });
    }

    function test_inheritance_and_source() {
        var ud = Store.addCollection(Store.empty(), "Mine");
        ud = Store.setCollectionValue(ud, "Mine", "BgColor", "#112233");
        ud = Store.addTheme(ud, "Mine", "A", { Rainbow: true });
        var t = Store.catalog(ud, true).themes[0];
        compare(t.config.BgColor, "#112233");
        compare(t.config.Rainbow, true);
        compare(Store.source(ud, "theme", "Mine/A", "BgColor"), "Mine");
        compare(Store.source(ud, "theme", "Mine/A", "Rainbow"), "own");
        compare(Store.source(ud, "theme", "Mine/A", "Density"), "");
        ud = Store.resetThemeValue(ud, "Mine/A", "Rainbow");
        compare(Store.catalog(ud, true).themes[0].config.Rainbow, false);
    }

    function test_rename_move_delete() {
        var ud = Store.addTheme(Store.addCollection(Store.empty(), "Mine"), "Mine", "A", { Density: 20 });
        ud = Store.renameTheme(ud, "Mine/A", "Mine/B");
        verify(ud.themes["Mine/B"] && !ud.themes["Mine/A"]);
        ud = Store.moveTheme(ud, "Mine/B", "Other");
        verify(ud.themes["Other/B"] && !ud.themes["Mine/B"]);
        compare(ud.themes["Other/B"].Density, 20);
        ud = Store.deleteCollection(Store.addCollection(ud, "Other"), "Other");
        compare(Object.keys(ud.themes).length, 0);
    }

    function test_builtin_cannot_be_changed_by_import() {
        var r = Store.importEntries(Store.empty(), [
            { path: "./OLED/Red.json", values: { Density: 1 } },
            { path: "./Mine/_collection.json", values: { BgColor: "#010203" } },
            { path: "./Mine/Sub/New.json", values: { Rainbow: true, Tilt: 999, Nonsense: 1 } },
            { path: "./README.json", values: {} }
        ]);
        compare(r.count, 2);
        verify(!r.ud.themes["OLED/Red"]);
        compare(r.ud.collections["Mine"].BgColor, "#010203");
        compare(r.ud.themes["Mine/Sub/New"].Tilt, 90, "values are limited to the allowed range");
        verify(!r.ud.themes["Mine/Sub/New"].hasOwnProperty("Nonsense"));
        verify(r.ud.collections["Mine/Sub"] !== undefined, "parents of an imported theme exist");
    }

    function test_selection() {
        var cat = Store.catalog(Store.empty(), false);
        compare(Store.selectedThemes(cat, []).length, 1, "nothing ticked = default theme");
        compare(Store.selectedThemes(cat, []).length > 0 ? Store.selectedThemes(cat, [])[0].key : "", Builtin.defaultKey);
        var some = Store.selectedThemes(cat, ["c:OLED/Flat"]);
        compare(some.length, 18, "flat and flat with explosions");
        var sel = Sel.setTheme(["c:OLED/Calm"], "OLED/Calm/Classic", "OLED/Calm", false, { collections: cat.collections, themes: cat.themes });
        verify(sel.indexOf("t:OLED/Calm/Ocean") >= 0 && sel.indexOf("t:OLED/Calm/Classic") < 0, "unticking one theme keeps the others");
    }

    function test_values_are_sanitized() {
        var v = Params.sanitize({ Tilt: 500, LandColor: "bad", Density: "x", Projection: "foo", LineColors: ["#ff0000", "nope"] });
        compare(v.Tilt, 90);
        verify(!v.hasOwnProperty("LandColor"));
        verify(!v.hasOwnProperty("Density"));
        verify(!v.hasOwnProperty("Projection"));
        compare(v.LineColors.length, 1);
    }

    // The map itself
    function test_map_data_is_there() {
        verify(Geo.polys.length > 50, "coast lines");
        verify(Geo.borders.length > 100, "country borders");
    }

    function test_country_names() {
        verify(Countries.list.length > 150, "countries");
        var de = Countries.languages.indexOf("de");
        Countries.list.forEach(function (c) {
            compare(c[3].length, Countries.languages.length);
            verify(c[3].every(function (n) { return n.length > 0; }), "a name is missing for " + c[3][0]);
            verify(c[0] >= -180 && c[0] <= 180 && c[1] >= -90 && c[1] <= 90);
        });
        verify(Countries.list.some(function (c) { return c[3][de] === "Deutschland"; }), "German names");
        var t = Store.catalog(Store.empty(), false).themes.filter(function (x) { return x.key === "OLED/Flat/Calm/Classic"; })[0];
        verify(t.config.ShowCountryNames, "flat themes show the names");
        verify(t.config.CountryNameColor.length === 7);
    }

    // The cities the data stream flies between
    function test_cities_are_spread_over_the_world() {
        verify(Geo.cities.length >= 150, "enough cities");
        compare(Geo.regions.length, 10);
        Geo.regions.forEach(function (r, i) { verify(r.cities.length >= 9, "region " + i + " has enough cities"); });
        for (var i = 0; i < Geo.cities.length; i++) {
            var c = Geo.cities[i];
            verify(c[0] >= -180 && c[0] <= 180 && c[1] >= -57 && c[1] <= 84, "city " + i + " is on the map");
            for (var j = i + 1; j < Geo.cities.length; j++)
                verify(Math.hypot(c[0] - Geo.cities[j][0], c[1] - Geo.cities[j][1]) > 2.2, "cities " + i + " and " + j + " are too close");
        }
    }

    // Every quarter of the map has cities, at any number of cities
    function test_cities_in_every_band() {
        [100, 50, 20].forEach(function (pct) {
            Geo.useCities(pct);
            var bands = [0, 0, 0, 0];
            Geo.active.forEach(function (id) {
                var lat = Geo.cities[id][1];
                bands[lat >= 55 ? 0 : lat >= 25 ? 1 : lat >= -5 ? 2 : 3]++;
            });
            bands.forEach(function (n, b) { verify(n >= (pct === 20 ? 4 : 10), "band " + b + " has " + n + " cities at " + pct + " %"); });
        });
        Geo.useCities(100);
    }

    function test_fewer_cities_are_a_subset() {
        Geo.useCities(100);
        var all = Geo.active.length;
        Geo.useCities(40);
        verify(Geo.active.length < all * 0.6 && Geo.active.length > all * 0.3, "about 40 % of " + all + " is " + Geo.active.length);
        Geo.useCities(100);
    }

    function test_aircraft_opensky() {
        var json = { time: 1000, states: [
            ["abc123", "DLH400  ", "Germany", 990, 995, 8.5, 50.0, 11000, false, 240, 270, 0, null, 11100, "1000", false, 0],
            ["def456", "GND1", "Italy", 990, 995, 9, 45, 0, true, 0, 0, 0, null, 0, null, false, 0],
            ["000001", "NOPOS", "X", null, 995, null, null, 0, false, 0, 0, 0, null, 0, null, false, 0] ] };
        var l = Air.fromOpenSky(json, 50000);
        compare(l.length, 1);
        compare(l[0].call, "DLH400");
        compare(l[0].t0, 40000);
        compare(l[0].alt, 11100);
    }

    function test_aircraft_pack() {
        var l = Air.fromOpenSky({ time: 10, states: [["4d2300", "RYR26GP ", "Malta", 8, 9, 8, 50, 11000, false, 240, 318, 0, null, 11100, "7700", false, 0]] }, 10000);
        verify(l[0].emerg);
        var back = Air.unpack(Air.pack(l[0]));
        compare(back.call, "RYR26GP");
        compare(back.hex, "4d2300");
        verify(back.emerg);
        compare(back.t0, l[0].t0);
    }

    function test_aircraft_movement_and_labels() {
        var a = { lat: 0, lon: 0, gs: 250, trk: 90, t0: 0 }, out = { lat: 0, lon: 0 };
        Air.position(a, 400000, out);                  // 100 km east
        verify(Math.abs(out.lon - 0.898) < 0.01 && Math.abs(out.lat) < 0.001, "lon " + out.lon);
        Air.position({ lat: 0, lon: 179.9, gs: 250, trk: 90, t0: 0 }, 400000, out);
        verify(out.lon < 0, "wraps over the date line");
        var b = { lat: 0, lon: 1, t0: 900000, gs: 0, trk: 0 };
        Air.carryGlide(b, { lat: 0, lon: 0, t0: 0, gs: 0, trk: 0 }, 900000);
        verify(b.gl && Math.abs(b.gl[1] + 1) < 0.01, "glides from the old place to the new one");
        Air.position(b, 900000, out);                  // at the start of the glide it is still at the old place
        verify(Math.abs(out.lon) < 0.01, "starts at the old place: " + out.lon);
        Air.position(b, 900000 + 11000, out);
        verify(Math.abs(out.lon - 1) < 0.001, "arrives at the new place: " + out.lon);
        var list = [];
        for (var i = 0; i < 50; i++) list.push({ hex: "a" + i, call: "X" + i, reg: "", emerg: i === 40, label: false, lat: (i % 7) * 10, lon: i * 7 - 170 });
        compare(Air.selectLabels(list, 10, {}), 10);
        verify(list[40].label, "an emergency is always labeled");
        compare(list.filter(function (x) { return x.label; }).length, 10);
        var lines = Air.labelLines({ hex: "abc", call: "UAE6", type: "A388", alt: 11277, gs: 250, reg: "A6-EVH", op: "",
                                     route: { o: { code: "LHR", name: "London" }, d: { code: "DXB", name: "Dubai" }, airline: "Emirates" } },
                                   { route: true, type: true, altitude: true, operator: true }, true);
        compare(lines[0], "UAE6  A388");
        verify(lines[1].indexOf("LHR → DXB") === 0);
        verify(lines.join("|").indexOf("FL370") > 0 && lines.join("|").indexOf("900 km/h") > 0, lines.join("|"));
        var crowd = [];
        for (var c = 0; c < 100; c++) crowd.push({ hex: "c" + c, lat: 40 + (c % 3) * 0.1, lon: -100 + (c % 5) * 0.1 });
        crowd.push({ hex: "r1", lat: 60, lon: 90 });
        crowd.push({ hex: "r2", lat: -30, lon: 20 });
        var few = Air.spread(crowd, 5);
        compare(few.length, 5);
        verify(few.some(function (x) { return x.hex === "r1"; }) && few.some(function (x) { return x.hex === "r2"; }), "the lonely ones stay");
        compare(Air.spread(crowd, 0).length, 102);
        compare(Air.spread(crowd, 500).length, 102);
        verify(Air.routable("DLH400") && !Air.routable("N12345"));
        verify(Air.demo(0).length > 20);
    }
}
