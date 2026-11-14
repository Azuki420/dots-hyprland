pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Scope {
    id: root

    property string activeScreenName: ""

    Connections {
        target: GlobalStates
        function onAppDrawerOpenChanged() {
            if (GlobalStates.appDrawerOpen) {
                root.activeScreenName = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
            }
        }
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            GlobalStates.appDrawerOpen = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            visible: GlobalStates.appDrawerOpen && (modelData.name === root.activeScreenName)

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "quickshell:appDrawer"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (visible && GlobalStates.appDrawerOpen) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: Region {
                item: panelWindow.visible ? drawerContent.maskTarget : null
            }

            onVisibleChanged: {
                if (visible) {
                    GlobalFocusGrab.addDismissable(panelWindow);
                } else {
                    GlobalFocusGrab.removeDismissable(panelWindow);
                }
            }

            AppDrawerContent {
                id: drawerContent
                anchors.centerIn: parent
                visible: panelWindow.visible
            }
        }
    }

    IpcHandler {
        target: "appDrawer"

        function toggle(): void {
            if (!GlobalStates.appDrawerOpen) {
                root.activeScreenName = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
            }
            GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen;
        }

        function close(): void {
            GlobalStates.appDrawerOpen = false;
        }

        function open(): void {
            root.activeScreenName = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
            GlobalStates.appDrawerOpen = true;
        }
    }

    GlobalShortcut {
        name: "appDrawerToggle"
        description: Translation.tr("Toggle app drawer")
        onPressed: {
            if (!GlobalStates.appDrawerOpen) {
                root.activeScreenName = Hyprland.focusedMonitor?.name ?? (Quickshell.screens[0]?.name ?? "");
            }
            GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen;
        }
    }
}
