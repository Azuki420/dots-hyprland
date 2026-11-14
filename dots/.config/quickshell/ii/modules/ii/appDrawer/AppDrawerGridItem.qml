pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RippleButton {
    id: root

    property var entry: null
    property int itemIndex: 0
    property bool isSelected: false
    property string query: ""

    readonly property string highlightPrefix: `<u><font color="${Appearance.colors.colPrimary}">`
    readonly property string highlightSuffix: `</font></u>`

    function highlightContent(content, query) {
        if (!content) return "";
        let cleanQuery = (query ?? "").trim();
        if (!cleanQuery || cleanQuery.length === 0 || content === cleanQuery)
            return StringUtils.escapeHtml(content);

        let contentLower = content.toLowerCase();
        let queryLower = cleanQuery.toLowerCase();

        let result = "";
        let lastIndex = 0;
        let qIndex = 0;

        for (let i = 0; i < content.length && qIndex < queryLower.length; i++) {
            if (contentLower[i] === queryLower[qIndex]) {
                if (i > lastIndex)
                    result += StringUtils.escapeHtml(content.slice(lastIndex, i));
                result += root.highlightPrefix + StringUtils.escapeHtml(content[i]) + root.highlightSuffix;
                lastIndex = i + 1;
                qIndex++;
            }
        }
        if (lastIndex < content.length)
            result += StringUtils.escapeHtml(content.slice(lastIndex));

        return result;
    }

    readonly property string displayContent: highlightContent(root.entry?.name ?? "", root.query)

    signal activated()

    implicitWidth: 120
    implicitHeight: 96
    buttonRadius: Appearance.rounding.normal

    colBackground: root.isSelected ? Appearance.colors.colSecondaryContainer : "transparent"
    colBackgroundHover: root.isSelected ? Appearance.colors.colSecondaryContainerHover : Appearance.colors.colLayer1Hover
    colRipple: root.isSelected ? Appearance.colors.colSecondaryContainerActive : Appearance.colors.colLayer1Active

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        spacing: 6

        IconImage {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 44
            width: 44
            height: 44
            source: {
                if (!root.entry) return "";
                let icon = root.entry.icon;
                if (!icon || icon.length === 0) {
                    icon = AppSearch.guessIcon(root.entry.id);
                }
                return Quickshell.iconPath(icon, "image-missing");
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop
            textFormat: Text.StyledText
            text: root.isSelected ? StringUtils.escapeHtml(root.entry?.name ?? "") : root.displayContent
            font.pixelSize: Appearance.font.pixelSize.small
            font.family: Appearance.font.family.main
            color: root.isSelected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurface
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }

    onClicked: {
        root.activated();
    }

    StyledToolTip {
        text: root.entry?.name ?? ""
    }
}
