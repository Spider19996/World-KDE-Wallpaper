.pragma library

// Live aircraft: reading the data of two free services that need neither a login nor a key,
//  - OpenSky Network (opensky-network.org): every aircraft in the world in one request, position and speed only
//  - adsbdb.com for the route (origin, destination, airline) and the type of single aircraft.
// An aircraft is { hex, call, lat, lon, alt (m), gs (m/s), trk (°), t0 (ms, when the position was valid), type, reg, op,
//                  sq, emerg, mil, label, route, info }.

var M_PER_DEG = 111320;
var FT = 0.3048, KT = 0.514444;

function trim(s) { return String(s === undefined || s === null ? "" : s).replace(/^\s+|\s+$/g, ""); }

// ---- Reading the answers ------------------------------------------------------------------------------

// https://opensky-network.org/api/states/all: [icao24, callsign, country, time_position, last_contact, lon, lat, baro_alt,
// on_ground, velocity, true_track, vertical_rate, sensors, geo_alt, squawk, spi, position_source]
function fromOpenSky(json, fetched) {
    var states = json && json.states ? json.states : [], out = [], server = json && json.time ? json.time : 0;
    for (var i = 0; i < states.length; i++) {
        var s = states[i];
        if (s[8] || typeof s[5] !== "number" || typeof s[6] !== "number") continue;
        var age = server && typeof s[3] === "number" ? Math.max(0, server - s[3]) : 0;
        var sq = trim(s[14]);
        out.push({ hex: String(s[0]).toLowerCase(), call: trim(s[1]), lat: s[6], lon: s[5],
                   alt: typeof s[13] === "number" ? s[13] : (typeof s[7] === "number" ? s[7] : 0),
                   gs: typeof s[9] === "number" ? s[9] : 0, trk: typeof s[10] === "number" ? s[10] : 0,
                   t0: fetched - age * 1000, type: "", reg: "", op: trim(s[2]), sq: sq,
                   emerg: sq === "7700" || sq === "7600" || sq === "7500", mil: false, label: false });
    }
    return out;
}

// adsbdb.com/v0/callsign: the route of a flight number
function parseRoute(json) {
    var r = json && json.response && json.response.flightroute;
    if (!r || !r.origin || !r.destination) return null;
    function airport(a) {
        return { code: a.iata_code || a.icao_code || "", name: a.municipality || a.name || "", lat: a.latitude, lon: a.longitude };
    }
    return { o: airport(r.origin), d: airport(r.destination), airline: r.airline ? trim(r.airline.name) : "" };
}

// adsbdb.com/v0/aircraft: type, registration and owner of one aircraft
function parseAircraft(json) {
    var a = json && json.response && json.response.aircraft;
    if (!a) return null;
    return { type: trim((a.manufacturer ? a.manufacturer + " " : "") + (a.type || "")), code: trim(a.icao_type), reg: trim(a.registration),
             owner: trim(a.registered_owner) };
}

// ---- Keeping ---------------------------------------------------------------------------------

// The short form that is kept on disk (no labels or routes)
function pack(a) {
    return [a.hex, a.call, Math.round(a.lat * 1e4) / 1e4, Math.round(a.lon * 1e4) / 1e4, Math.round(a.alt), Math.round(a.gs * 10) / 10,
            Math.round(a.trk * 10) / 10, a.t0, a.type, a.reg, a.op, a.sq, a.emerg ? 1 : 0, a.mil ? 1 : 0, a.desc || ""];
}
function unpack(v) {
    return { hex: v[0], call: v[1], lat: v[2], lon: v[3], alt: v[4], gs: v[5], trk: v[6], t0: v[7], type: v[8], reg: v[9], op: v[10], sq: v[11],
             emerg: v[12] === 1, mil: v[13] === 1, desc: v[14], label: false };
}

// A new answer replaces the old one: the aircraft was drawn at the old extrapolated place and glides from there to the new one
function carryGlide(a, before, now) {
    var o = { lat: 0, lon: 0 }, n = { lat: 0, lon: 0 };
    position(before, now, o);
    position(a, now, n);
    var dlat = o.lat - n.lat, dlon = o.lon - n.lon;
    if (dlon > 180) dlon -= 360; else if (dlon < -180) dlon += 360;
    if (Math.abs(dlat) < 3 && Math.abs(dlon) < 3 && (Math.abs(dlat) > 0.0005 || Math.abs(dlon) > 0.0005)) a.gl = [dlat, dlon, now];
}

// ---- What to ask for ---------------------------------------------------------------------------------

