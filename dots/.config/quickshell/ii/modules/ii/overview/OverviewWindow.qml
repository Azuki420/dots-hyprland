pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

Item { // Window
    id: root
    property var toplevel
    property var windowData
    property var monitorData
    property var scale
    property bool restrictToWorkspace: true
    property real widthRatio: {
        if (!widgetMonitor || !monitorData) return 1;
        const wWidth = (widgetMonitor.transform & 1) ? widgetMonitor.height : widgetMonitor.width;
        const mWidth = (monitorData.transform & 1) ? monitorData.height : monitorData.width;
        const wRes = widgetMonitor.reserved ?? [0, 0, 0, 0];
        const mRes = monitorData.reserved ?? [0, 0, 0, 0];
        const widgetUsableWidth = wWidth - (wRes[0] ?? 0) - (wRes[2] ?? 0);
        const monitorUsableWidth = mWidth - (mRes[0] ?? 0) - (mRes[2] ?? 0);
        const baseRatio = (widgetUsableWidth > 0 && monitorUsableWidth > 0) ? (widgetUsableWidth / monitorUsableWidth) : 1;
        const scaleRatio = ((monitorData.scale ?? 1) / (widgetMonitor.scale ?? 1));
        return baseRatio * scaleRatio;
    }
    property real heightRatio: {
        if (!widgetMonitor || !monitorData) return 1;
        const wHeight = (widgetMonitor.transform & 1) ? widgetMonitor.width : widgetMonitor.height;
        const mHeight = (monitorData.transform & 1) ? monitorData.width : monitorData.height;
        const wRes = widgetMonitor.reserved ?? [0, 0, 0, 0];
        const mRes = monitorData.reserved ?? [0, 0, 0, 0];
        const widgetUsableHeight = wHeight - (wRes[1] ?? 0) - (wRes[3] ?? 0);
        const monitorUsableHeight = mHeight - (mRes[1] ?? 0) - (mRes[3] ?? 0);
        const baseRatio = (widgetUsableHeight > 0 && monitorUsableHeight > 0) ? (widgetUsableHeight / monitorUsableHeight) : 1;
        const scaleRatio = ((monitorData.scale ?? 1) / (widgetMonitor.scale ?? 1));
        return baseRatio * scaleRatio;
    }
    property real initX: {
        const leftRes = monitorData?.reserved?.[0] ?? 0;
        return Math.max((windowData?.at[0] - (monitorData?.x ?? 0) - leftRes) * widthRatio * root.scale, 0) + xOffset;
    }

    property real initY: {
        const topRes = monitorData?.reserved?.[1] ?? 0;
        return Math.max((windowData?.at[1] - (monitorData?.y ?? 0) - topRes) * heightRatio * root.scale, 0) + yOffset;
    }
    property real xOffset: 0
    property real yOffset: 0
    property var widgetMonitor
    property int widgetMonitorId: widgetMonitor.id

    property var targetWindowWidth: windowData?.size[0] * scale * widthRatio
    property var targetWindowHeight: windowData?.size[1] * scale * heightRatio
    property bool hovered: false
    property bool pressed: false

    property bool centerIcons: Config.options.overview.centerIcons
    property real iconGapRatio: 0.06
    property real iconToWindowRatio: centerIcons ? 0.35 : 0.15
    property real xwaylandIndicatorToIconRatio: 0.35
    property real iconToWindowRatioCompact: 0.6
    property string iconPath: Quickshell.iconPath(AppSearch.guessIcon(windowData?.class), "image-missing")
    property bool compactMode: Appearance.font.pixelSize.smaller * 4 > targetWindowHeight || Appearance.font.pixelSize.smaller * 4 > targetWindowWidth

    property bool indicateXWayland: windowData?.xwayland ?? false

    // Dwindle Docking & Resize states
    property string targetDropDirection: ""
    property bool isResizeActive: false
    property real splitDelta: 0
    signal startCornerResize(real mouseX, real mouseY)
    signal updateCornerResize(real mouseX, real mouseY)
    signal endCornerResize(var mouse)

    // Fallback & recovery states
    property var lastSnapshotResult: null
    property bool screencopyFailed: false
    property int recoveryAttempts: 0
    readonly property int maxRecoveryAttempts: 5

    function takeSnapshot() {
        if (windowPreview.hasContent && !root.screencopyFailed) {
            windowPreview.grabToImage(function(result) {
                if (result && result.url) {
                    root.lastSnapshotResult = result;
                    fallbackImage.source = result.url;
                }
            });
        }
    }

    onTargetWindowWidthChanged: {
        root.recoveryAttempts = 0;
        if (GlobalStates.overviewOpen) {
            screencopyRecoverTimer.restart();
        }
    }
    onTargetWindowHeightChanged: {
        root.recoveryAttempts = 0;
        if (GlobalStates.overviewOpen) {
            screencopyRecoverTimer.restart();
        }
    }

    Connections {
        target: GlobalStates
        function onOverviewOpenChanged() {
            if (GlobalStates.overviewOpen) {
                root.screencopyFailed = false;
                root.recoveryAttempts = 0;
                screencopyRecoverTimer.restart();
            } else {
                snapshotIntervalTimer.stop();
                snapshotDebounceTimer.stop();
                screencopyRecoverTimer.stop();
                reconnectTimer.stop();
            }
        }
    }

    Timer {
        id: snapshotDebounceTimer
        interval: 100
        repeat: false
        onTriggered: root.takeSnapshot()
    }

    Timer {
        id: snapshotIntervalTimer
        interval: 2000
        repeat: true
        running: GlobalStates.overviewOpen && windowPreview.hasContent && !root.screencopyFailed
        onTriggered: root.takeSnapshot()
    }

    Timer {
        id: screencopyRecoverTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (GlobalStates.overviewOpen && root.toplevel && !windowPreview.hasContent) {
                if (root.recoveryAttempts < root.maxRecoveryAttempts) {
                    root.recoveryAttempts++;
                    windowPreview.captureSource = null;
                    reconnectTimer.restart();
                }
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 50
        repeat: false
        onTriggered: {
            if (GlobalStates.overviewOpen && root.toplevel) {
                windowPreview.captureSource = root.toplevel;
            }
        }
    }

    x: initX
    y: initY
    width: targetWindowWidth
    height: targetWindowHeight
    opacity: windowData.monitor == widgetMonitorId ? 1 : 0.4

    property real topLeftRadius
    property real topRightRadius
    property real bottomLeftRadius
    property real bottomRightRadius

    layer.enabled: true
    layer.effect: OpacityMask {
        maskSource: Rectangle {
            width: root.width
            height: root.height
            topLeftRadius: root.topLeftRadius
            topRightRadius: root.topRightRadius
            bottomRightRadius: root.bottomRightRadius
            bottomLeftRadius: root.bottomLeftRadius
        }
    }

    Behavior on x {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on y {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on width {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }
    Behavior on height {
        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
    }

    // 1. Base card background for when no frame is captured yet
    Rectangle {
        id: fallbackBackground
        anchors.fill: parent
        color: Appearance.colors.colSurfaceContainerHigh
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
    }

    // 2. Fallback grabbed image (in-memory image from grabToImage)
    Image {
        id: fallbackImage
        anchors.fill: parent
        fillMode: Image.Stretch
        visible: status === Image.Ready && (!windowPreview.hasContent || root.screencopyFailed)
        cache: false
    }

    // 3. Live screencopy preview
    ScreencopyView {
        id: windowPreview
        anchors.fill: parent
        captureSource: GlobalStates.overviewOpen ? root.toplevel : null
        live: true
        visible: hasContent && !root.screencopyFailed

        onHasContentChanged: {
            if (hasContent) {
                root.screencopyFailed = false;
                root.recoveryAttempts = 0;
                snapshotDebounceTimer.restart();
            } else {
                root.screencopyFailed = true;
                if (GlobalStates.overviewOpen && root.toplevel) {
                    screencopyRecoverTimer.restart();
                }
            }
        }

        onSourceSizeChanged: {
            if (hasContent) {
                snapshotDebounceTimer.restart();
            }
        }
    }

    // 4. Color overlay for interactions (hover/active/border)
    Rectangle {
        id: interactionOverlay
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomRightRadius: root.bottomRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        color: pressed ? ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.5) : 
            hovered ? ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.7) : 
            ColorUtils.transparentize(Appearance.colors.colLayer2)
        border.color: root.isResizeActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.m3colors.m3outline, 0.88)
        border.width: root.isResizeActive ? 2 : 1
    }

    // 5. Window App Icon
    StyledImage {
        id: windowIcon
        property real baseSize: Math.min(root.targetWindowWidth, root.targetWindowHeight)
        anchors {
            top: root.centerIcons ? undefined : parent.top
            left: root.centerIcons ? undefined : parent.left
            centerIn: root.centerIcons ? parent : undefined
            margins: baseSize * root.iconGapRatio
        }
        property var iconSize: {
            return baseSize * (root.compactMode ? root.iconToWindowRatioCompact : root.iconToWindowRatio);
        }
        mipmap: true
        Layout.alignment: Qt.AlignHCenter
        source: root.iconPath
        width: iconSize
        height: iconSize

        Behavior on width {
            animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
        }
        Behavior on height {
            animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
        }
    }

    // 6. Dwindle Docking Preview Indicator (when another window is dragged over this window)
    Rectangle {
        id: dockingPreview
        visible: root.targetDropDirection !== ""
        z: 15
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.65)
        border.color: Appearance.colors.colPrimary
        border.width: 2
        topLeftRadius: (root.targetDropDirection === "r" || root.targetDropDirection === "d") ? Appearance.rounding.small : root.topLeftRadius
        topRightRadius: (root.targetDropDirection === "l" || root.targetDropDirection === "d") ? Appearance.rounding.small : root.topRightRadius
        bottomLeftRadius: (root.targetDropDirection === "r" || root.targetDropDirection === "u") ? Appearance.rounding.small : root.bottomLeftRadius
        bottomRightRadius: (root.targetDropDirection === "l" || root.targetDropDirection === "u") ? Appearance.rounding.small : root.bottomRightRadius

        x: {
            if (!visible) return 0
            if (root.targetDropDirection === "r") return parent.width / 2
            return 0
        }
        y: {
            if (!visible) return 0
            if (root.targetDropDirection === "d") return parent.height / 2
            return 0
        }
        width: {
            if (!visible) return parent.width
            if (root.targetDropDirection === "l" || root.targetDropDirection === "r") return parent.width / 2
            return parent.width
        }
        height: {
            if (!visible) return parent.height
            if (root.targetDropDirection === "u" || root.targetDropDirection === "d") return parent.height / 2
            return parent.height
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 22
            color: Appearance.colors.colOnPrimary
            text: {
                switch(root.targetDropDirection) {
                    case "l": return "arrow_left"
                    case "r": return "arrow_right"
                    case "u": return "arrow_drop_up"
                    case "d": return "arrow_drop_down"
                    case "swap": return "swap_horiz"
                    default: return "add"
                }
            }
        }
    }

    // 7. Resizing Status Indicator
    Rectangle {
        id: resizeIndicator
        visible: root.isResizeActive
        z: 20
        anchors.centerIn: parent
        implicitWidth: resizeText.implicitWidth + 24
        implicitHeight: 30
        radius: Appearance.rounding.full
        color: ColorUtils.transparentize(Appearance.colors.colSurfaceContainerHighest, 0.1)
        border.color: Appearance.colors.colPrimary
        border.width: 1

        RowLayout {
            anchors.centerIn: parent
            spacing: 6
            MaterialSymbol {
                iconSize: 16
                color: Appearance.colors.colPrimary
                text: windowData?.floating ? "aspect_ratio" : "vertical_split"
            }
            StyledText {
                id: resizeText
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Medium
                color: Appearance.colors.colOnSurface
                text: {
                    if (windowData?.floating) {
                        return `${Math.round(root.width / (root.scale * root.widthRatio))} × ${Math.round(root.height / (root.scale * root.heightRatio))} px`
                    } else {
                        const pct = Math.round(root.splitDelta * 100)
                        return `Split: ${pct >= 0 ? "+" : ""}${pct}%`
                    }
                }
            }
        }
    }

    // 8. Corner Resize Handle (bottom-right)
    Item {
        id: cornerGrip
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: 24
        height: 24
        z: 16

        MouseArea {
            id: cornerGripArea
            anchors.fill: parent
            cursorShape: Qt.SizeFDiagCursor
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onPressed: (mouse) => {
                root.startCornerResize(mouse.x + cornerGrip.x, mouse.y + cornerGrip.y)
            }
            onPositionChanged: (mouse) => {
                root.updateCornerResize(mouse.x + cornerGrip.x, mouse.y + cornerGrip.y)
            }
            onReleased: (mouse) => {
                root.endCornerResize(mouse)
            }
        }

        MaterialSymbol {
            anchors.centerIn: parent
            iconSize: 14
            color: cornerGripArea.containsMouse || root.isResizeActive ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colOnSurface, 0.65)
            text: "drag_handle"
            rotation: -45
        }
    }
}
