import QtQuick
import QtQuick.Window
import org.kde.taskmanager as TaskManager

// True while a maximized or fullscreen window on this screen hides the desktop.
// Loaded through a Loader, so a missing module only disables the detection.
Item {
    id: root

    property bool covered: false

    function update() {
        var hidden = false;
        for (var i = 0; i < tasks.count && !hidden; i++) {
            var index = tasks.index(i, 0);
            hidden = tasks.data(index, TaskManager.AbstractTasksModel.IsMaximized) === true
                  || tasks.data(index, TaskManager.AbstractTasksModel.IsFullScreen) === true;
        }
        covered = hidden;
    }

    TaskManager.TasksModel {
        id: tasks
        groupMode: TaskManager.TasksModel.GroupDisabled
        filterByScreen: true
        filterByVirtualDesktop: true
        filterByActivity: true
        filterNotMinimized: true
        screenGeometry: Qt.rect(Screen.virtualX, Screen.virtualY, Screen.width, Screen.height)
        onCountChanged: refresh.restart()
        onDataChanged: refresh.restart()
        onRowsInserted: refresh.restart()
        onRowsRemoved: refresh.restart()
    }

    // Window changes come in bursts
    Timer {
        id: refresh
        interval: 150
        onTriggered: root.update()
    }

    Component.onCompleted: update()
}