// Not more than `max` aircraft, as far apart from each other as possible: the largest distance is searched at which
// still `max` aircraft are left when no two are closer than that. Crowded regions are thinned out first, empty ones keep
// every aircraft. The order is fixed (by hex code), so the same ones stay from one update to the next.
function spread(list, max) {
    if (max <= 0 || list.length <= max) return list;
    var order = list.slice().sort(function (a, b) { return hash(a.hex) - hash(b.hex); });
    var n = order.length, xs = new Float32Array(n), ys = new Float32Array(n), i;
    for (i = 0; i < n; i++) {
        xs[i] = order[i].lon * Math.max(0.3, Math.cos(order[i].lat * Math.PI / 180));
        ys[i] = order[i].lat;
    }
    function pick(r) {
        var grid = {}, out = [], r2 = r * r;
        for (var k = 0; k < n; k++) {
            var cx = Math.floor(xs[k] / r), cy = Math.floor(ys[k] / r), ok = true;
            for (var dx = -1; dx <= 1 && ok; dx++) {
                for (var dy = -1; dy <= 1 && ok; dy++) {
                    var cell = grid[(cx + dx) * 4096 + (cy + dy)];
                    if (!cell) continue;
                    for (var m = 0; m < cell.length && ok; m++) {
                        var ex = xs[cell[m]] - xs[k], ey = ys[cell[m]] - ys[k];
                        ok = ex * ex + ey * ey >= r2;
                    }
                }
            }
            if (!ok) continue;
            var key = cx * 4096 + cy;
            (grid[key] = grid[key] || []).push(k);
            out.push(k);
        }
        return out;
    }
    var lo = 0.05, hi = 45, best = pick(lo);
    for (i = 0; i < 10; i++) {
        var mid = Math.sqrt(lo * hi), got = pick(mid);
        if (got.length >= max) { lo = mid; best = got; } else hi = mid;
    }
    var out = [];
    for (i = 0; i < best.length && out.length < max; i++) out.push(order[best[i]]);
    return out;
}

// A flight number of an airline (three letters and digits) has a route to look up, a registration or an air force
// callsign has none
function routable(call) { return /^[A-Z]{3}[0-9]{1,4}[A-Z]{0,2}$/.test(call); }

// ---- Labels -------------------------------------------------------------------------------------------

