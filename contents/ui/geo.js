.import "coast.js" as Coast
.import "borders.js" as Borders

// Flat equirectangular map (x = lon/180, z = lat/90*0.5) on a plane, tilted towards the viewer, perspective projected.
var W = 0, H = 0, F = 1, D = 2.2, sinT = 0.5, cosT = 0.86, cx = 0, cy = 0;
var P = { x: 0, y: 0, s: 0 };
var PROBES = [[-180, 84, 0], [180, 84, 0], [-180, -57, 0], [180, -57, 0], [0, 70, 0.3], [-90, 70, 0.22], [90, 70, 0.22]];

function setTilt(deg) {
    var t = deg * Math.PI / 180;
    sinT = Math.sin(t); cosT = Math.cos(t);
}

// Bounding box of the map plus head room for the arcs, at F = 1 (everything is proportional to F)
function measure() {
    F = 1; cx = 0; cy = 0;
    var b = { minX: 1e9, maxX: -1e9, minY: 1e9, maxY: -1e9 };
    for (var i = 0; i < PROBES.length; i++) {
        proj(PROBES[i][0], PROBES[i][1], PROBES[i][2]);
        b.minX = Math.min(b.minX, P.x); b.maxX = Math.max(b.maxX, P.x);
        b.minY = Math.min(b.minY, P.y); b.maxY = Math.max(b.maxY, P.y);
    }
    return b;
}

// Auto tilt: the screen's aspect ratio decides. A wide screen gets a flatter view, a 16:9 screen a steeper one,
// so the map fills the screen either way.
function autoTilt(w, h) {
    var target = (w * 0.97) / (h * 0.95), best = 45, bestErr = 1e9;
    for (var deg = 25; deg <= 70; deg++) {
        setTilt(deg);
        var b = measure(), err = Math.abs(Math.log((b.maxX - b.minX) / (b.maxY - b.minY) / target));
        if (err < bestErr) { bestErr = err; best = deg; }
    }
    return best;
}

// Fits the whole map (plus head room for the arcs) into the screen, keeps the 2:1 aspect ratio of the map.
// tiltDeg 0 = auto. scalePct: share of the largest possible size. vposPct: place in the free vertical space.
function layout(w, h, tiltDeg, scalePct, vposPct, projectionName) {
    W = w; H = h;
    projection = projectionName === "equirect" ? "equirect" : "miller";
    setTilt(tiltDeg > 0 ? tiltDeg : autoTilt(w, h));
    var b = measure();
    var fit = Math.min(w * 0.97 / (b.maxX - b.minX), h * 0.95 / (b.maxY - b.minY));
    F = fit * Math.min(100, scalePct) / 100;
    cx = w / 2 - (b.minX + b.maxX) / 2 * F;
    cy = (h - (b.maxY - b.minY) * F) * vposPct / 100 - b.minY * F;
}

// Latitude to the vertical map coordinate (x = lon/180 spans -1..1). Miller stretches the poles vertically, so
// high latitudes are not squashed flat as in the plain equirectangular map.
var projection = "miller";
function zOf(lat) {
    if (projection === "miller") return 1.25 * Math.log(Math.tan(Math.PI / 4 + 0.4 * lat * Math.PI / 180)) / Math.PI;
    return lat / 180;
}

// Result in P (x, y in pixels, s = pixels per world unit at that depth)
function proj(lon, lat, h) { projXZ(lon / 180, zOf(lat), h); }

// The same for map coordinates (x, z), h is the height above the map
function projXZ(x, z, h) {
    var yc = h * Math.max(cosT, 0.3) + z * sinT;   // arcs keep some lift when looking straight down
    var zc = -h * sinT + z * cosT;
    var s = F / (D + zc);
    P.x = cx + x * s; P.y = cy - yc * s; P.s = s;
}

