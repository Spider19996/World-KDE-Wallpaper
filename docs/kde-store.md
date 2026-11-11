# KDE Store page

**Name:** World

**Category:** Plasma 6 Wallpaper Plugins

**Summary:** A flat world map as line art with a simulated data stream, themes with explosions, OLED friendly.

## Description

World draws a flat, perspective-tilted world map as line art. Data packets fly along arcs between cities, the nodes
pulse on arrival, and packets can explode on impact. It is written in QML, there is nothing to build.

- Themes in collections with inheritance, a theme manager with live preview and an assistant that rolls random themes
- Live aircraft (optional, no account needed): all aircraft of the world, labeled with flight, route and type, from OpenSky Network
- Rotation: any mix of themes takes turns every few seconds, with a fade
- Colors, rainbow or the Plasma accent color, country borders, density, speed, explosions, tilt, flat view, projection
- Always fits the screen with the right proportions, also on ultrawide screens
- OLED friendly: pure black background and a slow pixel shift against burn-in
- Power aware: frame rate limit, pause on battery, on the lock screen and when a window covers the desktop

Aircraft are off by default; when on, the wallpaper asks opensky-network.org and adsbdb.com over the internet.

Requires KDE Plasma 6 (Qt 6.5 or newer). License: GPL-3.0-or-later. Map data: Natural Earth (public domain).

## Upload

Upload `dist/World-<version>.zip` (made by `tools/make-package.sh`). Screenshots: `docs/red.jpg`, `docs/explosions.jpg`, `docs/flat.jpg`, `docs/bright.jpg`, `docs/flights.jpg`, `docs/flights-flat.jpg`, `docs/flights-bright.jpg`.
