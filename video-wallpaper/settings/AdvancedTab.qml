import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

import "./advanced"

ColumnLayout {
    id: root
    spacing: Style.marginM
    Layout.fillWidth: true


    /***************************
    * PROPERTIES
    ***************************/
    required property var pluginApi
    required property bool enabled
    
    readonly property string activeBackend: pluginApi.pluginSettings.activeBackend || "qt6-multimedia"

    property bool hardwareAcceleration: pluginApi.pluginSettings.hardwareAcceleration   || false
    property string fillMode:           pluginApi.pluginSettings.fillMode               || "fit"
    property string mpvSocket:          pluginApi.pluginSettings.mpvSocket              || "/tmp/mpv-socket"
    property string profile:            pluginApi.pluginSettings.profile                || "default"

    readonly property list<string> backends: ["mpvpaper", "qt6-multimedia"]

    /***************************
    * COMPONENTS
    ***************************/
    // Fill Mode
    NComboBox {
        enabled: root.enabled
        Layout.fillWidth: true
        label: root.pluginApi?.tr("settings.advanced.fill_mode.label") || "Fill Mode"
        description: root.pluginApi?.tr("settings.advanced.fill_mode.description") || "The mode that the wallpaper is fitted into the background."
        defaultValue: "0"
        model: [
            {
                "key": "fit",
                "name": pluginApi?.tr("settings.advanced.fill_mode.fit") || "Fit"
            },
            {
                "key": "crop",
                "name": pluginApi?.tr("settings.advanced.fill_mode.crop") || "Crop"
            },
            {
                "key": "stretch",
                "name": pluginApi?.tr("settings.advanced.fill_mode.stretch") || "Stretch"
            }
        ]
        currentKey: root.fillMode
        onSelected: key => root.fillMode = key
    }

    NTabView {
        currentIndex: root.backends.indexOf(root.activeBackend)

        VideoWallpaper {
            pluginApi: root.pluginApi
            enabled: root.enabled
        }

        Mpvpaper {
            pluginApi: root.pluginApi
            enabled: root.enabled
        }

        NoBackend {
            pluginApi: root.pluginApi
            enabled: root.enabled
        }
    }

    Connections {
        target: pluginApi
        function onPluginSettingsChanged() {
            // Update the local properties on change
            root.hardwareAcceleration = root.pluginApi.pluginSettings.hardwareAcceleration || false
            root.mpvSocket = root.pluginApi.pluginSettings.mpvSocket || "/tmp/mpv-socket";
            root.profile = root.pluginApi.pluginSettings.profile || pluginApi?.manifest?.metadata?.defaultSettings?.profile || "default"
            root.fillMode = root.pluginApi.pluginSettings.fillMode || pluginApi?.manifest?.metadata?.defaultSettings?.fillMode || "fit"
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

        pluginApi.pluginSettings.hardwareAcceleration = hardwareAcceleration;
        pluginApi.pluginSettings.mpvSocket = mpvSocket;
        pluginApi.pluginSettings.profile = profile;
        pluginApi.pluginSettings.fillMode = fillMode;
    }
}