// Real cities, grouped by region: [lon, lat, weight]. The weight is the size of the city (1 = large, 4 = a giant), so
// the big ones are busier. Regions are drawn from evenly (weights below), so no part of the world is crowded or empty.
var regionData = [
    { weight: 1.2, cities: [   // North America
        [-74, 40.7, 4], [-118.2, 34, 3], [-87.6, 41.9, 2], [-79.4, 43.7, 2], [-99.1, 19.4, 3], [-80.2, 25.8, 1], [-123.1, 49.3, 1],
        [-150, 61.2, 1], [-95.4, 29.8, 2], [-105, 39.7, 1], [-84.4, 33.7, 1], [-73.6, 45.5, 1], [-82.4, 23.1, 1],
        [-79.5, 9, 1], [-90.5, 14.6, 1], [-157.9, 21.3, 1], [-51.7, 64.2, 1], [-112, 33.4, 1],
        [-114.4, 62.5, 1], [-135, 60.7, 1], [-68.5, 63.7, 1], [-94.2, 58.8, 1], [-113.5, 53.5, 1], [-147.7, 64.8, 1], [-165.4, 64.5, 1], [-156.8, 71.3, 1], [-94.8, 74.7, 1], [-69.4, 77.5, 1], [-21.9, 70.5, 1], [-106.7, 52.1, 1], [-97.1, 49.9, 1], [-114, 51, 1], [-66, 46, 1], [-52.7, 47.6, 1], [-78, 56, 1], [-125, 55, 1],
        [-51.1, 69.2, 1], [-37.6, 65.6, 1], [-45.4, 61.2, 1], [-56.1, 72.8, 1], [-20.2, 74.3, 1], [-16.7, 81.6, 1], [-62.3, 82.5, 1], [-85.9, 80, 1], [-105, 69.1, 1], [-77, 72.7, 1], [-82.9, 76.4, 1], [-115.1, 67.8, 1], [-133.7, 68.4, 1], [-96, 64.3, 1], [-68.4, 58.1, 1], [-92.1, 62.8, 1], [-49.7, 62, 1], [-33, 69, 1], [-44, 76, 1], [-100, 78, 1], [-122, 72, 1], [-60, 66, 1] ] },
    { weight: 1.0, cities: [   // South America
        [-46.6, -23.5, 4], [-58.4, -34.6, 3], [-74, 4.7, 2], [-77, -12, 2], [-70.7, -33.4, 2], [-43.2, -22.9, 2], [-66.9, 10.5, 1],
        [-78.5, -0.2, 1], [-47.9, -15.8, 1], [-60, -3.1, 1], [-68.1, -16.5, 1], [-34.9, -8.1, 1], [-70.9, -53.2, 1],
        [-38.5, -3.7, 1], [-57.6, -25.3, 1],
        [-68.3, -54.8, 1], [-73, -41.5, 1], [-62.3, -38.7, 1], [-57.9, -51.7, 1], [-65.2, -26.8, 1], [-79.9, -2.2, 1] ] },
    { weight: 1.1, cities: [   // Europe
        [-0.1, 51.5, 4], [2.3, 48.9, 3], [8.7, 50.1, 3], [-3.7, 40.4, 2], [12.5, 41.9, 2], [18, 59.3, 1], [-21.9, 64.1, 1], [29, 41, 3],
        [21, 52.2, 1], [23.7, 38, 1], [30.5, 50.5, 1], [-9.1, 38.7, 1], [-6.3, 53.3, 1], [10.8, 59.9, 1], [25, 60.2, 1], [26.1, 44.4, 1],
        [16.4, 48.2, 1], [4.9, 52.4, 1], [14.4, 50.1, 1],
        [15.6, 78.2, 1], [18.9, 69.6, 1], [-18.1, 65.7, 1], [25.7, 66.5, 1], [23.7, 70.7, 1], [40.5, 64.5, 1], [-3.2, 58.4, 1], [12.6, 55.7, 1], [24.1, 56.9, 1], [-16.9, 28.1, 1], [14.5, 35.9, 1] ] },
    { weight: 0.6, cities: [   // Russia and Central Asia
        [37.6, 55.8, 3], [83, 55, 1], [60.6, 56.8, 1], [131.9, 43.1, 1], [76.9, 43.2, 1], [69.2, 41.3, 1], [104.3, 52.3, 1], [129.7, 62, 1],
        [33, 68.9, 1], [30.3, 59.9, 2], [49.1, 55.8, 1], [73.4, 54.99, 1],
        [88.2, 69.3, 1], [128.9, 71.6, 1], [177.5, 64.7, 1], [150.8, 59.6, 1], [158.7, 53, 1], [73.4, 61.3, 1], [64, 67.5, 1], [102.5, 71.9, 1], [80.5, 73.5, 1], [170.3, 69.7, 1], [133.4, 67.5, 1], [107.6, 51.8, 1], [60, 50, 1], [71.4, 51.2, 1], [87, 53.8, 1], [142.7, 46.9, 1], [51.4, 45.5, 1] ] },
    { weight: 0.7, cities: [   // Middle East
        [55.3, 25.2, 3], [46.7, 24.7, 2], [51.4, 35.7, 2], [34.8, 32.1, 1], [44.4, 33.3, 1], [51.5, 25.3, 1], [47.9, 29.4, 1], [58.4, 23.6, 1],
        [39.2, 21.5, 1] ] },
    { weight: 1.1, cities: [   // Africa
        [31.2, 30, 3], [3.4, 6.5, 3], [36.8, -1.3, 2], [28, -26.2, 3], [18.4, -33.9, 2], [-7.6, 33.6, 1], [3.1, 36.8, 1], [-0.2, 5.6, 1],
        [-17.4, 14.7, 1], [38.7, 9, 2], [39.3, -6.8, 1], [15.3, -4.3, 2], [13.2, -8.8, 1], [32.6, -25.9, 1], [32.5, 15.5, 1], [10.2, 36.8, 1],
        [47.5, -18.9, 1], [17.1, -22.6, 1], [-4, 5.3, 1], [-13.2, 8.5, 1], [29.9, -3.4, 1], [31, -17.8, 1],
        [25.6, -34, 1], [41.9, -3.5, 1], [-16, 18, 1], [11.5, 3.9, 1], [7.5, 9, 1] ] },
    { weight: 1.0, cities: [   // South Asia
        [72.9, 19.1, 3], [77.2, 28.6, 3], [77.6, 13, 2], [88.4, 22.6, 2], [80.3, 13.1, 1], [67, 24.9, 2], [90.4, 23.8, 2], [79.9, 6.9, 1],
        [85.3, 27.7, 1], [74.3, 31.5, 1], [69.2, 34.5, 1], [78.5, 17.4, 1] ] },
    { weight: 1.4, cities: [   // East Asia
        [139.7, 35.7, 4], [121.5, 31.2, 4], [116.4, 39.9, 3], [114.2, 22.3, 3], [127, 37.6, 3], [121.5, 25, 2], [135.5, 34.7, 1], [104.1, 30.7, 2],
        [108.9, 34.3, 1], [87.6, 43.8, 1], [91.1, 29.7, 1], [106.9, 47.9, 1], [126.6, 45.8, 1], [114.3, 30.6, 1], [141.4, 43.1, 1],
         ] },
    { weight: 1.0, cities: [   // Southeast Asia
        [103.8, 1.35, 3], [106.8, -6.2, 2], [100.5, 13.8, 2], [121, 14.6, 2], [101.7, 3.1, 1], [106.7, 10.8, 1], [105.8, 21, 1], [96.2, 16.8, 1],
        [112.7, -7.3, 1], [119.4, -5.1, 1], [140.7, -2.5, 1], [98.7, 18.8, 1] ] },
    { weight: 0.8, cities: [   // Oceania
        [151.2, -33.9, 3], [145, -37.8, 2], [115.9, -32, 1], [153, -27.5, 1], [174.8, -36.8, 1], [130.8, -12.5, 1], [147.2, -9.4, 1], [178.4, -18.1, 1],
        [174.8, -41.3, 1], [138.6, -34.9, 1], [-149.6, -17.5, 1], [166.5, -22.3, 1], [133.9, -23.7, 1],
        [147.3, -42.9, 1], [172.6, -43.5, 1], [170.5, -45.9, 1], [-171.8, -13.8, 1] ] }
];

