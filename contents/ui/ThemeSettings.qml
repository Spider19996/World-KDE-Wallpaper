pragma Singleton
import QtQuick

import "persist.js" as Persist

// Settings of the themes that are not part of a single wallpaper: like Substrate's theme store, one object that the
// settings window and the running wallpaper share, so a change shows at once and does not wait for "Apply". It is
// kept in the user's small memory (see persist.js) and read again at every start.
QtObject {
    id: store

    property bool hideBuiltin: Persist.get("hideBuiltin", "false") === "true"

    onHideBuiltinChanged: Persist.set("hideBuiltin", hideBuiltin ? "true" : "false")

    // Reads what another part of the desktop may have stored since
    function refresh() {
        var h = Persist.get("hideBuiltin", "false") === "true";
        if (h !== hideBuiltin) hideBuiltin = h;
    }
}
