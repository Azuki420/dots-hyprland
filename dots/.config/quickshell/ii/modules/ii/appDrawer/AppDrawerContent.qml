pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    property alias maskTarget: contentCard
    property string query: ""

    width: implicitWidth
    height: implicitHeight
    implicitWidth: 640 + Appearance.sizes.elevationMargin * 2
    implicitHeight: 560 + Appearance.sizes.elevationMargin * 2

    readonly property var allApps: {
        const rawList = AppSearch.list || [];
        return Array.from(rawList)
            .filter(app => app && app.name && app.name.trim().length > 0)
            .sort((a, b) => (a.name || "").localeCompare(b.name || "", undefined, { sensitivity: "base" }));
    }

    readonly property var displayedApps: {
        if (!root.query || root.query.trim().length === 0) {
            return allApps;
        }
        const results = AppSearch.fuzzyQuery(root.query.trim());
        return results ? Array.from(results).filter(app => app && app.name) : [];
    }

    onDisplayedAppsChanged: {
        if (appScriptModel) {
            appScriptModel.values = root.displayedApps;
        }
    }

    function launchApp(entry) {
        if (!entry) return;
        GlobalStates.appDrawerOpen = false;
        try {
            if (!entry.runInTerminal) {
                entry.execute();
            } else {
                Quickshell.execDetached(["bash", '-c', `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(entry.command.join(' '))}'`]);
            }
        } catch (e) {
            console.error("[AppDrawer] Execution failed:", e);
            entry.execute();
        }
    }

    function focusSearch() {
        searchInput.forceActiveFocus();
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    onVisibleChanged: {
        if (visible) {
            searchInput.text = "";
            root.query = "";
            if (gridView && gridView.count > 0) {
                gridView.currentIndex = 0;
                gridView.positionViewAtBeginning();
            }
            focusTimer.start();
        }
    }

    StyledRectangularShadow {
        target: contentCard
    }

    Rectangle {
        id: contentCard
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colBackgroundSurfaceContainer
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
        clip: true

        // Search Bar Row
        RowLayout {
            id: searchBarRow
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 8
                bottomMargin: 8
                leftMargin: 14
                rightMargin: 14
            }
            height: 44
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: "apps"
                iconSize: Appearance.font.pixelSize.huge
            }

            ToolbarTextField {
                id: searchInput
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 40
                font.pixelSize: Appearance.font.pixelSize.small
                placeholderText: Translation.tr("Search applications...")
                focus: true

                onTextChanged: {
                    root.query = text;
                    if (gridView.count > 0) {
                        gridView.currentIndex = 0;
                    }
                }

                onAccepted: {
                    if (root.displayedApps.length > 0) {
                        root.launchApp(root.displayedApps[0]);
                    }
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Down) {
                        if (gridView.count > 0) {
                            gridView.forceActiveFocus();
                            if (gridView.currentIndex < 0) gridView.currentIndex = 0;
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Escape) {
                        if (searchInput.text !== "") {
                            searchInput.text = "";
                            event.accepted = true;
                        } else {
                            GlobalStates.appDrawerOpen = false;
                            event.accepted = true;
                        }
                    }
                }
            }

            IconToolbarButton {
                Layout.alignment: Qt.AlignVCenter
                visible: searchInput.text.length > 0
                text: "close"
                onClicked: {
                    searchInput.text = "";
                    searchInput.forceActiveFocus();
                }
                StyledToolTip {
                    text: Translation.tr("Clear search")
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: 8
                visible: searchInput.text.length === 0
                text: `${root.allApps.length} apps`
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        // Separator
        Rectangle {
            id: separator
            anchors {
                top: searchBarRow.bottom
                topMargin: 8
                left: parent.left
                right: parent.right
            }
            height: 1
            color: Appearance.colors.colOutlineVariant
        }

        // Grid View Area
        Item {
            id: gridArea
            anchors {
                top: separator.bottom
                bottom: parent.bottom
                left: parent.left
                right: parent.right
            }

            GridView {
                id: gridView
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                cellWidth: Math.floor((width - 8) / 6)
                cellHeight: 96
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: StyledScrollBar {}

                model: ScriptModel {
                    id: appScriptModel
                    objectProp: "id"
                    values: root.displayedApps
                }

                delegate: AppDrawerGridItem {
                    required property var modelData
                    required property int index

                    width: gridView.cellWidth
                    height: gridView.cellHeight
                    entry: modelData
                    itemIndex: index
                    query: root.query
                    isSelected: gridView.activeFocus && gridView.currentIndex === index
                    onActivated: root.launchApp(modelData)
                }

                Keys.onPressed: event => {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                        if (gridView.currentIndex >= 0 && gridView.currentIndex < root.displayedApps.length) {
                            root.launchApp(root.displayedApps[gridView.currentIndex]);
                            event.accepted = true;
                        }
                    } else if (event.key === Qt.Key_Up && gridView.currentIndex < 6) {
                        searchInput.forceActiveFocus();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Escape) {
                        GlobalStates.appDrawerOpen = false;
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Backspace) {
                        searchInput.forceActiveFocus();
                        if (searchInput.text.length > 0) {
                            searchInput.text = searchInput.text.slice(0, -1);
                        }
                        event.accepted = true;
                    } else if (event.text && event.text.length === 1 && event.key !== Qt.Key_Delete && event.text.charCodeAt(0) >= 0x20) {
                        searchInput.forceActiveFocus();
                        searchInput.text += event.text;
                        event.accepted = true;
                    }
                }
            }

            // Empty state
            ColumnLayout {
                anchors.centerIn: parent
                visible: root.displayedApps.length === 0
                spacing: 10

                MaterialSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    text: "search_off"
                    iconSize: 48
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: Translation.tr("No applications found")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