// All cities as [lon, lat, weight, region]. Inside a region they are ordered so that any first part of the list is spread
// evenly over it (always the city farthest from the ones before, big cities slightly preferred), so showing fewer cities
// thins them out everywhere instead of dropping the remote ones.
var cities = [];
var regions = [];
var active = [];          // the cities in use, see useCities()
(function () {
    regionData.forEach(function (r, i) {
        var list = r.cities.map(function (c) { return { lon: c[0], lat: c[1], w: c[2] }; });
        var order = [], rest = list.slice();
        rest.sort(function (a, b) { return b.w - a.w; });
        order.push(rest.shift());
        while (rest.length > 0) {
            var best = 0, bestScore = -1;
            for (var k = 0; k < rest.length; k++) {
                var dmin = 1e9;
                for (var o = 0; o < order.length; o++) {
                    var dx = rest[k].lon - order[o].lon, dy = (rest[k].lat - order[o].lat) * 2;   // latitude counts double: the map is 2:1
                    dmin = Math.min(dmin, Math.hypot(dx, dy));
                }
                var score = dmin * (1 + 0.12 * (rest[k].w - 1));
                if (score > bestScore) { bestScore = score; best = k; }
            }
            order.push(rest.splice(best, 1)[0]);
        }
        var ids = [];
        order.forEach(function (c) { ids.push(cities.length); cities.push([c.lon, c.lat, c.w, i]); });
        regions.push({ weight: r.weight, cities: ids, count: ids.length });
    });
})();

// Uses pct percent of the cities (every region keeps at least a few)
function useCities(pct) {
    active = [];
    regions.forEach(function (r) {
        r.count = Math.min(r.cities.length, Math.max(4, Math.ceil(r.cities.length * pct / 100)));
        for (var i = 0; i < r.count; i++) active.push(r.cities[i]);
    });
}
useCities(100);

var polys = Coast.polys;
var borders = Borders.lines;
