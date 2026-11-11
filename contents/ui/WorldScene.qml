import QtQuick
import org.kde.kirigami as Kirigami

import "aircraft.js" as Air
import "countries.js" as Countries
import "geo.js" as Geo
import "params.js" as Params

// The picture: flat world map as line art with a simulated data stream on top. All settings come in through `p`
// (one theme with everything inherited filled in), so the same scene runs as the wallpaper and as the preview.
Item {
    id: scene

    property var p: Params.defaults()
    property bool running: true
    property int fps: 30                 // 0 = at the refresh rate of the screen
    property bool pixelShift: false      // burn-in protection: wander a few pixels (a global setting)
    property real resolution: 1.0        // share of the screen size the picture is calculated at

    // Live aircraft (see AircraftFeed.qml); the previews show a few made-up ones instead
    property var aircraft: []
    property bool aircraftDemo: false
    readonly property var aircraftShow: ({ route: p.AircraftInfoRoute, type: p.AircraftInfoType, altitude: p.AircraftInfoAltitude, operator: p.AircraftInfoOperator })
    readonly property var planes: aircraftDemo ? demoPlanes : aircraft
    property var demoPlanes: Air.demo(Date.now())
    readonly property bool metric: Qt.locale().measurementSystem === Locale.MetricSystem
    onPlanesChanged: planesCanvas.requestPaint()

    // Frame rate and cost of the data stream, updated every second
    property var stats: ({ fps: 0, ms: 0, load: 0, mb: 0, uploadMb: 0, sparks: 0, planes: 0, planeMs: 0 })
    property int frames: 0
    property real paintTotal: 0
    property int planePaints: 0           // pictures of the aircraft sent to the GPU since the last second

    readonly property var pal: ({
        land: Params.toRgb(p.LandColor),
        lines: p.AccentColor ? [[Math.round(Kirigami.Theme.highlightColor.r * 255), Math.round(Kirigami.Theme.highlightColor.g * 255), Math.round(Kirigami.Theme.highlightColor.b * 255)]]
                             : p.LineColors.map(function (c) { return Params.toRgb(c); }),
        bg: Params.toRgb(p.BgColor)
    })
    // The language of the country names: the chosen one, or that of the system
    readonly property string nameLanguage: {
        var l = p.CountryNameLanguage === "auto" ? Qt.locale().name.substring(0, 2) : p.CountryNameLanguage;
        return Countries.languages.indexOf(l) >= 0 ? l : "en";
    }
    // On a bright background the light is subtracted instead of added
    readonly property bool bright: Params.luminance(pal.bg) > 0.5

    function rgba(c, a) { return "rgba(" + c[0] + "," + c[1] + "," + c[2] + "," + Math.max(0, Math.min(1, a)).toFixed(3) + ")"; }
    function mixWhite(c, t) { return [Math.round(c[0] + (255 - c[0]) * t), Math.round(c[1] + (255 - c[1]) * t), Math.round(c[2] + (255 - c[2]) * t)]; }
    function mixBlack(c, t) { return [Math.round(c[0] * (1 - t)), Math.round(c[1] * (1 - t)), Math.round(c[2] * (1 - t))]; }

    // Everything that changes the geometry. A short delay lets a resizing window settle first.
    readonly property string layoutKey: width + "x" + height + ":" + p.Tilt + ":" + p.Projection + ":" + p.Cities + ":" + p.MapScale + ":" + p.VerticalPos
    onLayoutKeyChanged: settle.restart()
    // New settings show at once: the old connections and node colors must not linger
    onPChanged: { anim.reset(); mapCanvas.requestPaint(); planesCanvas.requestPaint(); }
    Timer { id: settle; interval: 40; onTriggered: scene.relayout() }

    function restart() { anim.reset(); }

    function relayout() {
        if (width <= 0 || height <= 0) return;
        Geo.layout(width, height, p.Tilt, p.MapScale, p.VerticalPos, p.Projection);
        Geo.useCities(p.Cities);
        anim.reset();
        mapCanvas.requestPaint();
        planesCanvas.requestPaint();
    }
    Component.onCompleted: relayout()

    Rectangle {
        anchors.fill: parent
        color: scene.p.BgColor
    }

    // ---- The map: drawn once, redrawn only when the layout or the colors change ---------------------------
    Canvas {
        id: mapCanvas
        // The canvas has the size of the picture at the chosen resolution and is scaled up to the screen
        width: Math.round(scene.width * scene.resolution)
        height: Math.round(scene.height * scene.resolution)
        canvasSize: Qt.size(Math.max(1, width), Math.max(1, height))
        onCanvasSizeChanged: requestPaint()
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        // Burn-in protection: the whole picture wanders a few pixels
        property real shiftX: 0
        property real shiftY: 0
        transform: [
            Scale { origin.x: 0; origin.y: 0; xScale: 1 / scene.resolution; yScale: 1 / scene.resolution },
            Translate { x: mapCanvas.shiftX; y: mapCanvas.shiftY }
        ]

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.scale(scene.resolution, scene.resolution);
            if (width <= 0 || Geo.W <= 0) return;
            var p = scene.p, land = scene.pal.land;
            var mo = p.MapOpacity / 100;

            // Graticule
            if (p.ShowGraticule) {
                ctx.lineWidth = 0.6;
                ctx.strokeStyle = scene.rgba(land, 0.1 * mo);
                ctx.beginPath();
                for (var gl = -150; gl <= 180; gl += 30) {
                    Geo.proj(gl, 84, 0); ctx.moveTo(Geo.P.x, Geo.P.y);
                    Geo.proj(gl, -57, 0); ctx.lineTo(Geo.P.x, Geo.P.y);
                }
                for (var gb = -45; gb <= 75; gb += 30) {
                    Geo.proj(-180, gb, 0); ctx.moveTo(Geo.P.x, Geo.P.y);
                    Geo.proj(180, gb, 0); ctx.lineTo(Geo.P.x, Geo.P.y);
                }
                ctx.stroke();
            }

            ctx.lineJoin = "round";

            // Country borders
            if (p.ShowBorders) {
                ctx.lineWidth = p.BorderWidth;
                ctx.strokeStyle = scene.rgba(Params.toRgb(p.BorderColor), p.BorderOpacity / 100);
                ctx.beginPath();
                for (var bi = 0; bi < Geo.borders.length; bi++) {
                    var bl = Geo.borders[bi];
                    Geo.proj(bl[0], bl[1], 0);
                    ctx.moveTo(Geo.P.x, Geo.P.y);
                    for (var bw = 2; bw < bl.length; bw += 2) { Geo.proj(bl[bw], bl[bw + 1], 0); ctx.lineTo(Geo.P.x, Geo.P.y); }
                }
                ctx.stroke();
            }

            // Coast lines, a little dimmer towards the far edge
            Geo.proj(0, 84, 0); var farY = Geo.P.y;
            Geo.proj(0, -57, 0); var nearY = Geo.P.y;
            var lg = ctx.createLinearGradient(0, farY, 0, nearY);
            lg.addColorStop(0, scene.rgba(land, 0.5 * mo));
            lg.addColorStop(1, scene.rgba(land, mo));
            ctx.lineWidth = p.MapLineWidth;
            ctx.strokeStyle = lg;
            ctx.beginPath();
            for (var q = 0; q < Geo.polys.length; q++) {
                var pl = Geo.polys[q];
                Geo.proj(pl[0], pl[1], 0);
                ctx.moveTo(Geo.P.x, Geo.P.y);
                for (var w = 2; w < pl.length; w += 2) { Geo.proj(pl[w], pl[w + 1], 0); ctx.lineTo(Geo.P.x, Geo.P.y); }
                ctx.closePath();
            }
            ctx.stroke();

            // Country names, the important ones first; a name that would cover another one is left out
            if (p.ShowCountryNames) {
                var li = Countries.languages.indexOf(scene.nameLanguage);
                ctx.fillStyle = scene.rgba(Params.toRgb(p.CountryNameColor), p.CountryNameOpacity / 100);
                ctx.textAlign = "center";
                ctx.textBaseline = "middle";
                var placed = [];
                for (var ci = 0; ci < Countries.list.length; ci++) {
                    var cn = Countries.list[ci], text = cn[3][li];
                    if (!text) continue;
                    Geo.proj(cn[0], cn[1], 0);
                    var px = p.CountryNameSize * Geo.P.s / 900;   // the size is for a map as wide as a 1920 px screen
                    if (px < 6) continue;
                    ctx.font = px.toFixed(1) + "px sans-serif";
                    var half = ctx.measureText(text).width / 2 + 3, hh = px * 0.6, cx0 = Geo.P.x, cy0 = Geo.P.y, hit = false;
                    for (var pi = 0; pi < placed.length && !hit; pi++) {
                        var b = placed[pi];
                        hit = cx0 - half < b[2] && cx0 + half > b[0] && cy0 - hh < b[3] && cy0 + hh > b[1];
                    }
                    if (hit) continue;
                    placed.push([cx0 - half, cy0 - hh, cx0 + half, cy0 + hh]);
                    ctx.fillText(text, cx0, cy0);
                }
            }
        }
    }

    // ---- Aircraft: slow movers, so drawn only now and then; after an update every aircraft glides to its new place --
    Canvas {
        id: planesCanvas
        width: mapCanvas.width
        height: mapCanvas.height
        transform: [
            Scale { origin.x: 0; origin.y: 0; xScale: 1 / scene.resolution; yScale: 1 / scene.resolution },
            Translate { x: mapCanvas.shiftX; y: mapCanvas.shiftY }
        ]
        canvasSize: Qt.size(Math.max(1, width), Math.max(1, height))
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        property int shown: 0
        property real lastMs: 0
        property bool gliding: false

        // Top view of an aircraft, one half (right side from nose to tail), unit length; and a plain dart for crowded maps
        readonly property var halfIcon: [0, -1, 0.11, -0.62, 0.11, -0.2, 0.92, 0.28, 0.92, 0.46, 0.11, 0.22, 0.09, 0.62, 0.36, 0.84, 0.36, 0.98, 0, 0.88]
        readonly property var dart: [0, -1, 0.55, 0.8, 0, 0.45, -0.55, 0.8]

        function icon(simple) {
            if (simple) return dart;
            var out = [], h = halfIcon, n = h.length / 2, i;
            for (i = 0; i < n; i++) out.push(h[i * 2], h[i * 2 + 1]);
            for (i = n - 2; i >= 1; i--) out.push(-h[i * 2], h[i * 2 + 1]);
            return out;
        }

        // Adds an aircraft at (x, y), pointing along the angle `th` (0 = up), size s, to the current path
        function addPlane(ctx, shape, x, y, th, s) {
            var c = Math.cos(th), si = Math.sin(th);
            for (var i = 0; i < shape.length; i += 2) {
                var u = shape[i] * s, v = shape[i + 1] * s;
                var px = x + u * c - v * si, py = y + u * si + v * c;
                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
            }
            ctx.closePath();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.scale(scene.resolution, scene.resolution);
            var p = scene.p, list = scene.planes;
            shown = 0;
            gliding = false;
            if (width <= 0 || Geo.W <= 0 || !p.ShowAircraft || !list || list.length === 0) return;
            var started = Date.now(), n = list.length;
            var base = Params.toRgb(p.AircraftColor), hot = Params.toRgb(p.AircraftLabelColor), op = p.AircraftOpacity / 100;
            // The more aircraft, the smaller and fainter each one, and a plain dart instead of the detailed shape
            var crowd = Math.log(Math.max(n, 300) / 300) / Math.LN10;                 // 0 (300 or fewer) .. 1.5 (10000)
            var size = p.AircraftSize / 100 * Math.max(0.3, 1 - crowd * 0.65);
            op *= Math.max(0.55, 1 - crowd * 0.3);
            var shape = icon(n > 1200), pos = { lat: 0, lon: 0 }, tp = { lat: 0, lon: 0 };
            var xs = new Float32Array(n), ys = new Float32Array(n), ths = new Float32Array(n), ss = new Float32Array(n);
            var buckets = p.Rainbow ? 8 : 1, bucket = new Uint8Array(n), vis = new Uint8Array(n);
            var labeled = [], marked = new Uint8Array(n), i, k;

            for (i = 0; i < n; i++) {
                var a = list[i];
                Air.position(a, started, pos);
                if (a.gl) gliding = true;
                if (pos.lat < -57 || pos.lat > 84) continue;
                var h = 0.006 + Math.min(1, a.alt / 12000) * 0.012;
                Geo.proj(pos.lon, pos.lat, h);
                var x = Geo.P.x, y = Geo.P.y, sc = Geo.P.s;
                // The direction on the screen: where the aircraft will be in a moment
                var r = a.trk * Math.PI / 180;
                Geo.proj(pos.lon + Math.sin(r) * 0.6 / Math.max(0.15, Math.cos(pos.lat * Math.PI / 180)), pos.lat + Math.cos(r) * 0.6, h);
                xs[i] = x; ys[i] = y; ss[i] = Math.max(2, 0.0075 * sc * size);
                ths[i] = Math.atan2(Geo.P.x - x, y - Geo.P.y);
                bucket[i] = buckets > 1 ? Math.max(0, Math.min(7, Math.floor(a.alt / 12000 * 8))) : 0;
                vis[i] = 1;
                shown++;
                if (a.label && p.AircraftLabels && p.AircraftLabelMax > 0) { labeled.push(i); marked[i] = 1; }
            }

            // Routes of the labeled aircraft, faint and dashed
            if (p.AircraftRoutes && labeled.length > 0) {
                ctx.lineWidth = 0.9;
                ctx.setLineDash([3, 5]);
                ctx.strokeStyle = scene.rgba(hot, 0.35);
                ctx.beginPath();
                for (var li = 0; li < labeled.length; li++) {
                    var rt = list[labeled[li]].route;
                    if (!rt || typeof rt.o.lon !== "number" || typeof rt.d.lon !== "number") continue;
                    var dl = rt.d.lon - rt.o.lon, db = rt.d.lat - rt.o.lat, lift = 0.01 + Math.hypot(dl, db) / 180 * 0.1;
                    for (k = 0; k <= 36; k++) {
                        var t = k / 36;
                        Geo.proj(rt.o.lon + dl * t, rt.o.lat + db * t, 4 * lift * t * (1 - t));
                        if (k === 0) ctx.moveTo(Geo.P.x, Geo.P.y); else ctx.lineTo(Geo.P.x, Geo.P.y);
                    }
                }
                ctx.stroke();
                ctx.setLineDash([]);
            }

            // The aircraft, all of one color in one go (eight colors of the rainbow by altitude)
            for (var b = 0; b < buckets; b++) {
                var col = buckets > 1 ? anim.hsl(b / 8 * 0.75, p.RainbowSaturation, p.RainbowLightness) : base;
                ctx.fillStyle = scene.rgba(col, op);
                ctx.beginPath();
                for (i = 0; i < n; i++) if (vis[i] && !marked[i] && bucket[i] === b) addPlane(ctx, shape, xs[i], ys[i], ths[i], ss[i]);
                ctx.fill();
            }
            // The labeled ones in their own color, a little larger
            var bigShape = icon(false);
            ctx.fillStyle = scene.rgba(hot, Math.max(op, 0.9));
            ctx.beginPath();
            for (i = 0; i < n; i++) if (vis[i] && marked[i]) addPlane(ctx, bigShape, xs[i], ys[i], ths[i], ss[i] * 1.3);
            ctx.fill();

            // Labels: a ring around the aircraft, the lines of text next to it on a dim background; a label that would
            // cover another one is left out
            if (labeled.length > 0) {
                var px = Math.max(7, p.AircraftLabelSize * Geo.P.s / 900);
                ctx.font = px.toFixed(1) + "px sans-serif";
                ctx.textBaseline = "top";
                var placed = [], lh = px * 1.25, bg = scene.pal.bg;
                for (var q = 0; q < labeled.length; q++) {
                    i = labeled[q];
                    var pl = list[i], lines = Air.labelLines(pl, scene.aircraftShow, scene.metric);
                    var wmax = 0, ln;
                    for (ln = 0; ln < lines.length; ln++) wmax = Math.max(wmax, ctx.measureText(lines[ln]).width);
                    var toLeft = xs[i] > scene.width * 0.72, gapx = ss[i] * 1.3 + 5;
                    var bx = toLeft ? xs[i] - gapx - wmax : xs[i] + gapx, by = ys[i] - lh * 0.6;
                    var box = [bx - 4, by - 3, bx + wmax + 4, by + lines.length * lh + 3], hit = false;
                    for (var pi = 0; pi < placed.length && !hit; pi++) {
                        var ob = placed[pi];
                        hit = box[0] < ob[2] && box[2] > ob[0] && box[1] < ob[3] && box[3] > ob[1];
                    }
                    if (hit || box[0] < 0 || box[2] > scene.width || box[1] < 0 || box[3] > scene.height) continue;
                    placed.push(box);
                    var lc = pl.emerg ? [255, 255, 255] : hot;
                    ctx.fillStyle = scene.rgba(bg, 0.72);
                    ctx.fillRect(box[0], box[1], box[2] - box[0], box[3] - box[1]);
                    ctx.strokeStyle = scene.rgba(lc, 0.7 * op);
                    ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.arc(xs[i], ys[i], ss[i] * 1.25, 0, 6.2832); ctx.stroke();
                    ctx.lineWidth = 0.7;
                    ctx.strokeStyle = scene.rgba(lc, 0.4 * op);
                    ctx.beginPath();
                    ctx.moveTo(xs[i] + (toLeft ? -1 : 1) * ss[i] * 1.25, ys[i]);
                    ctx.lineTo(toLeft ? bx + wmax + 2 : bx - 2, by + lh * 0.6);
                    ctx.stroke();
                    ctx.textAlign = toLeft ? "right" : "left";
                    for (ln = 0; ln < lines.length; ln++) {
                        ctx.fillStyle = scene.rgba(lc, ln === 0 ? 1 : 0.85);
                        ctx.fillText(lines[ln], toLeft ? bx + wmax : bx, by + ln * lh);
                    }
                }
            }
            lastMs = Date.now() - started;
            scene.planePaints++;
        }
    }

    // A calm picture every couple of seconds; while aircraft glide to their new places, many frames per second
    Timer {
        interval: planesCanvas.gliding ? 66 : 2000
        repeat: true
        running: scene.running && scene.visible && scene.p.ShowAircraft && scene.planes && scene.planes.length > 0
        onTriggered: planesCanvas.requestPaint()
    }

    // ---- The data stream: arcs with packets, pulses at the nodes ---------------------------------------
    Canvas {
        id: anim
        width: mapCanvas.width
        height: mapCanvas.height
        transform: [
            Scale { origin.x: 0; origin.y: 0; xScale: 1 / scene.resolution; yScale: 1 / scene.resolution },
            Translate { x: mapCanvas.shiftX; y: mapCanvas.shiftY }
        ]
        canvasSize: Qt.size(Math.max(1, width), Math.max(1, height))
        renderTarget: Canvas.FramebufferObject
        renderStrategy: Canvas.Cooperative

        readonly property int steps: 40
        property var arcs: []
        property var rings: []
        property var sparks: []
        property var glow: new Array(Geo.cities.length).fill(0)
        property var cityCol: new Array(Geo.cities.length).fill(null)
        property double last: 0
        property real hue: 0

        function reset() {
            arcs = []; rings = []; sparks = []; last = 0;
            glow = new Array(Geo.cities.length).fill(0);
            cityCol = new Array(Geo.cities.length).fill(null);
        }

        function hsl(h, s, l) {
            var a = s * Math.min(l, 1 - l);
            function f(n) { var k = (n + h * 12) % 12; return Math.round(255 * (l - a * Math.max(-1, Math.min(k - 3, 9 - k, 1)))); }
            return [f(0), f(8), f(4)];
        }

        // Colors of a new connection: a hue of its own (rainbow) or one of the line colors
        function nextColors() {
            var p = scene.p;
            if (p.Rainbow) {
                hue = (hue + 0.09 + Math.random() * 0.06) % 1;
                return { acc: hsl(hue, p.RainbowSaturation, p.RainbowLightness),
                         core: scene.bright ? hsl(hue, p.RainbowSaturation, p.RainbowLightness * 0.6) : hsl(hue, 0.9, 0.88) };
            }
            var l = scene.pal.lines, c = l[Math.floor(Math.random() * l.length)];
            return { acc: c, core: scene.bright ? scene.mixBlack(c, 0.45) : scene.mixWhite(c, 0.75) };
        }

        // A packet that hits its target can blow up: shock wave plus a burst of sparks
        function explode(city, col) {
            var p = scene.p, c = Geo.cities[city], size = p.ExplosionSize / 100;
            Geo.proj(c[0], c[1], 0);
            var x = Geo.P.x, y = Geo.P.y, s = Geo.P.s;
            for (var i = 0; i < p.ExplosionSparks && sparks.length < 800; i++) {
                var an = Math.random() * 6.2832, sp = (0.06 + Math.random() * 0.3) * s * size;
                sparks.push({ x: x, y: y, vx: Math.cos(an) * sp, vy: Math.sin(an) * sp, age: 0, life: 0.5 + Math.random() * 0.9, acc: col.acc, core: col.core });
            }
            rings.push({ x: c[0] / 180, z: Geo.zOf(c[1]), age: 0, dur: 1.3, size: 2.2 * size, acc: col.acc, boom: true });
        }

        // A region first (evenly, so no part of the world is crowded or empty), then a city in it, big cities more often.
        // `not` is a region to leave out (-1 = none).
        function pickCity(not) {
            var rs = Geo.regions, total = 0, i;
            for (i = 0; i < rs.length; i++) if (i !== not) total += rs[i].weight;
            var r = Math.random() * total, region = 0;
            for (i = 0; i < rs.length; i++) {
                if (i === not) continue;
                r -= rs[i].weight;
                if (r <= 0) { region = i; break; }
            }
            // Only the cities in use; big ones more often, but not by much, so the small ones are seen as well
            var ids = rs[region].cities, n = rs[region].count, sum = 0;
            for (i = 0; i < n; i++) sum += Math.sqrt(Geo.cities[ids[i]][2]);
            var c = Math.random() * sum;
            for (i = 0; i < n; i++) { c -= Math.sqrt(Geo.cities[ids[i]][2]); if (c <= 0) return ids[i]; }
            return ids[0];
        }

        function spawn() {
            // Most connections go to another part of the world, which also makes the longer arcs
            var ia = pickCity(-1), ib = pickCity(Math.random() < 0.8 ? Geo.cities[ia][3] : -1);
            var a = Geo.cities[ia], b = Geo.cities[ib];
            var xa = a[0] / 180, xb = b[0] / 180, za = Geo.zOf(a[1]), zb = Geo.zOf(b[1]);
            var d = Math.hypot(xa - xb, za - zb);
            if (ia === ib || d < 0.14) return;
            var H = (0.04 + d * 0.30) * scene.p.ArcHeight / 100, N = steps;
            var pts = new Float32Array(N * 2);
            for (var i = 0; i < N; i++) {
                var t = i / (N - 1);
                Geo.projXZ(xa + (xb - xa) * t, za + (zb - za) * t, 4 * H * t * (1 - t));
                pts[i * 2] = Geo.P.x; pts[i * 2 + 1] = Geo.P.y;
            }
            var tp = 1.4 + d * 2.0, n = 1 + Math.floor(Math.random() * 3), packets = [];
            for (i = 0; i < n; i++) packets.push({ delay: 0.25 + i * (0.25 + Math.random() * 0.5) * tp * 0.5, done: false });
            var life = packets[n - 1].delay + tp * 1.3 + 0.9;
            var col = nextColors();
            arcs.push({ a: ia, b: ib, pts: pts, tp: tp, life: life, age: 0, packets: packets, acc: col.acc, core: col.core });
            cityCol[ia] = col;
            glow[ia] = Math.max(glow[ia], 0.8);
            rings.push({ x: xa, z: za, age: 0, dur: 1.1, size: 0.6, acc: col.acc });
        }

        function drawArc(ctx, arc) {
            var N = steps, pts = arc.pts, acc = arc.acc, core = arc.core;
            var env = Math.min(1, arc.age / 0.4) * Math.min(1, (arc.life - arc.age) / 0.9);
            ctx.lineCap = "round";
            ctx.lineWidth = 1;
            ctx.strokeStyle = scene.rgba(acc, scene.p.ArcOpacity / 100 * env);
            ctx.beginPath();
            ctx.moveTo(pts[0], pts[1]);
            for (var i = 1; i < N; i++) ctx.lineTo(pts[i * 2], pts[i * 2 + 1]);
            ctx.stroke();

            var trail = 13;
            for (var k = 0; k < arc.packets.length; k++) {
                var pk = arc.packets[k];
                var raw = (arc.age - pk.delay) / arc.tp * 1.3;     // 0..1 travel, 1..1.3 tail runs out
                if (raw <= 0 || raw >= 1.3) continue;
                if (raw >= 1 && !pk.done) {
                    pk.done = true;
                    var b = Geo.cities[arc.b];
                    glow[arc.b] = 1;
                    cityCol[arc.b] = { acc: arc.acc, core: arc.core };
                    rings.push({ x: b[0] / 180, z: Geo.zOf(b[1]), age: 0, dur: 1.4, size: 1, acc: arc.acc });
                    if (Math.random() * 100 < scene.p.ExplosionChance) explode(arc.b, { acc: arc.acc, core: arc.core });
                }
                var fRaw = raw * (N - 1), head = Math.min(fRaw, N - 1), tail = Math.max(0, fRaw - trail);
                for (var s = Math.floor(tail); s < Math.min(N - 1, Math.ceil(head)); s++) {
                    var rel = (s + 0.5 - (fRaw - trail)) / trail;
                    if (rel <= 0) continue;
                    var e1 = Math.min(1, head - s);
                    var x0 = pts[s * 2], y0 = pts[s * 2 + 1];
                    ctx.strokeStyle = scene.rgba(rel > 0.8 ? core : acc, Math.min(1, rel * rel * 1.1));
                    ctx.lineWidth = 0.8 + 1.8 * rel;
                    ctx.beginPath();
                    ctx.moveTo(x0, y0);
                    ctx.lineTo(x0 + (pts[s * 2 + 2] - x0) * e1, y0 + (pts[s * 2 + 3] - y0) * e1);
                    ctx.stroke();
                }
                if (raw < 1) {
                    var hi = Math.min(N - 2, Math.floor(head)), fr = head - hi;
                    var hx = pts[hi * 2] + (pts[hi * 2 + 2] - pts[hi * 2]) * fr;
                    var hy = pts[hi * 2 + 1] + (pts[hi * 2 + 3] - pts[hi * 2 + 1]) * fr;
                    ctx.fillStyle = scene.rgba(acc, 0.28);
                    ctx.beginPath(); ctx.arc(hx, hy, 6, 0, 6.2832); ctx.fill();
                    ctx.fillStyle = scene.rgba(core, 1);
                    ctx.beginPath(); ctx.arc(hx, hy, 2, 0, 6.2832); ctx.fill();
                }
            }
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.scale(scene.resolution, scene.resolution);
            if (width <= 0 || Geo.W <= 0) return;
            var p = scene.p;
            var now = Date.now();
            var dt = last ? Math.min(0.1, (now - last) / 1000) : 0;
            last = now;
            dt *= p.Speed / 100;

            var maxArcs = Math.round(6 + p.Density / 100 * 40);
            if (p.Density > 0 && arcs.length < maxArcs && Math.random() < dt * maxArcs / 4.5) spawn();

            ctx.globalCompositeOperation = scene.bright ? "source-over" : "lighter";

            var i, k;
            for (i = rings.length - 1; i >= 0; i--) {
                var rg = rings[i];
                rg.age += dt;
                var u = rg.age / rg.dur;
                if (u >= 1) { rings.splice(i, 1); continue; }
                var rad = (0.008 + 0.05 * u) * rg.size;
                ctx.strokeStyle = scene.rgba(rg.acc, 0.8 * Math.pow(1 - u, 1.5));
                ctx.lineWidth = rg.boom ? 2.2 : 1.2;
                ctx.beginPath();
                for (k = 0; k <= 28; k++) {
                    var an = k / 28 * 6.2832;
                    Geo.projXZ(rg.x + Math.cos(an) * rad, rg.z + Math.sin(an) * rad, 0);
                    if (k === 0) ctx.moveTo(Geo.P.x, Geo.P.y); else ctx.lineTo(Geo.P.x, Geo.P.y);
                }
                ctx.stroke();
            }

            for (i = sparks.length - 1; i >= 0; i--) {
                var sk = sparks[i];
                sk.age += dt;
                if (sk.age >= sk.life) { sparks.splice(i, 1); continue; }
                var drag = Math.max(0, 1 - 2.4 * dt), f = 1 - sk.age / sk.life;
                sk.vx *= drag; sk.vy *= drag;
                sk.x += sk.vx * dt; sk.y += sk.vy * dt;
                ctx.strokeStyle = scene.rgba(f > 0.6 ? sk.core : sk.acc, f);
                ctx.lineWidth = 0.8 + 1.6 * f;
                ctx.beginPath();
                ctx.moveTo(sk.x - sk.vx * 0.1, sk.y - sk.vy * 0.1);
                ctx.lineTo(sk.x, sk.y);
                ctx.stroke();
            }

            for (i = arcs.length - 1; i >= 0; i--) {
                var arc = arcs[i];
                arc.age += dt;
                if (arc.age >= arc.life) { arcs.splice(i, 1); continue; }
                drawArc(ctx, arc);
            }

            var dflt = scene.p.Rainbow ? { acc: scene.pal.land, core: scene.pal.land }
                                       : { acc: scene.pal.lines[0], core: scene.bright ? scene.mixBlack(scene.pal.lines[0], 0.45) : scene.mixWhite(scene.pal.lines[0], 0.75) };
            for (var ai = 0; ai < Geo.active.length; ai++) {
                i = Geo.active[ai];
                var c = Geo.cities[i];
                glow[i] = Math.max(0, glow[i] - dt * 0.9);
                var g = glow[i];
                var nc = cityCol[i] || dflt;
                Geo.proj(c[0], c[1], 0);
                var r0 = 0.0032 * Geo.P.s * (0.85 + 0.12 * c[2]) * p.NodeSize / 100;
                if (g > 0.02) {
                    ctx.fillStyle = scene.rgba(nc.acc, 0.3 * g);
                    ctx.beginPath(); ctx.arc(Geo.P.x, Geo.P.y, r0 * (2 + 3 * g), 0, 6.2832); ctx.fill();
                }
                ctx.fillStyle = scene.rgba(g > 0.3 ? nc.core : nc.acc, 0.55 + 0.45 * g);
                ctx.beginPath(); ctx.arc(Geo.P.x, Geo.P.y, r0 * (1 + 0.5 * g), 0, 6.2832); ctx.fill();
            }
            scene.paintTotal += Date.now() - now;
            scene.frames++;
        }
    }

    Timer {
        interval: Math.round(1000 / Math.max(1, scene.fps))
        repeat: true
        running: scene.running && scene.visible && scene.fps > 0
        onRunningChanged: if (running) anim.last = 0
        onTriggered: anim.requestPaint()
    }

    // Frame rate 0: one frame per screen refresh
    FrameAnimation {
        running: scene.running && scene.visible && scene.fps <= 0
        onRunningChanged: if (running) anim.last = 0
        onTriggered: anim.requestPaint()
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            // The data stream is all this wallpaper does on the CPU. Its picture is a texture the size of the screen
            // (the map is a second one, drawn once) that goes to the GPU after every frame.
            var picture = Math.round(scene.width * scene.resolution) * Math.round(scene.height * scene.resolution) * 4 / 1048576;
            var onScreen = scene.p.ShowAircraft && scene.planes && scene.planes.length > 0;
            var ms = scene.frames > 0 ? scene.paintTotal / scene.frames : 0;
            scene.stats = { fps: scene.frames, ms: ms, load: ms * scene.frames / 10,
                            // the map and the data stream are a picture each, the aircraft a third one and their list (about 250 bytes each)
                            mb: (onScreen ? 3 : 2) * picture + (onScreen ? scene.planes.length * 250 / 1048576 : 0),
                            uploadMb: picture * (scene.frames + scene.planePaints), sparks: anim.sparks.length,
                            planes: planesCanvas.shown, planeMs: planesCanvas.lastMs };
            scene.frames = 0;
            scene.planePaints = 0;
            scene.paintTotal = 0;
        }
    }

    Timer {
        interval: 60000
        repeat: true
        running: scene.pixelShift
        triggeredOnStart: true
        onTriggered: {
            mapCanvas.shiftX = Math.round((Math.random() - 0.5) * 12);
            mapCanvas.shiftY = Math.round((Math.random() - 0.5) * 12);
        }
        onRunningChanged: if (!running) { mapCanvas.shiftX = 0; mapCanvas.shiftY = 0; }
    }
}
