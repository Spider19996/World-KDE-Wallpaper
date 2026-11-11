import QtQuick

import "aircraft.js" as Air
import "persist.js" as Memory

// Fetches the live aircraft of the whole world from OpenSky Network, one request every quarter of an hour (anonymous use is
// limited to roughly 100 of them per day); the aircraft are moved along their course in between. Nothing here is drawn;
// `planes` is a new list after every update. Route, airline and type of the labeled aircraft come from adsbdb.com, one request at a time.
Item {
    id: feed
    visible: false

    property bool enabled: false
    property bool active: true               // false while the wallpaper is paused: no requests then
    property int refreshAll: 900
    property int maxPlanes: 2500
    property int labelMax: 20
    property bool lookupRoute: true
    property bool lookupAircraft: true

    property var planes: []
    property double updated: 0               // when the last answer came in (ms)
    property string service: ""              // who delivered it
    // What went wrong, null = nothing: { service, kind: "limit" | "offline" | "http" | "data", status, minutes }. Only set while
    // aircraft are on and the service is in use.
    property var error: null
    property var lookupError: null           // the same for the route and type service
    readonly property bool running: enabled && active

    property var allCache: null              // { time, planes }: the last answer for the world, kept for the next change of settings
    property int generation: 0
    property double holdUntil: 0             // a service asked for patience
    property var routeCache: ({})
    property var aircraftCache: ({})
    property var queue: []
    property var queued: ({})

    function get(url, done) {
        var x = new XMLHttpRequest();
        x.open("GET", url);
        x.timeout = 40000;
        x.onreadystatechange = function () {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            done(x.status, x.responseText, x);
        };
        x.send();
    }

    // The answers are also kept on disk (shared by all screens and by the next start of the desktop), so nothing is fetched
    // again as long as it is fresh enough
    function loadCache(key, maxAge) {
        try {
            var c = JSON.parse(Memory.get(key, "null"));
            if (c && c.planes && Date.now() - c.time < maxAge) return c;
        } catch (e) {}
        return null;
    }
    function saveCache(key, time, list) { Memory.set(key, JSON.stringify({ time: time, planes: list })); }

    Component.onCompleted: {
        // Routes and types known from before
        try {
            var r = JSON.parse(Memory.get("aircraft:lookups", "{}")), now = Date.now(), k;
            for (k in r.routes || {}) if (now - r.routes[k][0] < 12 * 3600000) routeCache[k] = r.routes[k][1];
            for (k in r.aircraft || {}) if (now - r.aircraft[k][0] < 30 * 86400000) aircraftCache[k] = r.aircraft[k][1];
        } catch (e) {}
    }
    property var cacheTimes: ({ routes: {}, aircraft: {} })
    function saveLookups() {
        var out = { routes: {}, aircraft: {} }, k, now = Date.now(), n = 0;
        for (k in routeCache) { out.routes[k] = [cacheTimes.routes[k] || now, routeCache[k]]; if (++n > 1500) break; }
        n = 0;
        for (k in aircraftCache) { out.aircraft[k] = [cacheTimes.aircraft[k] || now, aircraftCache[k]]; if (++n > 1500) break; }
        Memory.set("aircraft:lookups", JSON.stringify(out));
    }

    function parse(text) {
        try { return JSON.parse(text); } catch (e) { return null; }
    }

    // ---- Rounds ---------------------------------------------------------------------------------------
    Timer {
        id: round
        interval: Math.max(60, feed.refreshAll) * 1000
        repeat: true
        running: feed.running
        triggeredOnStart: true
        onTriggered: feed.cycle()
    }

    onMaxPlanesChanged: if (allCache) apply(allCache.planes)
    onLabelMaxChanged: if (running) apply(planes)
    onLookupRouteChanged: if (running) queueLookups()
    onLookupAircraftChanged: if (running) queueLookups()
    onRunningChanged: {
        if (!running) { queue = []; queued = ({}); }
        if (!enabled) { planes = []; error = null; lookupError = null; service = ""; }
    }

    function cycle() {
        generation++;
        if (Date.now() < holdUntil) return;
        fetchAll(generation);
    }

    function refresh() { holdUntil = 0; allCache = null; cycle(); }

    // ---- The whole world --------------------------------------------------------------------------------
    function fetchAll(gen) {
        var maxAge = refreshAll * 900;
        if (!allCache || Date.now() - allCache.time >= maxAge) {
            var kept = loadCache("aircraft:all", 3600000);
            if (kept && (!allCache || kept.time > allCache.time)) allCache = { time: kept.time, planes: kept.planes.map(Air.unpack) };
        }
        if (allCache && Date.now() - allCache.time < maxAge) {
            if (planes.length === 0) apply(allCache.planes);
            return;
        }
        // Old data is better than an empty map while the new data is on its way
        if (planes.length === 0 && allCache && Date.now() - allCache.time < 1800000) apply(allCache.planes);
        get("https://opensky-network.org/api/states/all", function (status, text, xhr) {
            var service = "OpenSky Network";
            if (status === 200) {
                var json = parse(text);
                if (!json || !json.states) { if (gen === generation) error = { service: service, kind: "data", status: 0, minutes: 0 }; return; }
                allCache = { time: Date.now(), planes: Air.fromOpenSky(json, Date.now()) };
                saveCache("aircraft:all", allCache.time, allCache.planes.map(Air.pack));
                apply(allCache.planes);
            } else if (status === 429) {
                var wait = parseInt(xhr.getResponseHeader("X-Rate-Limit-Retry-After-Seconds")) || 3600;
                holdUntil = Date.now() + Math.min(wait, 6 * 3600) * 1000;
                error = { service: service, kind: "limit", status: 429, minutes: Math.ceil(wait / 60) };
            } else {
                error = { service: service, kind: status === 0 ? "offline" : "http", status: status, minutes: 0 };
            }
        });
    }

    // ---- New data -------------------------------------------------------------------------------------
    function apply(list) {
        var before = {}, old = {}, i, a;
        for (i = 0; i < planes.length; i++) { old[planes[i].hex] = planes[i]; if (planes[i].label) before[planes[i].hex] = true; }
        list = Air.spread(list, maxPlanes);
        Air.selectLabels(list, labelMax, before);
        for (i = 0; i < list.length; i++) {
            a = list[i];
            if (old[a.hex] && old[a.hex] !== a) Air.carryGlide(a, old[a.hex], Date.now());
            if (!a.label) continue;
            if (routeCache[a.call]) a.route = routeCache[a.call];
            if (aircraftCache[a.hex]) a.info = aircraftCache[a.hex];
        }
        planes = list;
        updated = Date.now();
        service = "OpenSky Network";
        error = null;
        queueLookups();
    }

    // ---- Route and type of the labeled aircraft -----------------------------------------------------------
    function queueLookups() {
        for (var i = 0; i < planes.length; i++) {
            var a = planes[i];
            if (!a.label) continue;
            if (lookupRoute && Air.routable(a.call) && !(a.call in routeCache) && !queued["c" + a.call]) {
                queued["c" + a.call] = true;
                queue.push({ kind: "route", key: a.call });
            }
            if (lookupAircraft && !(a.type && a.reg) && /^[0-9a-f]{6}$/.test(a.hex) && !(a.hex in aircraftCache) && !queued["h" + a.hex]) {
                queued["h" + a.hex] = true;
                queue.push({ kind: "aircraft", key: a.hex });
            }
        }
        if (queue.length > 0 && !lookups.running) lookups.start();
    }

    Timer {
        id: lookups
        interval: 800
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!feed.running || feed.queue.length === 0) { stop(); feed.saveLookups(); return; }
            feed.lookup(feed.queue.shift());
        }
    }

    function lookup(item) {
        var url = "https://api.adsbdb.com/v0/" + (item.kind === "route" ? "callsign/" : "aircraft/") + encodeURIComponent(item.key);
        get(url, function (status, text) {
            var json = status === 200 ? parse(text) : null;
            // 404: nothing known, which is remembered too so it is not asked again and again
            if (status !== 200 && status !== 404) {
                delete queued[(item.kind === "route" ? "c" : "h") + item.key];
                lookupError = { service: "adsbdb.com", kind: status === 0 ? "offline" : (status === 429 ? "limit" : "http"), status: status, minutes: 0 };
                if (status === 429) queue = [];
                return;
            }
            lookupError = null;
            if (item.kind === "route") {
                var r = json ? Air.parseRoute(json) : null;
                routeCache[item.key] = r;
                cacheTimes.routes[item.key] = Date.now();
                if (r) for (var i = 0; i < planes.length; i++) if (planes[i].call === item.key && planes[i].label) planes[i].route = r;
            } else {
                var ac = json ? Air.parseAircraft(json) : null;
                aircraftCache[item.key] = ac;
                cacheTimes.aircraft[item.key] = Date.now();
                if (ac) for (var k = 0; k < planes.length; k++) if (planes[k].hex === item.key) planes[k].info = ac;
            }
        });
    }
}
