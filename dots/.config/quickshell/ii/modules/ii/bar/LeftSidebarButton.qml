import QtQuick
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

RippleButton {
    id: root

    property real buttonPadding: 5
    implicitWidth: 30 + buttonPadding * 2
    implicitHeight: 30 + buttonPadding * 2
    buttonRadius: Appearance.rounding.full
    colBackgroundHover: Appearance.colors.colLayer1Hover
    colRipple: Appearance.colors.colLayer1Active
    colBackgroundToggled: Appearance.colors.colSecondaryContainer
    colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
    colRippleToggled: Appearance.colors.colSecondaryContainerActive
    toggled: GlobalStates.appDrawerOpen

    onPressed: {
        GlobalStates.appDrawerOpen = !GlobalStates.appDrawerOpen;
    }

    Loader {
        anchors.centerIn: parent
        active: true
        sourceComponent: (Config.options.bar.topLeftIcon === "launchpad" || Config.options.bar.topLeftIcon === "apps") ? materialIconComp : customIconComp
    }

    Component {
        id: materialIconComp
        MaterialSymbol {
            text: "apps"
            iconSize: 20
            color: Appearance.colors.colOnLayer0
        }
    }

    Component {
        id: customIconComp
        CustomIcon {
            width: 19.5
            height: 19.5
            source: Config.options.bar.topLeftIcon == 'distro' ? SystemInfo.distroIcon : `${Config.options.bar.topLeftIcon}-symbolic`
            colorize: true
            color: Appearance.colors.colOnLayer0
        }
    }

}
