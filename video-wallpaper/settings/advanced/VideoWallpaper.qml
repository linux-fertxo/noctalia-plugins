import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    required property var pluginApi
    required property bool enabled

    property int orientation: pluginApi.pluginSettings.orientation || 0


    /***************************
    * COMPONENTS
    ***************************/
    // Orientation
    NValueSlider {
        property real _value: root.orientation

        enabled: root.enabled
        from: -270
        to: 270
        value: root.orientation
        defaultValue: 0
        stepSize: 90
        text: _value
        label: root.pluginApi?.tr("settings.advanced.orientation.label") || "Orientation"
        description: root.pluginApi?.tr("settings.advanced.orientation.description") || "The orientation of the video playing, can be any multiple of 90."
        onMoved: value => _value = value
        onPressedChanged: (pressed, value) => {
            if(root.pluginApi == null) {
                Logger.e("video-wallpaper", "Plugin API is null.");
                return
            }

            if(!pressed) {
                root.pluginApi.pluginSettings.orientation = value;
                root.pluginApi.saveSettings();
            }
        }
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.orientation = root.pluginApi.pluginSettings.orientation || 0
        }
    }


    /********************************
    * Save settings functionality
    ********************************/
    function saveSettings() {
        if(!pluginApi) {
            Logger.e("mpvpaper", "Cannot save: pluginApi is null");
            return;
        }

        pluginApi.pluginSettings.orientation = orientation;
    }
}