function hash(s) {
    var h = 2166136261;
    for (var i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0;
    return h;
}

// Marks up to `max` aircraft as labeled: emergencies first, then the ones that were labeled before (so the labels do not
// jump around at every update), then the rest in a fixed but scattered order. Labels keep their distance, so they spread
// over the world instead of piling up where most of the traffic is.
function selectLabels(list, max, before) {
    var order = [], i, j;
    for (i = 0; i < list.length; i++) {
        var a = list[i];
        a.label = false;
        if (!a.call && !a.reg) continue;
        var rank = a.emerg ? 0 : (before[a.hex] ? 1 : 2);
        order.push({ a: a, k: rank * 4294967296 + hash(a.hex) });
    }
    order.sort(function (x, y) { return x.k - y.k; });
    var chosen = [];
    for (var gap = 14; gap >= 0 && chosen.length < max; gap -= 7) {
        for (i = 0; i < order.length && chosen.length < max; i++) {
            var c = order[i].a;
            if (c.label) continue;
            var ok = true;
            for (j = 0; j < chosen.length && ok; j++) {
                var dl = Math.abs(chosen[j].lon - c.lon);
                if (dl > 180) dl = 360 - dl;
                ok = Math.abs(chosen[j].lat - c.lat) > gap || dl > gap * 1.5;
            }
            if (ok || c.emerg) { c.label = true; chosen.push(c); }
        }
    }
    return chosen.length;
}

function flightLevel(m) { return "FL" + ("00" + Math.round(m / FT / 100)).slice(-3); }

// The lines of a label: [callsign and type, route, operator, altitude and speed]; `show` = { route, type, altitude, operator }
function labelLines(a, show, metric) {
    var lines = [], head = a.call || a.reg || a.hex.toUpperCase();
    var code = a.type || (a.info ? a.info.code : "");
    if (show.type && code) head += "  " + code;
    if (a.emerg) head += "  !";
    lines.push(head);
    if (show.route && a.route) lines.push(a.route.o.code + " → " + a.route.d.code + "  (" + a.route.o.name + " → " + a.route.d.name + ")");
    if (show.type && a.info && a.info.type) lines.push(a.info.type + (a.reg || a.info.reg ? "  " + (a.reg || a.info.reg) : ""));
    else if (show.type && a.desc) lines.push(a.desc + (a.reg ? "  " + a.reg : ""));
    else if (show.type && a.reg && a.call) lines.push(a.reg);
    if (show.operator) {
        var op = a.route && a.route.airline ? a.route.airline : (a.info && a.info.owner ? a.info.owner : a.op);
        if (op) lines.push(op);
    }
    if (show.altitude) {
        var kmh = a.gs * 3.6;
        lines.push(flightLevel(a.alt) + "  ·  " + (metric ? Math.round(kmh / 10) * 10 + " km/h" : Math.round(kmh / 1.609344 / 5) * 5 + " mph"));
    }
    return lines;
}

// ---- Movement -----------------------------------------------------------------------------------------

var GLIDE = 10000;    // ms an aircraft takes to glide to its new position after an update

// Where the aircraft is now: its last position moved along its course (a straight line is exact enough for minutes). After
// an update it does not jump to the new position but glides there (a.gl = [dlat, dlon, time] is the distance it still has to go).
function position(a, now, out) {
    var dt = Math.max(0, Math.min(1200, (now - a.t0) / 1000)), d = a.gs * dt, r = a.trk * Math.PI / 180;
    var lat = a.lat + d * Math.cos(r) / M_PER_DEG;
    var lon = a.lon + d * Math.sin(r) / (M_PER_DEG * Math.max(0.15, Math.cos(a.lat * Math.PI / 180)));
    if (a.gl) {
        var u = (now - a.gl[2]) / GLIDE;
        if (u >= 1) a.gl = null;
        else { var e = 1 - Math.max(0, u), w = e * e * (3 - 2 * e); lat += a.gl[0] * w; lon += a.gl[1] * w; }
    }
    out.lat = Math.max(-85, Math.min(85, lat));
    out.lon = ((lon + 540) % 360) - 180;
    return out;
}

// A few aircraft for the preview of a theme (no network)
function demo(now) {
    var routes = [
        { call: "DLH400", type: "B748", reg: "D-ABYT", op: "Lufthansa", o: ["FRA", "Frankfurt", 8.57, 50.03], d: ["JFK", "New York", -73.78, 40.64], t: 0.46 },
        { call: "SIA221", type: "A359", reg: "9V-SMF", op: "Singapore Airlines", o: ["SIN", "Singapore", 103.99, 1.36], d: ["SYD", "Sydney", 151.18, -33.94], t: 0.55 },
        { call: "UAE6", type: "A388", reg: "A6-EVH", op: "Emirates", o: ["LHR", "London", -0.46, 51.47], d: ["DXB", "Dubai", 55.36, 25.25], t: 0.4 },
        { call: "UAL32", type: "B77W", reg: "N2749U", op: "United", o: ["SFO", "San Francisco", -122.38, 37.62], d: ["NRT", "Tokyo", 140.39, 35.77], t: 0.3 }
    ];
    var out = [], i;
    function bearing(lon1, lat1, lon2, lat2) {
        var r = Math.PI / 180, dl = (lon2 - lon1) * r;
        var y = Math.sin(dl) * Math.cos(lat2 * r), x = Math.cos(lat1 * r) * Math.sin(lat2 * r) - Math.sin(lat1 * r) * Math.cos(lat2 * r) * Math.cos(dl);
        return (Math.atan2(y, x) / r + 360) % 360;
    }
    for (i = 0; i < routes.length; i++) {
        var r = routes[i], lon = r.o[2] + (r.d[2] - r.o[2]) * r.t, lat = r.o[3] + (r.d[3] - r.o[3]) * r.t;
        out.push({ hex: "d0000" + i, call: r.call, lat: lat, lon: lon, alt: 11000, gs: 245, trk: bearing(lon, lat, r.d[2], r.d[3]), t0: now,
                   type: r.type, reg: r.reg, op: r.op, sq: "1000", emerg: false, mil: false, label: true,
                   route: { o: { code: r.o[0], name: r.o[1], lon: r.o[2], lat: r.o[3] }, d: { code: r.d[0], name: r.d[1], lon: r.d[2], lat: r.d[3] }, airline: r.op } });
    }
    // The rest on well-known corridors
    var lanes = [[-5, 52, 140, 38, 0.3], [-75, 40, -5, 50, 0.5], [115, 30, 105, 14, 0.5], [-100, 38, -80, 30, 0.5], [77, 28, 55, 25, 0.5], [-45, -20, -60, -30, 0.5],
                 [18, -30, 30, -20, 0.5], [135, 36, 125, 38, 0.5], [10, 45, 25, 40, 0.5], [-120, 35, -100, 40, 0.5]];
    for (i = 0; i < 70; i++) {
        var l = lanes[i % lanes.length], u = ((i * 0.37) % 1), j = ((i * 7) % 11) / 11 - 0.5;
        var lo = l[0] + (l[2] - l[0]) * u + j * 6, la = l[1] + (l[3] - l[1]) * u + j * 4;
        out.push({ hex: "d1" + ("0000" + i).slice(-4), call: "", lat: la, lon: lo, alt: 9000 + (i % 5) * 600, gs: 230, trk: bearing(l[0], l[1], l[2], l[3]) + (i % 2 ? 180 : 0), t0: now,
                   type: "", reg: "", op: "", sq: "1000", emerg: false, mil: false, label: false });
    }
    return out;
}
