#!/usr/bin/env bash
# Runs the logic tests (tests/tst_store.qml) with Qt's qmltestrunner and lints the QML files.
set -euo pipefail
cd "$(dirname "$0")/.."
for c in qmltestrunner6 /usr/lib/qt6/bin/qmltestrunner /usr/lib64/qt6/bin/qmltestrunner qmltestrunner; do RUNNER="$(command -v "$c" || true)"; [[ -n "$RUNNER" ]] && break; done
QT_QPA_PLATFORM=offscreen "$RUNNER" -input tests/tst_store.qml
if command -v qmllint >/dev/null; then
    qmllint contents/ui/*.qml | grep -i "error" && exit 1 || true
fi
echo "Tests passed"
