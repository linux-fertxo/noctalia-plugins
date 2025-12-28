/*
 * SPDX-FileCopyrightText: 2025 cod3ddot@proton.me
 *
 * SPDX-License-Identifier: AGPL-3.0-or-later
 */

import QtQuick
import QtQuick.Layouts

import qs.Commons
import qs.Widgets

ColumnLayout {
    id: root

    // noctalia plugin api, injected dynamically
    property var pluginApi: null
    readonly property var pluginCore: pluginApi?.mainInstance

    spacing: Style.marginM

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.debug.label")
        description: root.pluginApi.tr("settings.debug.description")
        checked: root.pluginCore.pluginSettings.debug
        onToggled: checked => root.pluginCore.pluginSettings.debug = checked
    }

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.listenToNotifications.label")
        description: root.pluginApi.tr("settings.listenToNotifications.description")
        checked: root.pluginCore.pluginSettings.listenToNotifications
        onToggled: checked => root.pluginCore.pluginSettings.listenToNotifications = checked
    }

    NToggle {
        Layout.fillWidth: true
        label: root.pluginApi.tr("settings.polling.label")
        description: root.pluginApi.tr("settings.polling.description")
        checked: root.pluginCore.pluginSettings.polling
        onToggled: checked => root.pluginCore.pluginSettings.polling = checked
    }

    NValueSlider {
        Layout.fillWidth: true
        text: root.pluginCore.pluginSettings.pollingInterval + "ms"
        enabled: root.pluginCore.pluginSettings.polling
        from: 1000
        to: 5000
        stepSize: 250
        value: root.pluginCore.pluginSettings.pollingInterval
        onMoved: root.pluginCore.pluginSettings.pollingInterval = value
    }

    // This function is called by noctalia dialog
    function saveSettings(): void {
        if (!pluginApi) {
            return root.pluginCore?.error("cannot save settings: pluginApi is null");
        }

        root.pluginApi.pluginSettings.debug = root.pluginCore.pluginSettings.debug;
        root.pluginApi.pluginSettings.polling = root.pluginCore.pluginSettings.polling;
        root.pluginApi.pluginSettings.pollingInterval = root.pluginCore.pluginSettings.pollingInterval;
        root.pluginApi.pluginSettings.listenToNotifications = root.pluginCore.pluginSettings.listenToNotifications;

        // Persists to disk
        root.pluginApi.saveSettings();

        root.pluginCore?.log("saved settings");
    }
}
