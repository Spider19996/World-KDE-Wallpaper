#!/usr/bin/env bash
# Compiles po/<language>.po to contents/locale/<language>/LC_MESSAGES/<domain>.mo, where Plasma looks
# for the texts of a wallpaper package. Needs gettext (msgfmt).
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v msgfmt >/dev/null; then
    echo "msgfmt (gettext) not found, building without translations"
    exit 0
fi

DOMAIN=plasma_wallpaper_de.robin.world

rm -rf contents/locale
for po in po/*.po; do
    [ -e "$po" ] || continue
    lang=$(basename "$po" .po)
    mkdir -p "contents/locale/$lang/LC_MESSAGES"
    msgfmt -o "contents/locale/$lang/LC_MESSAGES/$DOMAIN.mo" "$po"
done
