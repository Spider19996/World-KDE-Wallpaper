import QtQuick
import org.kde.plasma.plasma5support as P5Support

// Battery and screen lock state. Loaded through a Loader, so a missing module only turns the detection off.
Item {
    id: root

    // The lock state is polled (a tiny D-Bus call every few seconds), so only ask for it when it is needed
    property bool watchLock: false
    property bool onBattery: false
    property bool screenLocked: false

    P5Support.DataSource {
        engine: "powermanagement"
        connectedSources: ["AC Adapter", "Battery"]
        onDataChanged: {
            var ac = data["AC Adapter"], bat = data["Battery"];
            var plugged = ac ? ac["Plugged in"] !== false : true;
            var hasBattery = bat ? bat["Has Battery"] === true : false;
            root.onBattery = hasBattery && !plugged;
        }
    }

    P5Support.DataSource {
        engine: "executable"
        interval: 3000
        connectedSources: root.watchLock ? ["busctl --user call org.freedesktop.ScreenSaver /ScreenSaver org.freedesktop.ScreenSaver GetActive"] : []
        onNewData: function (source, d) { root.screenLocked = String(d["stdout"] || "").indexOf("true") >= 0; }
    }
    onWatchLockChanged: if (!watchLock) screenLocked = false
}
