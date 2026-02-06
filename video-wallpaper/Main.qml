import Qt.labs.folderlistmodel
import QtQuick
import Quickshell.Io
import qs.Commons

import "./main"

Item {
    id: root

    property var pluginApi: null


    readonly property bool automation:
        pluginApi.pluginSettings.automation ||
        false

    readonly property string automationMode:
        pluginApi.pluginSettings.automationMode ||
        "random"

    readonly property real automationTime:
        pluginApi.pluginSettings.automationTime ||
        5 * 60

    readonly property string currentWallpaper: 
        pluginApi.pluginSettings.currentWallpaper || 
        ""

    readonly property bool enabled: 
        pluginApi.pluginSettings.enabled || 
        false

    readonly property bool isMuted:
        pluginApi.pluginSettings.isMuted ||
        false

    readonly property bool isPlaying:
        pluginApi.pluginSettings.isPlaying ||
        false

    readonly property var oldWallpapers:
        pluginApi.pluginSettings.oldWallpapers || 
        ({})

    readonly property bool thumbCacheReady:
        pluginApi.pluginSettings.thumbCacheReady ||
        false

    readonly property double volume:
        pluginApi.pluginSettings.volume ||
        1.0

    readonly property string wallpapersFolder: 
        pluginApi.pluginSettings.wallpapersFolder || 
        pluginApi.manifest.metadata.defaultSettings.wallpapersFolder || 
        "~/Pictures/Wallpapers"


    /***************************
    * WALLPAPER FUNCTIONALITY
    ***************************/
    function random() {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (folderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        const rand = Math.floor(Math.random() * folderModel.count);
        const url = folderModel.get(rand, "filePath");
        setWallpaper(url);
    }

    function clear() {
        setWallpaper("");
    }

    function nextWallpaper() {
        if (wallpapersFolder === "") {
            Logger.e("video-wallpaper", "Wallpapers folder is empty!");
            return;
        }
        if (folderModel.count === 0) {
            Logger.e("video-wallpaper", "No valid video files found!");
            return;
        }

        Logger.d("video-wallpaper", "Choosing next wallpaper...");

        // Even if the file is not in wallpapers folder, aka -1, it sets the nextIndex to 0 then
        const currentIndex = folderModel.indexOf(root.currentWallpaper);
        const nextIndex = (currentIndex + 1) % folderModel.count;
        const url = folderModel.get(nextIndex, "filePath");
        setWallpaper(url);
    }

    function setWallpaper(path) {
        if (root.pluginApi == null) {
            Logger.e("video-wallpaper", "Can't set the wallpaper because pluginApi is null.");
            return;
        }

        pluginApi.pluginSettings.currentWallpaper = path;
        pluginApi.saveSettings();
    }

    /***************************
    * HELPER FUNCTIONALITY
    ***************************/
    function getThumbPath(videoPath: string): string {
        return thumbnails.getThumbPath(videoPath);
    }

    // Get thumbnail url based on video name
    function getThumbUrl(videoPath: string): string {
        return thumbnails.getThumbUrl(videoPath);
    }

    function thumbRegenerate() {
        thumbnails.thumbRegenerate();
    }

    /***************************
    * COMPONENTS
    ***************************/
    VideoWallpaper {
        id: wallpaper
        pluginApi: root.pluginApi
        currentWallpaper: root.currentWallpaper
        enabled: root.enabled
        isPlaying: root.isPlaying
        isMuted: root.isMuted
        volume: root.volume

        thumbnails: thumbnails
        innerService: innerService
    }

    Thumbnails {
        id: thumbnails
        pluginApi: root.pluginApi
        currentWallpaper: root.currentWallpaper
        thumbCacheReady: root.thumbCacheReady
        folderModel: folderModel
    }

    InnerService {
        id: innerService
        pluginApi: root.pluginApi
        currentWallpaper: root.currentWallpaper
        oldWallpapers: root.oldWallpapers

        thumbnails: thumbnails
    }

    Automation {
        id: automation
        pluginApi: root.pluginApi
        automation: root.automation
        automationMode: root.automationMode
        automationTime: root.automationTime

        random: root.random
        nextWallpaper: root.nextWallpaper
    }

    FolderListModel {
        id: folderModel
        folder: root.pluginApi == null ? "" : "file://" + root.wallpapersFolder
        nameFilters: ["*.mp4", "*.avi", "*.mov"]
        showDirs: false

        onStatusChanged: {
            if (folderModel.status == FolderListModel.Ready) {
                // Generate all the thumbnails for the folder
                thumbnails.thumbGeneration();
            }
        }
    }

    // IPC Handler
    IpcHandler {
        target: "plugin:videowallpaper"

        function random() {
            root.random();
        }

        function clear() {
            root.clear();
        }

        // Current wallpaper
        function setWallpaper(path: string) {
            root.setWallpaper(path);
        }

        function getWallpaper(): string {
            return root.currentWallpaper;
        }

        // Enabled
        function setEnabled(enabled: bool) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.enabled = enabled;
            root.pluginApi.saveSettings();
        }

        function getEnabled(): bool {
            return root.enabled;
        }

        function toggleActive() {
            setEnabled(!root.enabled);
        }

        // Is playing
        function resume() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = true;
            root.pluginApi.saveSettings();
        }

        function pause() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = false;
            root.pluginApi.saveSettings();
        }

        function togglePlaying() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isPlaying = !root.isPlaying;
            root.pluginApi.saveSettings();
        }

        // Mute / unmute
        function mute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = true;
            root.pluginApi.saveSettings();
        }

        function unmute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = false;
            root.pluginApi.saveSettings();
        }

        function toggleMute() {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.isMuted = !root.isMuted;
            root.pluginApi.saveSettings();
        }

        // Volume
        function setVolume(volume: real) {
            if (root.pluginApi == null) return;

            root.pluginApi.pluginSettings.volume = volume;
            root.pluginApi.saveSettings();
        }

        function increaseVolume() {
            setVolume(root.volume + Settings.data.audio.volumeStep);
        }

        function decreaseVolume() {
            setVolume(root.volume - Settings.data.audio.volumeStep);
        }
    }
}
