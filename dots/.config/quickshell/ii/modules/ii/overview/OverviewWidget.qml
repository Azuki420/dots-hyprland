pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root
    required property var screen
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property var toplevels: ToplevelManager.toplevels
    // Clamp to avoid lock-screen temp workspace (2147483647 - N) leaking into UI
    readonly property int effectiveActiveWorkspaceId: Math.max(1, Math.min(100, monitor?.activeWorkspace?.id ?? 1))
    readonly property int workspacesShown: Config.options.overview.rows * Config.options.overview.columns
    readonly property int workspaceGroup: Math.floor((effectiveActiveWorkspaceId - 1) / workspacesShown)
    property bool monitorIsFocused: (Hyprland.focusedMonitor?.name == monitor.name)
    property var windows: HyprlandData.windowList
    property var windowByAddress: HyprlandData.windowByAddress
    property var windowAddresses: HyprlandData.addresses
    property var monitorData: HyprlandData.monitors.find(m => m.id === root.monitor?.id)
    property real scale: Config.options.overview.scale
    property color activeBorderColor: Appearance.colors.colSecondary

    property real workspaceImplicitWidth: (monitorData?.transform % 2 === 1) ? 
        ((monitor.height - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale) :
        ((monitor.width - monitorData?.reserved[0] - monitorData?.reserved[2]) * root.scale / monitor.scale)
    property real workspaceImplicitHeight: (monitorData?.transform % 2 === 1) ? 
        ((monitor.width - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale) :
        ((monitor.height - monitorData?.reserved[1] - monitorData?.reserved[3]) * root.scale / monitor.scale)
    property real largeWorkspaceRadius: Appearance.rounding.large
    property real smallWorkspaceRadius: Appearance.rounding.verysmall

    property real workspaceNumberMargin: 80
    property real workspaceNumberSize: 250 * monitor.scale
    property int workspaceZ: 0
    property int windowZ: 1
    property int windowDraggingZ: 99999
    property real workspaceSpacing: 5

    property string draggingAddress: ""
    property int draggingFromWorkspace: -1
    property int draggingTargetWorkspace: -1
    property string targetWindowAddress: ""
    property int targetWindowWorkspace: -1
    property string targetDropDirection: ""

    function calculateDropDirection(relX, relY) {
        if (relX >= 0.32 && relX <= 0.68 && relY >= 0.32 && relY <= 0.68) {
            return "swap";
        }
        const dLeft = relX;
        const dRight = 1 - relX;
        const dTop = relY;
        const dBottom = 1 - relY;
        const minD = Math.min(dLeft, dRight, dTop, dBottom);
        if (minD === dLeft) return "l";
        if (minD === dRight) return "r";
        if (minD === dTop) return "u";
        return "d";
    }

    function getTiledCountInWorkspace(wsId) {
        if (!wsId || wsId <= 0) return 0;
        const list = root.windows;
        if (!list) return 0;
        return list.filter(w => w && w.workspace && Number(w.workspace.id) === Number(wsId) && !w.floating).length;
    }

    function getSingleTiledWindowInWorkspace(wsId, excludeAddr) {
        if (!wsId || wsId <= 0) return null;
        const list = root.windows;
        if (!list) return null;
        const cleanExclude = excludeAddr ? (excludeAddr.startsWith("0x") ? excludeAddr : `0x${excludeAddr.replace(/^address:/, '')}`) : "";
        return list.find(w => {
            if (!w || !w.workspace || Number(w.workspace.id) !== Number(wsId) || w.floating) return false;
            const wAddr = w.address.startsWith("0x") ? w.address : `0x${w.address.replace(/^address:/, '')}`;
            if (cleanExclude && wAddr.toLowerCase() === cleanExclude.toLowerCase()) return false;
            return true;
        });
    }

    implicitWidth: overviewBackground.implicitWidth + Appearance.sizes.elevationMargin * 2
    implicitHeight: overviewBackground.implicitHeight + Appearance.sizes.elevationMargin * 2

    property Component windowComponent: OverviewWindow {}
    property list<OverviewWindow> windowWidgets: []
    
    function getWsRow(ws) {
        // 1-indexed workspace, 0-indexed row
        var normalRow = Math.floor((ws - 1) / Config.options.overview.columns) % Config.options.overview.rows;
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - normalRow - 1 : normalRow);
    }
    function getWsColumn(ws) {
        // 1-indexed workspace, 0-indexed column
        var normalCol = (ws - 1) % Config.options.overview.columns;
        return (Config.options.overview.orderRightLeft ? Config.options.overview.columns - normalCol - 1 : normalCol);
    }
    function getWsInCell(ri, ci) {
        // 1-indexed workspace, 0-indexed row and column index
        return (Config.options.overview.orderBottomUp ? Config.options.overview.rows - ri - 1 : ri) * Config.options.overview.columns + (Config.options.overview.orderRightLeft ? Config.options.overview.columns - ci - 1 : ci) + 1
    }

    StyledRectangularShadow {
        target: overviewBackground
    }
    Rectangle { // Background
        id: overviewBackground
        property real padding: 10
        anchors.fill: parent
        anchors.margins: Appearance.sizes.elevationMargin

        implicitWidth: workspaceColumnLayout.implicitWidth + padding * 2
        implicitHeight: workspaceColumnLayout.implicitHeight + padding * 2
        radius: root.largeWorkspaceRadius + padding
        color: Appearance.colors.colBackgroundSurfaceContainer

        Column { // Workspaces
            id: workspaceColumnLayout

            z: root.workspaceZ
            anchors.centerIn: parent
            spacing: workspaceSpacing
            
            Repeater {
                model: Config.options.overview.rows
                delegate: Row {
                    id: row
                    required property int index
                    spacing: workspaceSpacing

                    Repeater { // Workspace repeater
                        model: Config.options.overview.columns
                        Rectangle { // Workspace
                            id: workspace
                            required property int index
                            property int colIndex: index
                            property int workspaceValue: root.workspaceGroup * root.workspacesShown + getWsInCell(row.index, colIndex)
                            property color defaultWorkspaceColor: Appearance.colors.colSurfaceContainerLow
                            property color hoveredWorkspaceColor: ColorUtils.mix(defaultWorkspaceColor, Appearance.colors.colLayer1Hover, 0.1)
                            property color hoveredBorderColor: Appearance.colors.colLayer2Hover
                            property int wsTiledCount: root.getTiledCountInWorkspace(workspace.workspaceValue)
                            property bool hoveredWhileDragging: {
                                if (root.draggingAddress === "") return false;
                                if (Number(root.draggingFromWorkspace) === Number(workspace.workspaceValue)) return false;
                                // Only show workspace-level indicator when workspace has 0 tiles (empty workspace)!
                                if (wsTiledCount > 0) return false;
                                if (Number(root.targetWindowWorkspace) === Number(workspace.workspaceValue)) return true;
                                if (Number(root.draggingTargetWorkspace) === Number(workspace.workspaceValue)) return true;
                                return false;
                            }

                            implicitWidth: root.workspaceImplicitWidth
                            implicitHeight: root.workspaceImplicitHeight
                            width: root.workspaceImplicitWidth
                            height: root.workspaceImplicitHeight
                            color: hoveredWhileDragging ? hoveredWorkspaceColor : defaultWorkspaceColor
                            property bool workspaceAtLeft: colIndex === 0
                            property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                            property bool workspaceAtTop: row.index === 0
                            property bool workspaceAtBottom: row.index === Config.options.overview.rows - 1
                            topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                            border.width: 2
                            border.color: hoveredWhileDragging ? hoveredBorderColor : "transparent"

                            StyledText {
                                anchors.centerIn: parent
                                text: workspace.workspaceValue
                                font {
                                    pixelSize: root.workspaceNumberSize * root.scale
                                    weight: Font.DemiBold
                                    family: Appearance.font.family.expressive
                                }
                                color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.8)
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            MouseArea {
                                id: workspaceArea
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onPressed: {
                                    if (root.draggingTargetWorkspace === -1) {
                                        GlobalStates.overviewOpen = false
                                        Hyprland.dispatch(`hl.dsp.focus({ workspace = ${workspace.workspaceValue} })`)
                                    }
                                }
                            }

                            DropArea {
                                anchors.fill: parent
                                onEntered: (drag) => {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (wsTiledCount === 1) {
                                        const singleWin = root.getSingleTiledWindowInWorkspace(workspace.workspaceValue, root.draggingAddress)
                                        if (singleWin) {
                                            const addr = singleWin.address.startsWith("0x") ? singleWin.address : `0x${singleWin.address}`
                                            root.targetWindowAddress = addr
                                            root.targetWindowWorkspace = workspace.workspaceValue
                                            if (drag && typeof drag.x === 'number' && width > 0) {
                                                const relX = drag.x / width
                                                root.targetDropDirection = (relX < 0.5) ? "l" : "r"
                                            } else {
                                                root.targetDropDirection = ""
                                            }
                                        }
                                    } else {
                                        root.targetDropDirection = ""
                                    }
                                }
                                onPositionChanged: (drag) => {
                                    root.draggingTargetWorkspace = workspace.workspaceValue
                                    if (wsTiledCount === 1 && root.targetWindowAddress === "") {
                                        const singleWin = root.getSingleTiledWindowInWorkspace(workspace.workspaceValue, root.draggingAddress)
                                        if (singleWin) {
                                            const addr = singleWin.address.startsWith("0x") ? singleWin.address : `0x${singleWin.address}`
                                            root.targetWindowAddress = addr
                                            root.targetWindowWorkspace = workspace.workspaceValue
                                        }
                                    }
                                    if (drag && typeof drag.x === 'number' && width > 0) {
                                        const relX = drag.x / width
                                        root.targetDropDirection = (relX < 0.5) ? "l" : "r"
                                    }
                                }
                                onExited: {
                                    if (root.draggingTargetWorkspace == workspace.workspaceValue) {
                                        root.draggingTargetWorkspace = -1
                                    }
                                    if (root.targetWindowWorkspace == workspace.workspaceValue) {
                                        root.targetWindowAddress = ""
                                        root.targetWindowWorkspace = -1
                                    }
                                    root.targetDropDirection = ""
                                }
                            }

                        }
                    }
                }
            }
        }

        Item { // Windows & focused workspace indicator
            id: windowSpace
            anchors.centerIn: parent
            implicitWidth: workspaceColumnLayout.implicitWidth
            implicitHeight: workspaceColumnLayout.implicitHeight

            Repeater { // Window repeater
                model: ScriptModel {
                    values: {
                        return ToplevelManager.toplevels.values.filter((toplevel) => {
                            const address = `0x${toplevel.HyprlandToplevel?.address}`
                            var win = windowByAddress[address]
                            const inWorkspaceGroup = (root.workspaceGroup * root.workspacesShown < win?.workspace?.id && win?.workspace?.id <= (root.workspaceGroup + 1) * root.workspacesShown)
                            return inWorkspaceGroup;
                        })
                    }
                }
                delegate: OverviewWindow {
                    id: window
                    required property var modelData
                    property int monitorId: windowData?.monitor
                    property var monitor: HyprlandData.monitors.find(m => m.id == monitorId)
                    property var address: `0x${modelData.HyprlandToplevel.address}`
                    toplevel: modelData
                    monitorData: this.monitor
                    scale: root.scale
                    widgetMonitor: HyprlandData.monitors.find(m => m.id == root.monitor.id)
                    windowData: windowByAddress[address]

                    targetDropDirection: (root.targetWindowAddress === window.address) ? root.targetDropDirection : ""
                    isResizeActive: dragArea.isResizing
                    splitDelta: dragArea.currentSplitDelta

                    onStartCornerResize: (mouseX, mouseY) => {
                        dragArea.isResizing = true
                        dragArea.resizeStartX = mouseX
                        dragArea.resizeStartY = mouseY
                        dragArea.resizeStartWidth = window.width
                        dragArea.resizeStartHeight = window.height
                        dragArea.currentSplitDelta = 0
                        dragArea.currentWidthDelta = 0
                        dragArea.currentHeightDelta = 0
                    }

                    onUpdateCornerResize: (mouseX, mouseY) => {
                        if (dragArea.isResizing) {
                            const dx = mouseX - dragArea.resizeStartX
                            const dy = mouseY - dragArea.resizeStartY
                            if (windowData?.floating) {
                                dragArea.currentWidthDelta = dx
                                dragArea.currentHeightDelta = dy
                                window.width = Math.max(80, dragArea.resizeStartWidth + dx)
                                window.height = Math.max(60, dragArea.resizeStartHeight + dy)
                            } else {
                                dragArea.currentSplitDelta = dx / (root.workspaceImplicitWidth * 0.4)
                            }
                        }
                    }

                    onEndCornerResize: (mouse) => {
                        dragArea.finishResize()
                    }

                    property bool atInitPosition: (initX == x && initY == y)

                    // Offset on the canvas
                    property int workspaceColIndex: getWsColumn(windowData?.workspace.id)
                    property int workspaceRowIndex: getWsRow(windowData?.workspace.id)
                    xOffset: (root.workspaceImplicitWidth + workspaceSpacing) * workspaceColIndex
                    yOffset: (root.workspaceImplicitHeight + workspaceSpacing) * workspaceRowIndex
                    property real xWithinWorkspaceWidget: Math.max((windowData?.at[0] - (monitor?.x ?? 0) - (monitorData?.reserved?.[0] ?? 0)) * window.widthRatio * root.scale, 0)
                    property real yWithinWorkspaceWidget: Math.max((windowData?.at[1] - (monitor?.y ?? 0) - (monitorData?.reserved?.[1] ?? 0)) * window.heightRatio * root.scale, 0)

                    // Radius
                    property real minRadius: Appearance.rounding.small
                    property bool workspaceAtLeft: workspaceColIndex === 0
                    property bool workspaceAtRight: workspaceColIndex === Config.options.overview.columns - 1
                    property bool workspaceAtTop: workspaceRowIndex === 0
                    property bool workspaceAtBottom: workspaceRowIndex === Config.options.overview.rows - 1
                    property bool workspaceAtTopLeft: (workspaceAtLeft && workspaceAtTop) 
                    property bool workspaceAtTopRight: (workspaceAtRight && workspaceAtTop) 
                    property bool workspaceAtBottomLeft: (workspaceAtLeft && workspaceAtBottom) 
                    property bool workspaceAtBottomRight: (workspaceAtRight && workspaceAtBottom) 
                    property real distanceFromLeftEdge: xWithinWorkspaceWidget
                    property real distanceFromRightEdge: root.workspaceImplicitWidth - (xWithinWorkspaceWidget + targetWindowWidth)
                    property real distanceFromTopEdge: yWithinWorkspaceWidget
                    property real distanceFromBottomEdge: root.workspaceImplicitHeight - (yWithinWorkspaceWidget + targetWindowHeight)
                    property real distanceFromTopLeftCorner: Math.max(distanceFromLeftEdge, distanceFromTopEdge)
                    property real distanceFromTopRightCorner: Math.max(distanceFromRightEdge, distanceFromTopEdge)
                    property real distanceFromBottomLeftCorner: Math.max(distanceFromLeftEdge, distanceFromBottomEdge)
                    property real distanceFromBottomRightCorner: Math.max(distanceFromRightEdge, distanceFromBottomEdge)
                    topLeftRadius: Math.max((workspaceAtTopLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopLeftCorner, minRadius)
                    topRightRadius: Math.max((workspaceAtTopRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromTopRightCorner, minRadius)
                    bottomLeftRadius: Math.max((workspaceAtBottomLeft ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomLeftCorner, minRadius)
                    bottomRightRadius: Math.max((workspaceAtBottomRight ? root.largeWorkspaceRadius : root.smallWorkspaceRadius) - distanceFromBottomRightCorner, minRadius)

                    Timer {
                        id: updateWindowPosition
                        interval: Config.options.hacks.arbitraryRaceConditionDelay
                        repeat: false
                        running: false
                        onTriggered: {
                            window.x = Math.round(xWithinWorkspaceWidget + xOffset)
                            window.y = Math.round(yWithinWorkspaceWidget + yOffset)
                        }
                    }

                    z: Drag.active ? root.windowDraggingZ : (root.windowZ + windowData?.floating + windowData?.fullscreen * 2)
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    DropArea {
                        id: tileDropArea
                        anchors.fill: parent
                        enabled: root.draggingAddress !== "" && root.draggingAddress !== window.address

                        function updateDropDirection(drag) {
                            if (!drag || typeof drag.x !== 'number' || width <= 0) {
                                root.targetDropDirection = ""
                                return
                            }
                            const targetWsId = windowData?.workspace?.id ?? -1
                            const sameWorkspace = (Number(root.draggingFromWorkspace) === Number(targetWsId))
                            const wsTiledCount = root.getTiledCountInWorkspace(targetWsId)
                            const isTargetFloating = windowData?.floating ?? false
                            const draggedWin = root.windowByAddress[root.draggingAddress]
                            const isDraggedFloating = draggedWin?.floating ?? false

                            if (sameWorkspace && wsTiledCount === 2 && !isTargetFloating && !isDraggedFloating) {
                                // Exactly 2 tiles on this workspace: ONLY allow swapping left/right, never split!
                                root.targetDropDirection = "swap"
                            } else if (height > width) {
                                // Taller than wide (like a vertical column): splits vertically into Top ("u") or Bottom ("d")!
                                const relY = drag.y / height
                                root.targetDropDirection = (relY < 0.5) ? "u" : "d"
                            } else {
                                // Wider than tall (like 1-tile workspace, or stacked right tiles): splits horizontally into Left ("l") or Right ("r")!
                                const relX = drag.x / width
                                root.targetDropDirection = (relX < 0.5) ? "l" : "r"
                            }
                        }

                        onEntered: (drag) => {
                            root.targetWindowAddress = window.address
                            const targetWsId = windowData?.workspace?.id ?? -1
                            root.targetWindowWorkspace = targetWsId
                            updateDropDirection(drag)
                        }

                        onPositionChanged: (drag) => {
                            root.targetWindowAddress = window.address
                            const targetWsId = windowData?.workspace?.id ?? -1
                            root.targetWindowWorkspace = targetWsId
                            updateDropDirection(drag)
                        }
                        onExited: {
                            if (root.targetWindowAddress === window.address) {
                                root.targetWindowAddress = ""
                                root.targetDropDirection = ""
                            }
                        }
                    }

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: hovered = true
                        onExited: hovered = false
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        drag.target: parent

                        property bool isResizing: false
                        property real resizeStartX: 0
                        property real resizeStartY: 0
                        property real resizeStartWidth: 0
                        property real resizeStartHeight: 0
                        property real currentSplitDelta: 0
                        property real currentWidthDelta: 0
                        property real currentHeightDelta: 0

                        property bool wasDragged: false
                        property real pressX: 0
                        property real pressY: 0

                        function getScreenCoords(mx, my) {
                            const globalPt = dragArea.mapToItem(null, mx, my)
                            const screenX = Math.round((root.monitorData?.x ?? 0) + globalPt.x)
                            const screenY = Math.round((root.monitorData?.y ?? 0) + globalPt.y)
                            return { x: screenX, y: screenY }
                        }

                        function finishResize(mouse) {
                            if (!isResizing) return;
                            isResizing = false
                            const coords = mouse ? getScreenCoords(mouse.x, mouse.y) : getScreenCoords(dragArea.width, dragArea.height)
                            if (windowData?.floating) {
                                if (Math.abs(currentWidthDelta) > 5 || Math.abs(currentHeightDelta) > 5) {
                                    const exactPixelW = Math.max(100, Math.round(window.width / (root.scale * window.widthRatio)))
                                    const exactPixelH = Math.max(100, Math.round(window.height / (root.scale * window.heightRatio)))
                                    Hyprland.dispatch(`hl.dsp.window.resize({ size = "${exactPixelW} ${exactPixelH}", exact = true, window = "address:${window.windowData?.address}" })`)
                                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                }
                                updateWindowPosition.restart()
                            } else {
                                if (Math.abs(currentSplitDelta) >= 0.03) {
                                    const deltaStr = (currentSplitDelta >= 0 ? "+" : "") + currentSplitDelta.toFixed(2)
                                    Hyprland.dispatch(`hl.dsp.focus({ window = "address:${window.windowData?.address}" })`)
                                    Hyprland.dispatch(`hl.dsp.layout("splitratio ${deltaStr}")`)
                                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                    HyprlandData.updateAll()
                                }
                                currentSplitDelta = 0
                                updateWindowPosition.restart()
                            }
                        }

                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y !== 0) {
                                if (!windowData?.floating) {
                                    const coords = getScreenCoords(wheel.x, wheel.y)
                                    const delta = wheel.angleDelta.y > 0 ? "+0.05" : "-0.05"
                                    Hyprland.dispatch(`hl.dsp.focus({ window = "address:${windowData?.address}" })`)
                                    Hyprland.dispatch(`hl.dsp.layout("splitratio ${delta}")`)
                                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                    HyprlandData.updateAll()
                                    updateWindowPosition.restart()
                                    wheel.accepted = true
                                }
                            }
                        }

                        onPressed: (mouse) => {
                            wasDragged = false
                            pressX = mouse.x
                            pressY = mouse.y

                            if (mouse.button === Qt.RightButton) {
                                drag.target = null
                                isResizing = true
                                resizeStartX = mouse.x
                                resizeStartY = mouse.y
                                resizeStartWidth = window.width
                                resizeStartHeight = window.height
                                currentSplitDelta = 0
                                currentWidthDelta = 0
                                currentHeightDelta = 0
                            } else if (mouse.button === Qt.LeftButton) {
                                drag.target = parent
                                isResizing = false
                                root.targetWindowAddress = ""
                                root.targetWindowWorkspace = -1
                                root.targetDropDirection = ""
                                root.draggingAddress = window.address
                                root.draggingFromWorkspace = windowData?.workspace.id
                                window.pressed = true
                                window.Drag.active = true
                                window.Drag.source = window
                                window.Drag.hotSpot.x = mouse.x
                                window.Drag.hotSpot.y = mouse.y
                            }
                        }

                        onPositionChanged: (mouse) => {
                            if (!isResizing && (Math.abs(mouse.x - pressX) > 6 || Math.abs(mouse.y - pressY) > 6)) {
                                wasDragged = true
                            }

                            if (isResizing) {
                                const dx = mouse.x - resizeStartX
                                const dy = mouse.y - resizeStartY
                                if (windowData?.floating) {
                                    currentWidthDelta = dx
                                    currentHeightDelta = dy
                                    window.width = Math.max(80, resizeStartWidth + dx)
                                    window.height = Math.max(60, resizeStartHeight + dy)
                                } else {
                                    currentSplitDelta = dx / (root.workspaceImplicitWidth * 0.4)
                                }
                            }
                        }

                        onReleased: (mouse) => {
                            if (isResizing) {
                                finishResize(mouse)
                                return
                            }

                            if (mouse.button === Qt.LeftButton) {
                                const coords = getScreenCoords(mouse.x, mouse.y)
                                const targetWs = (root.targetWindowWorkspace !== -1 && root.targetWindowAddress !== "") ? root.targetWindowWorkspace : root.draggingTargetWorkspace
                                const targetWinAddr = root.targetWindowAddress
                                const dropDir = root.targetDropDirection
                                
                                window.pressed = false
                                window.Drag.active = false
                                const draggedAddr = window.windowData?.address
                                const fromWs = root.draggingFromWorkspace

                                root.draggingAddress = ""
                                root.draggingFromWorkspace = -1
                                root.draggingTargetWorkspace = -1
                                root.targetWindowAddress = ""
                                root.targetWindowWorkspace = -1
                                root.targetDropDirection = ""

                                if (targetWinAddr !== "" && targetWinAddr !== window.address) {
                                    // Dropped on a specific target window!
                                    const targetAddrClean = targetWinAddr.startsWith("address:") ? targetWinAddr : `address:${targetWinAddr}`
                                    const draggedAddrClean = draggedAddr.startsWith("address:") ? draggedAddr : `address:${draggedAddr}`

                                    if (dropDir === "swap") {
                                        if (fromWs !== targetWs) {
                                            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, follow = false, window = "${draggedAddrClean}" })`)
                                        }
                                        Hyprland.dispatch(`hl.dsp.focus({ window = "${draggedAddrClean}" })`)
                                        Hyprland.dispatch(`hl.dsp.window.swap({ target = "${targetAddrClean}" })`)
                                    } else {
                                        if (fromWs !== targetWs) {
                                            // Focus target window first so dwindle splits that specific window!
                                            Hyprland.dispatch(`hl.dsp.focus({ window = "${targetAddrClean}" })`)
                                            Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, follow = false, window = "${draggedAddrClean}" })`)
                                            const shouldSwap = (dropDir === "l" || dropDir === "u")
                                            if (shouldSwap) {
                                                Hyprland.dispatch(`hl.dsp.focus({ window = "${draggedAddrClean}" })`)
                                                Hyprland.dispatch(`hl.dsp.window.swap({ target = "${targetAddrClean}" })`)
                                            }
                                        } else {
                                            if (dropDir !== "") {
                                                Hyprland.dispatch(`hl.dsp.focus({ window = "${targetAddrClean}" })`)
                                                Hyprland.dispatch(`hl.dsp.focus({ window = "${draggedAddrClean}" })`)
                                                Hyprland.dispatch(`hl.dsp.window.move({ direction = "${dropDir}" })`)
                                            }
                                        }
                                    }
                                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                    HyprlandData.updateAll()
                                    updateWindowPosition.restart()
                                } else if (targetWs !== -1 && targetWs !== fromWs) {
                                    // Dropped on empty workspace space
                                    const targetWsTiledCount = root.getTiledCountInWorkspace(targetWs)
                                    if (targetWsTiledCount <= 1) {
                                        const draggedAddrClean = draggedAddr.startsWith("address:") ? draggedAddr : `address:${draggedAddr}`
                                        Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${targetWs}, follow = false, window = "${draggedAddrClean}" })`)
                                        if (targetWsTiledCount === 1 && (dropDir === "l" || dropDir === "u")) {
                                            const existingWin = root.getSingleTiledWindowInWorkspace(targetWs, draggedAddrClean)
                                            if (existingWin) {
                                                const existingAddr = existingWin.address.startsWith("address:") ? existingWin.address : `address:${existingWin.address}`
                                                Hyprland.dispatch(`hl.dsp.focus({ window = "${draggedAddrClean}" })`)
                                                Hyprland.dispatch(`hl.dsp.window.swap({ target = "${existingAddr}" })`)
                                            }
                                        }
                                        Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                        HyprlandData.updateAll()
                                        updateWindowPosition.restart()
                                    } else {
                                        updateWindowPosition.restart()
                                    }
                                } else {
                                    // Same workspace on empty space
                                    if (!window.windowData?.floating) {
                                        updateWindowPosition.restart()
                                        return
                                    }
                                    const percentageX = (window.x - xOffset) / root.workspaceImplicitWidth
                                    const percentageY = (window.y - yOffset) / root.workspaceImplicitHeight
                                    Hyprland.dispatch(`hl.dsp.window.move({ x = "${percentageX * root.screen.width}", y = "${percentageY * root.screen.height}", window = "address:${draggedAddr}" })`)
                                    Hyprland.dispatch(`hl.dsp.cursor.move({ x = ${coords.x}, y = ${coords.y} })`)
                                    updateWindowPosition.restart()
                                }
                            }
                        }

                        onClicked: (event) => {
                            if (!windowData || isResizing || wasDragged) return;

                            if (event.button === Qt.LeftButton) {
                                GlobalStates.overviewOpen = false
                                Hyprland.dispatch(`hl.dsp.focus({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            } else if (event.button === Qt.MiddleButton) {
                                Hyprland.dispatch(`hl.dsp.window.close({window = "address:${windowData.address}"})`)
                                event.accepted = true
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: false
                            alternativeVisibleCondition: dragArea.containsMouse && !window.Drag.active && !dragArea.isResizing
                            text: `${windowData?.title}\n[${windowData?.class}] ${windowData?.xwayland ? "[XWayland] " : ""}`.trim()
                        }
                    }
                }
            }

            Rectangle { // Focused workspace indicator
                id: focusedWorkspaceIndicator
                property int rowIndex: getWsRow(root.effectiveActiveWorkspaceId)
                property int colIndex: getWsColumn(root.effectiveActiveWorkspaceId)
                x: (root.workspaceImplicitWidth + workspaceSpacing) * colIndex
                y: (root.workspaceImplicitHeight + workspaceSpacing) * rowIndex
                z: root.windowZ
                width: root.workspaceImplicitWidth
                height: root.workspaceImplicitHeight
                color: "transparent"
                property bool workspaceAtLeft: colIndex === 0
                property bool workspaceAtRight: colIndex === Config.options.overview.columns - 1
                property bool workspaceAtTop: rowIndex === 0
                property bool workspaceAtBottom: rowIndex === Config.options.overview.rows - 1
                topLeftRadius: (workspaceAtLeft && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                topRightRadius: (workspaceAtRight && workspaceAtTop) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomLeftRadius: (workspaceAtLeft && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                bottomRightRadius: (workspaceAtRight && workspaceAtBottom) ? root.largeWorkspaceRadius : root.smallWorkspaceRadius
                border.width: 2
                border.color: root.activeBorderColor
                Behavior on x {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on y {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
                Behavior on topLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on topRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomLeftRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                Behavior on bottomRightRadius {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
            }
        }
    }
}
