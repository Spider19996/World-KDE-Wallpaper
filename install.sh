#!/usr/bin/env bash
# Installs the World wallpaper (KDE Plasma 6) for the current user. No build and no root needed.
#   ./install.sh [-y]      install (-y: restart Plasma without asking)
#   ./install.sh --uninstall
set -euo pipefail
ID="de.robin.world"
SRC="$(cd "$(dirname "$0")" && pwd)"
PKG="${XDG_DATA_HOME:-$HOME/.local/share}/plasma/wallpapers/$ID"
if [[ "${1:-}" == "--uninstall" ]]; then rm -rf "$PKG"; echo "Removed $PKG"; exit 0; fi
# The settings page shows the version of metadata.json
VERSION="$(grep -o '"Version": *"[^"]*"' "$SRC/metadata.json" | cut -d'"' -f4)"
printf '.pragma library\n// Written by install.sh from metadata.json\nvar version = "%s";\n' "$VERSION" > "$SRC/contents/ui/version.js"
"$SRC/tools/build-translations.sh"
rm -rf "$PKG"; mkdir -p "$PKG"
cp -r "$SRC/metadata.json" "$SRC/contents" "$PKG/"
echo "Installed. Right-click the desktop > Configure Desktop and Wallpaper > Wallpaper Type > World"
answer=n
if [[ "${1:-}" == "-y" ]]; then answer=y; elif [[ -t 0 ]]; then read -r -p "Restart Plasma now? [Y/n] " answer || answer=n; [[ -z "$answer" ]] && answer=y; fi
if [[ "$answer" =~ ^[yY]$ ]]; then systemctl --user restart plasma-plasmashell; echo "Plasma restarted."; else echo "Later: systemctl --user restart plasma-plasmashell"; fi
