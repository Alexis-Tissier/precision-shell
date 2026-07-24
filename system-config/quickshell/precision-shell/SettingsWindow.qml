import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

PanelWindow {
    id: settingsWindow

    required property var shellRoot
    required property var desktopContext
    property int selectedSection: 0
    property string statusMessage: ""
    property string pendingSessionAction: ""
    property string pendingSessionLabel: ""

    visible: shellRoot !== null && shellRoot.settingsOpen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    focusable: true

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "precision-shell-settings"

    color: "transparent"

    function p(value) {
        return desktopContext !== null ? desktopContext.p(value) : value
    }

    function applyPreferences(rawText, applyInitialLayout) {
        if (shellRoot === null || desktopContext === null)
            return

        try {
            const payload = JSON.parse(rawText)
            const panelOpacity = parseFloat(payload.panel_opacity)
            const overlayDarkness = parseFloat(payload.overlay_darkness)
            const defaultView = parseInt(payload.default_view)
            const latitude = parseFloat(payload.weather_latitude)
            const longitude = parseFloat(payload.weather_longitude)

            if (!isNaN(panelOpacity))
                shellRoot.panelOpacity = Math.max(0.90, Math.min(1, panelOpacity))

            if (!isNaN(overlayDarkness))
                shellRoot.overlayDarkness = Math.max(0.22, Math.min(0.65, overlayDarkness))

            if (!isNaN(defaultView))
                shellRoot.defaultViewState = Math.max(1, Math.min(4, defaultView))

            if (payload.weather_location !== undefined)
                desktopContext.weatherLocation = String(payload.weather_location)

            if (!isNaN(latitude))
                desktopContext.weatherLatitude = latitude

            if (!isNaN(longitude))
                desktopContext.weatherLongitude = longitude

            if (cityInput !== null && !cityInput.activeFocus)
                cityInput.text = desktopContext.weatherLocation

            if (applyInitialLayout === true)
                desktopContext.applyViewState(shellRoot.defaultViewState)

            desktopContext.refreshWeather()
        } catch (error) {
            settingsWindow.statusMessage = "Impossible de charger les préférences."
            console.warn("Precision preferences:", error)
        }
    }

    function savePreference(key, value) {
        settingsWriter.exec([
            "bash",
            "-lc",
            "$HOME/.local/bin/precision-settings set \"$1\" \"$2\"",
            "precision-settings",
            key,
            String(value)
        ])
    }

    function applyWeatherCity() {
        statusMessage = "Recherche de la ville…"
        cityWriter.exec([
            "bash",
            "-lc",
            "$HOME/.local/bin/precision-settings set-city \"$1\"",
            "precision-settings",
            cityInput.text
        ])
    }

    function runAction(actionName) {
        statusMessage = "Exécution…"
        actionProcess.exec([
            "bash",
            "-lc",
            "$HOME/.local/bin/precision-settings action \"$1\"",
            "precision-settings",
            actionName
        ])
    }

    function askSessionAction(actionName, label) {
        pendingSessionAction = actionName
        pendingSessionLabel = label
    }

    function clearConfirmation() {
        pendingSessionAction = ""
        pendingSessionLabel = ""
    }

    Shortcut {
        enabled: settingsWindow.visible
        context: Qt.ApplicationShortcut
        sequence: "Escape"
        onActivated: {
            if (settingsWindow.pendingSessionAction.length > 0)
                settingsWindow.clearConfirmation()
            else
                settingsWindow.shellRoot.closeSettings()
        }
    }

    Process {
        id: settingsReader
        running: true
        command: ["bash", "-lc", "$HOME/.local/bin/precision-settings get"]

        stdout: StdioCollector {
            onStreamFinished: settingsWindow.applyPreferences(text, true)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0)
                    settingsWindow.statusMessage = message
            }
        }
    }

    Process {
        id: settingsWriter

        onExited: function(exitCode, exitStatus) {
            settingsWindow.statusMessage = exitCode === 0
                ? "Préférence enregistrée."
                : "Échec de l’enregistrement."
        }
    }

    Process {
        id: cityWriter

        stdout: StdioCollector {
            onStreamFinished: {
                settingsWindow.applyPreferences(text, false)
                settingsWindow.statusMessage = "Ville météo mise à jour."
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0)
                    settingsWindow.statusMessage = message
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && settingsWindow.statusMessage === "Recherche de la ville…")
                settingsWindow.statusMessage = "Ville introuvable."
        }
    }

    Process {
        id: actionProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0)
                    settingsWindow.statusMessage = message
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim()
                if (message.length > 0)
                    settingsWindow.statusMessage = message
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0 && settingsWindow.statusMessage === "Exécution…")
                settingsWindow.statusMessage = "L’action a échoué."
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, shellRoot !== null ? shellRoot.overlayDarkness : 0.32)
    }

    MouseArea {
        anchors.fill: parent
        onClicked: settingsWindow.shellRoot.closeSettings()
    }

    Rectangle {
        id: settingsCard

        anchors.centerIn: parent
        width: Math.min(parent.width - settingsWindow.p(42), settingsWindow.p(720))
        height: Math.min(parent.height - settingsWindow.p(46), settingsWindow.p(410))
        radius: settingsWindow.p(14)
        color: desktopContext !== null ? desktopContext.panelSurface : "#FBF9F5"
        border.width: Math.max(1, settingsWindow.p(0.75))
        border.color: desktopContext !== null ? desktopContext.panelBorder : "#78CFC4B6"
        clip: true

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            propagateComposedEvents: false
            onPressed: function(mouse) { mouse.accepted = true }
        }

        Item {
            id: settingsHeader
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }
            height: settingsWindow.p(49)

            Column {
                anchors {
                    left: parent.left
                    leftMargin: settingsWindow.p(20)
                    verticalCenter: parent.verticalCenter
                }
                spacing: settingsWindow.p(2)

                Text {
                    text: "Precision Settings"
                    color: desktopContext.graphite
                    font.family: "Inter"
                    font.pixelSize: settingsWindow.p(12.2)
                    font.weight: Font.Medium
                }

                Text {
                    text: "Réglages propres à Precision Shell"
                    color: desktopContext.mutedInk
                    font.family: "Inter"
                    font.pixelSize: settingsWindow.p(6.9)
                }
            }

            Text {
                anchors {
                    right: closeButton.left
                    rightMargin: settingsWindow.p(13)
                    verticalCenter: parent.verticalCenter
                }
                width: settingsWindow.p(190)
                text: settingsWindow.statusMessage
                horizontalAlignment: Text.AlignRight
                elide: Text.ElideRight
                color: desktopContext.mutedInk
                font.family: "Inter"
                font.pixelSize: settingsWindow.p(6.8)
            }

            Rectangle {
                id: closeButton
                anchors {
                    right: parent.right
                    rightMargin: settingsWindow.p(15)
                    verticalCenter: parent.verticalCenter
                }
                width: settingsWindow.p(24)
                height: settingsWindow.p(24)
                radius: settingsWindow.p(7)
                color: closeMouse.containsMouse ? "#E8DED2" : "#F0E9E0"

                Text {
                    anchors.centerIn: parent
                    text: "×"
                    color: desktopContext.graphite
                    font.family: "Inter"
                    font.pixelSize: settingsWindow.p(12)
                }

                MouseArea {
                    id: closeMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: settingsWindow.shellRoot.closeSettings()
                }
            }
        }

        Rectangle {
            anchors {
                left: parent.left
                right: parent.right
                top: settingsHeader.bottom
            }
            height: Math.max(1, settingsWindow.p(0.7))
            color: "#55D8CCBC"
        }

        Item {
            anchors {
                left: parent.left
                right: parent.right
                top: settingsHeader.bottom
                bottom: parent.bottom
            }

            Rectangle {
                id: settingsSidebar
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: settingsWindow.p(145)
                color: "#44EEE7DE"

                Column {
                    anchors {
                        fill: parent
                        margins: settingsWindow.p(12)
                    }
                    spacing: settingsWindow.p(5)

                    Repeater {
                        model: [
                            {"title": "Appearance", "subtitle": "Look and widgets"},
                            {"title": "System", "subtitle": "Sound, network, weather"},
                            {"title": "Shortcuts", "subtitle": "Keyboard reference"},
                            {"title": "Session", "subtitle": "Power and maintenance"}
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            required property int index

                            width: parent.width
                            height: settingsWindow.p(38)
                            radius: settingsWindow.p(8)
                            color: settingsWindow.selectedSection === index
                                ? "#E5DBCF"
                                : (sectionMouse.containsMouse ? "#70EEE6DC" : "transparent")
                            border.width: settingsWindow.selectedSection === index
                                ? Math.max(1, settingsWindow.p(0.6))
                                : 0
                            border.color: "#75CFC4B6"

                            Column {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(10)
                                    right: parent.right
                                    rightMargin: settingsWindow.p(7)
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: settingsWindow.p(1.5)

                                Text {
                                    width: parent.width
                                    text: modelData.title
                                    color: desktopContext.graphite
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(8.4)
                                    font.weight: settingsWindow.selectedSection === index
                                        ? Font.Medium
                                        : Font.Normal
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.subtitle
                                    color: desktopContext.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(5.9)
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: sectionMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWindow.selectedSection = index
                            }
                        }
                    }

                    Item { width: 1; height: settingsWindow.p(7) }

                    Rectangle {
                        width: parent.width
                        height: Math.max(1, settingsWindow.p(0.6))
                        color: "#4FD8CCBC"
                    }

                    Item { width: 1; height: settingsWindow.p(5) }

                    Text {
                        width: parent.width
                        text: "Super+S : Fedora\nSuper+Shift+S : Precision"
                        color: desktopContext.mutedInk
                        font.family: "Inter"
                        font.pixelSize: settingsWindow.p(5.9)
                        wrapMode: Text.WordWrap
                    }
                }
            }

            Item {
                id: pageHost
                anchors {
                    left: settingsSidebar.right
                    right: parent.right
                    top: parent.top
                    bottom: parent.bottom
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedSection === 0
                    clip: true
                    contentWidth: width
                    contentHeight: appearanceColumn.implicitHeight + settingsWindow.p(26)
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {}

                    Column {
                        id: appearanceColumn
                        width: parent.width - settingsWindow.p(38)
                        x: settingsWindow.p(19)
                        y: settingsWindow.p(18)
                        spacing: settingsWindow.p(12)

                        Text {
                            text: "Appearance"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(12.5)
                            font.weight: Font.Medium
                        }

                        Text {
                            width: parent.width
                            text: "Adjust the shell without changing the calm visual language."
                            color: desktopContext.mutedInk
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(7.1)
                            wrapMode: Text.WordWrap
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(68)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(11)
                                }
                                text: "Panel opacity"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.5)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(11)
                                }
                                text: Math.round(shellRoot.panelOpacity * 100) + "%"
                                color: desktopContext.softInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7.4)
                            }

                            Slider {
                                id: opacitySlider
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(9)
                                }
                                from: 0.90
                                to: 1.0
                                stepSize: 0.01
                                value: shellRoot.panelOpacity
                                onMoved: shellRoot.panelOpacity = value
                                onPressedChanged: {
                                    if (!pressed)
                                        settingsWindow.savePreference("panel_opacity", value)
                                }

                                background: Rectangle {
                                    x: opacitySlider.leftPadding
                                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                                    width: opacitySlider.availableWidth
                                    height: settingsWindow.p(2)
                                    radius: height / 2
                                    color: "#CFC6BC"

                                    Rectangle {
                                        width: opacitySlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: desktopContext.softInk
                                    }
                                }

                                handle: Rectangle {
                                    x: opacitySlider.leftPadding + opacitySlider.visualPosition * (opacitySlider.availableWidth - width)
                                    y: opacitySlider.topPadding + opacitySlider.availableHeight / 2 - height / 2
                                    width: settingsWindow.p(9)
                                    height: settingsWindow.p(9)
                                    radius: width / 2
                                    color: desktopContext.warmWhite
                                    border.width: Math.max(1, settingsWindow.p(0.65))
                                    border.color: "#A79E94"
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(68)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(11)
                                }
                                text: "Overlay darkness"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.5)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(11)
                                }
                                text: Math.round(shellRoot.overlayDarkness * 100) + "%"
                                color: desktopContext.softInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7.4)
                            }

                            Slider {
                                id: darknessSlider
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(9)
                                }
                                from: 0.22
                                to: 0.65
                                stepSize: 0.01
                                value: shellRoot.overlayDarkness
                                onMoved: shellRoot.overlayDarkness = value
                                onPressedChanged: {
                                    if (!pressed)
                                        settingsWindow.savePreference("overlay_darkness", value)
                                }

                                background: Rectangle {
                                    x: darknessSlider.leftPadding
                                    y: darknessSlider.topPadding + darknessSlider.availableHeight / 2 - height / 2
                                    width: darknessSlider.availableWidth
                                    height: settingsWindow.p(2)
                                    radius: height / 2
                                    color: "#CFC6BC"

                                    Rectangle {
                                        width: darknessSlider.visualPosition * parent.width
                                        height: parent.height
                                        radius: parent.radius
                                        color: desktopContext.softInk
                                    }
                                }

                                handle: Rectangle {
                                    x: darknessSlider.leftPadding + darknessSlider.visualPosition * (darknessSlider.availableWidth - width)
                                    y: darknessSlider.topPadding + darknessSlider.availableHeight / 2 - height / 2
                                    width: settingsWindow.p(9)
                                    height: settingsWindow.p(9)
                                    radius: width / 2
                                    color: desktopContext.warmWhite
                                    border.width: Math.max(1, settingsWindow.p(0.65))
                                    border.color: "#A79E94"
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(80)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: "Default desktop layout"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.5)
                            }

                            Row {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(11)
                                }
                                spacing: settingsWindow.p(7)

                                Repeater {
                                    model: [
                                        {"label": "Hidden", "state": 1},
                                        {"label": "Palette", "state": 2},
                                        {"label": "Controls", "state": 3},
                                        {"label": "All", "state": 4}
                                    ]

                                    delegate: Rectangle {
                                        required property var modelData
                                        width: (parent.width - settingsWindow.p(21)) / 4
                                        height: settingsWindow.p(25)
                                        radius: settingsWindow.p(7)
                                        color: shellRoot.defaultViewState === modelData.state
                                            ? "#DDD2C5"
                                            : (layoutMouse.containsMouse ? "#EDE5DB" : "#F5F0EA")
                                        border.width: Math.max(1, settingsWindow.p(0.55))
                                        border.color: shellRoot.defaultViewState === modelData.state
                                            ? "#AFA092"
                                            : "#55CFC4B6"

                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: desktopContext.graphite
                                            font.family: "Inter"
                                            font.pixelSize: settingsWindow.p(6.7)
                                        }

                                        MouseArea {
                                            id: layoutMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                shellRoot.defaultViewState = modelData.state
                                                desktopContext.applyViewState(modelData.state)
                                                settingsWindow.savePreference("default_view", modelData.state)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(50)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Column {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    verticalCenter: parent.verticalCenter
                                }
                                spacing: settingsWindow.p(2)

                                Text {
                                    text: "Desktop widgets"
                                    color: desktopContext.graphite
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(8.5)
                                }

                                Text {
                                    text: shellRoot.desktopWidgetsVisible ? "Visible" : "Hidden"
                                    color: desktopContext.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(6.2)
                                }
                            }

                            Rectangle {
                                id: widgetsToggle
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    verticalCenter: parent.verticalCenter
                                }
                                width: settingsWindow.p(25)
                                height: settingsWindow.p(14)
                                radius: height / 2
                                color: shellRoot.desktopWidgetsVisible ? desktopContext.softInk : "#B9B1A8"

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: shellRoot.desktopWidgetsVisible
                                        ? parent.width - width - settingsWindow.p(2)
                                        : settingsWindow.p(2)
                                    width: settingsWindow.p(10)
                                    height: settingsWindow.p(10)
                                    radius: width / 2
                                    color: desktopContext.warmWhite
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: shellRoot.desktopWidgetsVisible = !shellRoot.desktopWidgetsVisible
                                }
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedSection === 1
                    clip: true
                    contentWidth: width
                    contentHeight: systemColumn.implicitHeight + settingsWindow.p(26)
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {}

                    Column {
                        id: systemColumn
                        width: parent.width - settingsWindow.p(38)
                        x: settingsWindow.p(19)
                        y: settingsWindow.p(18)
                        spacing: settingsWindow.p(12)

                        Text {
                            text: "System"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(12.5)
                            font.weight: Font.Medium
                        }

                        Row {
                            width: parent.width
                            spacing: settingsWindow.p(10)

                            Rectangle {
                                width: (parent.width - settingsWindow.p(10)) / 2
                                height: settingsWindow.p(58)
                                radius: settingsWindow.p(10)
                                color: "#A8F7F3EE"
                                border.width: Math.max(1, settingsWindow.p(0.6))
                                border.color: "#55D8CCBC"

                                Column {
                                    anchors {
                                        left: parent.left
                                        leftMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: settingsWindow.p(3)

                                    Text {
                                        text: "Wi-Fi"
                                        color: desktopContext.graphite
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(8.5)
                                    }

                                    Text {
                                        width: settingsWindow.p(120)
                                        text: !desktopContext.wifiEnabled
                                            ? "Off"
                                            : (desktopContext.wifiConnected ? desktopContext.wifiSsid : "On")
                                        color: desktopContext.mutedInk
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(6.5)
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    anchors {
                                        right: parent.right
                                        rightMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: settingsWindow.p(25)
                                    height: settingsWindow.p(14)
                                    radius: height / 2
                                    color: desktopContext.wifiEnabled ? desktopContext.softInk : "#B9B1A8"
                                    opacity: desktopContext.wifiBusy ? 0.55 : 1

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: desktopContext.wifiEnabled
                                            ? parent.width - width - settingsWindow.p(2)
                                            : settingsWindow.p(2)
                                        width: settingsWindow.p(10)
                                        height: settingsWindow.p(10)
                                        radius: width / 2
                                        color: desktopContext.warmWhite
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !desktopContext.wifiBusy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: desktopContext.toggleWifi()
                                    }
                                }
                            }

                            Rectangle {
                                width: (parent.width - settingsWindow.p(10)) / 2
                                height: settingsWindow.p(58)
                                radius: settingsWindow.p(10)
                                color: "#A8F7F3EE"
                                border.width: Math.max(1, settingsWindow.p(0.6))
                                border.color: "#55D8CCBC"

                                Column {
                                    anchors {
                                        left: parent.left
                                        leftMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: settingsWindow.p(3)

                                    Text {
                                        text: "Bluetooth"
                                        color: desktopContext.graphite
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(8.5)
                                    }

                                    Text {
                                        width: settingsWindow.p(120)
                                        text: !desktopContext.bluetoothEnabled
                                            ? "Off"
                                            : (desktopContext.bluetoothConnectedName.length > 0
                                                ? desktopContext.bluetoothConnectedName
                                                : "On")
                                        color: desktopContext.mutedInk
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(6.5)
                                        elide: Text.ElideRight
                                    }
                                }

                                Rectangle {
                                    anchors {
                                        right: parent.right
                                        rightMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    width: settingsWindow.p(25)
                                    height: settingsWindow.p(14)
                                    radius: height / 2
                                    color: desktopContext.bluetoothEnabled ? desktopContext.softInk : "#B9B1A8"
                                    opacity: desktopContext.bluetoothBusy ? 0.55 : 1

                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: desktopContext.bluetoothEnabled
                                            ? parent.width - width - settingsWindow.p(2)
                                            : settingsWindow.p(2)
                                        width: settingsWindow.p(10)
                                        height: settingsWindow.p(10)
                                        radius: width / 2
                                        color: desktopContext.warmWhite
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        enabled: !desktopContext.bluetoothBusy
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: desktopContext.toggleBluetooth()
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(82)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: "Volume"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.4)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: Math.round(desktopContext.volumeLevel * 100) + "%"
                                color: desktopContext.mutedInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7)
                            }

                            Slider {
                                id: settingsVolumeSlider
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(10)
                                }
                                from: 0
                                to: 1
                                value: desktopContext.volumeLevel
                                onMoved: desktopContext.queueVolume(value)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(82)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: "Brightness"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.4)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: Math.round(desktopContext.brightnessLevel * 100) + "%"
                                color: desktopContext.mutedInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7)
                            }

                            Slider {
                                id: settingsBrightnessSlider
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(10)
                                }
                                from: 0.01
                                to: 1
                                value: desktopContext.brightnessLevel
                                onMoved: desktopContext.queueBrightness(value)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(112)
                            radius: settingsWindow.p(10)
                            color: "#A8F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#55D8CCBC"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: "Weather"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8.5)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    top: parent.top
                                    topMargin: settingsWindow.p(10)
                                }
                                text: desktopContext.weatherSymbol + "  "
                                    + (isNaN(desktopContext.weatherTemperature)
                                        ? "--"
                                        : Math.round(desktopContext.weatherTemperature) + "°")
                                    + "  " + desktopContext.weatherSummary
                                color: desktopContext.softInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7)
                            }

                            TextField {
                                id: cityInput
                                anchors {
                                    left: parent.left
                                    right: applyCityButton.left
                                    leftMargin: settingsWindow.p(13)
                                    rightMargin: settingsWindow.p(8)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(13)
                                }
                                height: settingsWindow.p(29)
                                text: desktopContext.weatherLocation
                                color: desktopContext.graphite
                                placeholderText: "Weather city"
                                placeholderTextColor: desktopContext.mutedInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7.4)
                                leftPadding: settingsWindow.p(9)
                                rightPadding: settingsWindow.p(9)
                                background: Rectangle {
                                    radius: settingsWindow.p(7)
                                    color: "#FBF8F3"
                                    border.width: Math.max(1, settingsWindow.p(0.6))
                                    border.color: cityInput.activeFocus ? "#A99C8D" : "#70CFC4B6"
                                }
                                Keys.onReturnPressed: settingsWindow.applyWeatherCity()
                            }

                            Rectangle {
                                id: applyCityButton
                                anchors {
                                    right: refreshWeatherButton.left
                                    rightMargin: settingsWindow.p(7)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(13)
                                }
                                width: settingsWindow.p(56)
                                height: settingsWindow.p(29)
                                radius: settingsWindow.p(7)
                                color: applyCityMouse.containsMouse ? "#DCCFC1" : "#E7DDD2"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Apply"
                                    color: desktopContext.graphite
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(7)
                                }

                                MouseArea {
                                    id: applyCityMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.applyWeatherCity()
                                }
                            }

                            Rectangle {
                                id: refreshWeatherButton
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    bottom: parent.bottom
                                    bottomMargin: settingsWindow.p(13)
                                }
                                width: settingsWindow.p(62)
                                height: settingsWindow.p(29)
                                radius: settingsWindow.p(7)
                                color: refreshWeatherMouse.containsMouse ? "#E4D9CD" : "#F0E8DF"
                                border.width: Math.max(1, settingsWindow.p(0.55))
                                border.color: "#60CFC4B6"

                                Text {
                                    anchors.centerIn: parent
                                    text: "Refresh"
                                    color: desktopContext.graphite
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(7)
                                }

                                MouseArea {
                                    id: refreshWeatherMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        desktopContext.refreshWeather()
                                        settingsWindow.statusMessage = "Météo actualisée."
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: settingsWindow.p(43)
                            radius: settingsWindow.p(9)
                            color: systemSettingsMouse.containsMouse ? "#E4D8CC" : "#EEE6DD"
                            border.width: Math.max(1, settingsWindow.p(0.6))
                            border.color: "#65CFC4B6"

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(13)
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "Ouvrir les paramètres Fedora"
                                color: desktopContext.graphite
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(8)
                            }

                            Text {
                                anchors {
                                    right: parent.right
                                    rightMargin: settingsWindow.p(13)
                                    verticalCenter: parent.verticalCenter
                                }
                                text: "→"
                                color: desktopContext.softInk
                                font.pixelSize: settingsWindow.p(10)
                            }

                            MouseArea {
                                id: systemSettingsMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settingsWindow.runAction("open-system-settings")
                            }
                        }
                    }
                }

                Item {
                    anchors.fill: parent
                    visible: settingsWindow.selectedSection === 2

                    Column {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            margins: settingsWindow.p(19)
                        }
                        spacing: settingsWindow.p(6)

                        Text {
                            text: "Shortcuts"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(12.5)
                            font.weight: Font.Medium
                        }

                        Text {
                            text: "Global shortcuts currently managed by Niri."
                            color: desktopContext.mutedInk
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(7)
                        }
                    }

                    ListView {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: settingsWindow.p(19)
                            rightMargin: settingsWindow.p(19)
                            topMargin: settingsWindow.p(58)
                            bottomMargin: settingsWindow.p(15)
                        }
                        clip: true
                        spacing: settingsWindow.p(5)
                        model: [
                            {"key": "F1", "action": "Hide all desktop widgets"},
                            {"key": "F2", "action": "Show the central palette"},
                            {"key": "F3", "action": "Show quick controls"},
                            {"key": "F4", "action": "Show every desktop widget"},
                            {"key": "Super + D", "action": "Open the dashboard"},
                            {"key": "Super + Space", "action": "Open search"},
                            {"key": "Super + S", "action": "Open Precision Settings"},
                            {"key": "Super + E", "action": "Open Files"},
                            {"key": "Alt + Tab", "action": "Switch windows; release Alt to confirm"},
                            {"key": "Super + L", "action": "Lock and suspend"}
                        ]

                        delegate: Rectangle {
                            required property var modelData
                            width: ListView.view.width
                            height: settingsWindow.p(35)
                            radius: settingsWindow.p(8)
                            color: "#A2F7F3EE"
                            border.width: Math.max(1, settingsWindow.p(0.55))
                            border.color: "#50D8CCBC"

                            Rectangle {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(9)
                                    verticalCenter: parent.verticalCenter
                                }
                                width: settingsWindow.p(86)
                                height: settingsWindow.p(21)
                                radius: settingsWindow.p(6)
                                color: "#E6DCD0"

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.key
                                    color: desktopContext.graphite
                                    font.family: "Inter"
                                    font.pixelSize: settingsWindow.p(6.8)
                                    font.weight: Font.Medium
                                }
                            }

                            Text {
                                anchors {
                                    left: parent.left
                                    leftMargin: settingsWindow.p(107)
                                    right: parent.right
                                    rightMargin: settingsWindow.p(10)
                                    verticalCenter: parent.verticalCenter
                                }
                                text: modelData.action
                                color: desktopContext.softInk
                                font.family: "Inter"
                                font.pixelSize: settingsWindow.p(7.1)
                                elide: Text.ElideRight
                            }
                        }
                    }
                }

                Flickable {
                    anchors.fill: parent
                    visible: settingsWindow.selectedSection === 3
                    clip: true
                    contentWidth: width
                    contentHeight: sessionColumn.implicitHeight + settingsWindow.p(26)
                    boundsBehavior: Flickable.StopAtBounds

                    ScrollBar.vertical: ScrollBar {}

                    Column {
                        id: sessionColumn
                        width: parent.width - settingsWindow.p(38)
                        x: settingsWindow.p(19)
                        y: settingsWindow.p(18)
                        spacing: settingsWindow.p(12)

                        Text {
                            text: "Session"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(12.5)
                            font.weight: Font.Medium
                        }

                        Row {
                            width: parent.width
                            spacing: settingsWindow.p(8)

                            Repeater {
                                model: [
                                    {"label": "Lock", "action": "lock", "confirm": false},
                                    {"label": "Suspend", "action": "suspend", "confirm": false},
                                    {"label": "Restart", "action": "reboot", "confirm": true},
                                    {"label": "Power off", "action": "poweroff", "confirm": true}
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    width: (parent.width - settingsWindow.p(24)) / 4
                                    height: settingsWindow.p(52)
                                    radius: settingsWindow.p(9)
                                    color: sessionMouse.containsMouse ? "#E2D6C9" : "#EEE6DD"
                                    border.width: Math.max(1, settingsWindow.p(0.6))
                                    border.color: "#65CFC4B6"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: desktopContext.graphite
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(7.4)
                                    }

                                    MouseArea {
                                        id: sessionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (modelData.confirm)
                                                settingsWindow.askSessionAction(modelData.action, modelData.label)
                                            else
                                                settingsWindow.runAction(modelData.action)
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            text: "Maintenance"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(10)
                            font.weight: Font.Medium
                        }

                        Repeater {
                            model: [
                                {"title": "Create a backup", "subtitle": "Save the current Niri and Precision Shell configuration", "action": "backup"},
                                {"title": "Open backup folder", "subtitle": "Browse local restore points", "action": "open-backups"},
                                {"title": "Validate Niri", "subtitle": "Check the active KDL configuration", "action": "validate-niri"},
                                {"title": "Restart Precision Shell", "subtitle": "Reload Quickshell without logging out", "action": "restart-shell"},
                                {"title": "Open project folder", "subtitle": "Access stable sources and maintenance scripts", "action": "open-project"}
                            ]

                            delegate: Rectangle {
                                required property var modelData
                                width: parent.width
                                height: settingsWindow.p(48)
                                radius: settingsWindow.p(9)
                                color: maintenanceMouse.containsMouse ? "#E8DED3" : "#A8F7F3EE"
                                border.width: Math.max(1, settingsWindow.p(0.6))
                                border.color: "#55D8CCBC"

                                Column {
                                    anchors {
                                        left: parent.left
                                        leftMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: settingsWindow.p(2)

                                    Text {
                                        text: modelData.title
                                        color: desktopContext.graphite
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(8)
                                    }

                                    Text {
                                        text: modelData.subtitle
                                        color: desktopContext.mutedInk
                                        font.family: "Inter"
                                        font.pixelSize: settingsWindow.p(6.2)
                                    }
                                }

                                Text {
                                    anchors {
                                        right: parent.right
                                        rightMargin: settingsWindow.p(13)
                                        verticalCenter: parent.verticalCenter
                                    }
                                    text: "→"
                                    color: desktopContext.softInk
                                    font.pixelSize: settingsWindow.p(10)
                                }

                                MouseArea {
                                    id: maintenanceMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: settingsWindow.runAction(modelData.action)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            z: 20
            visible: settingsWindow.pendingSessionAction.length > 0
            color: "#8A000000"

            MouseArea {
                anchors.fill: parent
                onClicked: settingsWindow.clearConfirmation()
            }

            Rectangle {
                anchors.centerIn: parent
                width: settingsWindow.p(270)
                height: settingsWindow.p(140)
                radius: settingsWindow.p(12)
                color: desktopContext.panelSurface
                border.width: Math.max(1, settingsWindow.p(0.75))
                border.color: desktopContext.panelBorder

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: function(mouse) { mouse.accepted = true }
                }

                Column {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: settingsWindow.p(18)
                    }
                    spacing: settingsWindow.p(7)

                    Text {
                        text: settingsWindow.pendingSessionLabel + "?"
                        color: desktopContext.graphite
                        font.family: "Inter"
                        font.pixelSize: settingsWindow.p(11)
                        font.weight: Font.Medium
                    }

                    Text {
                        width: parent.width
                        text: "Unsaved work may be lost."
                        color: desktopContext.mutedInk
                        font.family: "Inter"
                        font.pixelSize: settingsWindow.p(7)
                        wrapMode: Text.WordWrap
                    }
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: settingsWindow.p(17)
                        bottom: parent.bottom
                        bottomMargin: settingsWindow.p(16)
                    }
                    spacing: settingsWindow.p(8)

                    Rectangle {
                        width: settingsWindow.p(70)
                        height: settingsWindow.p(27)
                        radius: settingsWindow.p(7)
                        color: cancelConfirmMouse.containsMouse ? "#E5DBD0" : "#F0E9E1"

                        Text {
                            anchors.centerIn: parent
                            text: "Cancel"
                            color: desktopContext.graphite
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(7)
                        }

                        MouseArea {
                            id: cancelConfirmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: settingsWindow.clearConfirmation()
                        }
                    }

                    Rectangle {
                        width: settingsWindow.p(80)
                        height: settingsWindow.p(27)
                        radius: settingsWindow.p(7)
                        color: confirmSessionMouse.containsMouse ? "#AF6E66" : "#965B55"

                        Text {
                            anchors.centerIn: parent
                            text: "Confirm"
                            color: "#FFF9F5"
                            font.family: "Inter"
                            font.pixelSize: settingsWindow.p(7)
                        }

                        MouseArea {
                            id: confirmSessionMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                const actionName = settingsWindow.pendingSessionAction
                                settingsWindow.clearConfirmation()
                                settingsWindow.runAction(actionName)
                            }
                        }
                    }
                }
            }
        }
    }
}
