
import Qt.labs.folderlistmodel
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import QtMultimedia

import qs.Commons
import qs.Services.UI

Variants {
    id: root
    required property var pluginApi


    /***************************
    * PROPERTIES
    ***************************/
    required property string currentWallpaper 
    required property bool enabled 
    required property bool isPlaying
    required property bool isMuted
    required property real volume

    required property Thumbnails thumbnails
    required property InnerService innerService


    /***************************
    * EVENTS
    ***************************/
    onCurrentWallpaperChanged: {
        if (root.enabled && root.currentWallpaper != "") {
            thumbnails.startColorGen();
        }
    }

    onEnabledChanged: {
        if(root.enabled && root.currentWallpaper != "") {
            Logger.d("video-wallpaper", "Turning video-wallpaper on.");

            // Save the old wallpapers of the user.
            innerService.saveOldWallpapers();

            pluginApi.pluginSettings.isPlaying = true;
            pluginApi.saveSettings();

            thumbnails.startColorGen();
        } else if(!root.enabled) {
            Logger.d("video-wallpaper", "Turning video-wallpaper off.");

            // Apply the old wallpapers back
            innerService.applyOldWallpapers();
        }
    }

    model: Quickshell.screens
    PanelWindow {
        required property var modelData
        screen: modelData
        exclusionMode: ExclusionMode.Ignore

        implicitWidth: modelData.width
        implicitHeight: modelData.height
        visible: root.enabled && root.currentWallpaper != ""

        WlrLayershell.namespace: `noctalia-video-wallpaper-${modelData.name}`
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            bottom: true
            right: true
            left: true
        }

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "black"

            Video {
                id: videoWallpaper
                anchors.fill: parent
                autoPlay: true
                loops: MediaPlayer.Infinite
                source: {
                    if(root.currentWallpaper == "") return ""
                    else if (root.currentWallpaper.startsWith("file://")) return root.currentWallpaper
                    else return `file://${root.currentWallpaper}`
                }
                muted: root.isMuted
                volume: root.volume
                playbackRate: {
                    if(root.isPlaying) return 1.0
                    // Pausing is the same as putting the speed to veryyyyyyy tiny amount
                    else return 0.00000001
                }

                onErrorOccurred: (error, errorString) => {
                    Logger.e("video-wallpaper", errorString);
                }
            }
        }
    }
}
