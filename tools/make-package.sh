#!/usr/bin/env bash
# Packs the wallpaper into dist/World-<version>.zip (metadata.json, LICENSE and contents/ at the top level), ready
# for `kpackagetool6 -t Plasma/Wallpaper -i <zip>` or the KDE Store. Pure QML: no build, nothing architecture specific.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(grep -o '"Version": *"[^"]*"' "$ROOT/metadata.json" | cut -d'"' -f4)"
OUT="$ROOT/dist/World-$VERSION.zip"

command -v msgfmt >/dev/null || { echo "msgfmt (gettext) is needed to include the translations"; exit 1; }
printf '.pragma library\n// Written by the packaging script from metadata.json\nvar version = "%s";\n' "$VERSION" > "$ROOT/contents/ui/version.js"
"$ROOT/tools/build-translations.sh"

mkdir -p "$ROOT/dist"
rm -f "$OUT"
(cd "$ROOT" && python3 - "$OUT" <<'PY'
import os, sys, zipfile

out = sys.argv[1]
entries = ["metadata.json", "LICENSE"] + [os.path.join(d, f) for d, _, fs in sorted(os.walk("contents")) for f in sorted(fs)]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for entry in entries:
        z.write(entry)
PY
)
echo "Created $OUT"
