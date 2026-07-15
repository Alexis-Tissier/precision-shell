import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Controls

ShellRoot {
    FloatingWindow {
        id: desktop

        visible: true
        fullscreen: true
        implicitWidth: 1180
        implicitHeight: 663
        title: "Precision Shell — Home V23"
        color: "#F6F1E8"

        readonly property real designWidth: 1180
        readonly property real designHeight: 663
        readonly property real uiScale: Math.min(width / designWidth, height / designHeight)
        readonly property real panelScale: uiScale * 1.10

        function s(value) {
            return value * uiScale
        }

        function p(value) {
            return value * panelScale
        }

        property int viewState: 4
        property date now: new Date()
        property bool restoreWidgetsOnFocus: false

        property int batteryPercent: 100
        property real volumeLevel: 0.0
        property real brightnessLevel: 0.54
        property real pendingVolumeLevel: 0.0
        property real pendingBrightnessLevel: 0.54
        property int brightnessWritePercent: 54
        property int brightnessAppliedPercent: -1
        property bool brightnessWriteQueued: false
        readonly property string brightnessDevice: "intel_backlight"

        property bool wifiEnabled: true
        property bool wifiConnected: false
        property bool wifiBusy: false
        property bool wifiMenuOpen: false
        property bool wifiScanning: false
        property bool wifiTargetEnabled: false
        property string wifiSsid: ""
        property string wifiMessage: ""
        property string wifiWriterError: ""
        property var wifiNetworks: []

        readonly property var dayNames: [
            "Sunday", "Monday", "Tuesday", "Wednesday",
            "Thursday", "Friday", "Saturday"
        ]

        readonly property var monthNames: [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December"
        ]

        function greetingLabel(date) {
            const hour = date.getHours()

            if (hour < 12)
                return "Good morning, Alexis."

            if (hour < 18)
                return "Good afternoon, Alexis."

            return "Good evening, Alexis."
        }

        function fullDateLabel(date) {
            return dayNames[date.getDay()]
                + ", "
                + date.getDate()
                + " "
                + monthNames[date.getMonth()]
        }

        readonly property color ivory: "#F6F1E8"
        readonly property color warmWhite: "#FBF9F5"
        readonly property color sand: "#D8CCBC"
        readonly property color graphite: "#302D29"
        readonly property color softInk: "#6D675F"
        readonly property color mutedInk: "#948B82"
        readonly property color panelBorder: "#4FCFC4B6"
        readonly property color panelSurface: "#DDFBF9F5"

        property var appItems: [
            {
                "icon": "browser.svg",
                "title": "Browse",
                "subtitle": "Internet",
                "lookup": "Brave",
                "fallback": ["brave-browser"]
            },
            {
                "icon": "terminal.svg",
                "title": "Terminal",
                "subtitle": "System",
                "lookup": "Alacritty",
                "fallback": ["alacritty"]
            },
            {
                "icon": "files.svg",
                "title": "Files",
                "subtitle": "Documents",
                "lookup": "Files",
                "fallback": ["nautilus"]
            },
            {
                "icon": "notes.svg",
                "title": "Notes",
                "subtitle": "Quick capture",
                "lookup": "Text Editor",
                "fallback": ["gnome-text-editor"]
            },
            {
                "icon": "calendar.svg",
                "title": "Calendar",
                "subtitle": "Schedule",
                "lookup": "Calendar",
                "fallback": ["gnome-calendar"]
            },
            {
                "icon": "mail.svg",
                "title": "Mail",
                "subtitle": "Inbox",
                "lookup": "Thunderbird",
                "fallback": ["thunderbird"]
            }
        ]

        function filteredAppItems() {
            const query = searchInput.text.trim().toLowerCase()

            if (query.length === 0)
                return appItems

            return appItems.filter(function(item) {
                return item.title.toLowerCase().indexOf(query) !== -1
                    || item.subtitle.toLowerCase().indexOf(query) !== -1
                    || item.lookup.toLowerCase().indexOf(query) !== -1
            })
        }

        function launchApplication(item) {
            const desktopEntry = DesktopEntries.heuristicLookup(item.lookup)

            if (desktopEntry !== null) {
                desktopEntry.execute()
            } else {
                Quickshell.execDetached({
                    command: item.fallback
                })
            }

            searchInput.text = ""
            searchInput.focus = false

            // Keep the shell itself visible behind the launched application,
            // but hide only the three transient widgets.
            restoreWidgetsOnFocus = true
            wifiMenuOpen = false
            viewState = 1
        }

        Timer {
            interval: 30000
            running: true
            repeat: true
            onTriggered: desktop.now = new Date()
        }

        Process {
            id: batteryReader
            command: [
                "bash",
                "-lc",
                "device=$(upower -e | grep '/battery_' | head -n1); "
                + "test -n \"$device\" && upower -i \"$device\" "
                + "| awk '/percentage:/ {gsub(\"%\", \"\", $2); print $2; exit}'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const parsed = parseInt(text.trim())

                    if (!isNaN(parsed))
                        desktop.batteryPercent = Math.max(0, Math.min(100, parsed))
                }
            }
        }

        Process {
            id: volumeReader
            command: [
                "bash",
                "-lc",
                "wpctl get-volume @DEFAULT_AUDIO_SINK@ "
                + "| awk '{printf \"%.0f\\n\", $2 * 100}'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const parsed = parseInt(text.trim())

                    if (!isNaN(parsed) && !volumeSlider.pressed)
                        desktop.volumeLevel = Math.max(0, Math.min(1, parsed / 100))
                }
            }
        }

        Process {
            id: brightnessReader
            command: [
                "bash",
                "-lc",
                "brightnessctl -m | awk -F, '{gsub(\"%\", \"\", $4); print $4}'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const parsed = parseInt(text.trim())

                    if (!isNaN(parsed) && !brightnessSlider.pressed)
                        desktop.brightnessLevel = Math.max(0.01, Math.min(1, parsed / 100))
                }
            }
        }

        Process {
            id: wifiReader
            command: [
                "bash",
                "-lc",
                "export LC_ALL=C; "
                + "radio=$(nmcli radio wifi 2>/dev/null); "
                + "device=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null "
                + "| awk -F: '$2 == \"wifi\" {print $1; exit}'); "
                + "ssid=\"\"; "
                + "if [ -n \"$device\" ]; then "
                + "ssid=$(nmcli -g GENERAL.CONNECTION device show \"$device\" "
                + "2>/dev/null | head -n1); "
                + "fi; "
                + "[ \"$ssid\" = \"--\" ] && ssid=\"\"; "
                + "printf '%s\\n%s\\n' \"$radio\" \"$ssid\""
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const lines = text.trim().split("\\n")
                    const radioState = lines.length > 0 ? lines[0].trim() : ""
                    const connectionName = lines.length > 1 ? lines[1].trim() : ""

                    desktop.wifiEnabled = radioState === "enabled"
                    desktop.wifiSsid = connectionName
                    desktop.wifiConnected = desktop.wifiEnabled
                        && connectionName.length > 0
                }
            }
        }

        Process {
            id: wifiWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    desktop.wifiWriterError = text.trim()

                    if (desktop.wifiWriterError.length > 0)
                        console.warn("Wi-Fi control:", desktop.wifiWriterError)
                }
            }

            onExited: function(exitCode, exitStatus) {
                if (exitCode !== 0) {
                    desktop.wifiMessage = desktop.wifiWriterError.length > 0
                        ? desktop.wifiWriterError
                        : "Unable to change Wi-Fi state"
                } else {
                    desktop.wifiMessage = desktop.wifiTargetEnabled
                        ? "Wi-Fi enabled"
                        : "Wi-Fi disabled"
                }

                desktop.wifiBusy = false
                wifiRefreshTimer.restart()
            }
        }

        Process {
            id: wifiScanner
            command: [
                "bash",
                "-lc",
                "export LC_ALL=C; "
                + "nmcli -t --escape no "
                + "-f IN-USE,SSID,SIGNAL,SECURITY "
                + "device wifi list --rescan yes 2>/dev/null"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const raw = text.trim()
                    const entries = raw.length > 0 ? raw.split("\n") : []
                    const strongest = {}

                    for (let index = 0; index < entries.length; index++) {
                        const parts = entries[index].split(":")

                        if (parts.length < 4)
                            continue

                        const inUse = parts.shift().trim()
                        const security = parts.pop().trim()
                        const parsedSignal = parseInt(parts.pop())
                        const ssid = parts.join(":").trim()

                        if (ssid.length === 0)
                            continue

                        const signal = isNaN(parsedSignal) ? 0 : parsedSignal
                        const candidate = {
                            "ssid": ssid,
                            "signal": signal,
                            "security": security,
                            "connected": inUse === "*"
                        }

                        if (strongest[ssid] === undefined
                                || signal > strongest[ssid].signal) {
                            strongest[ssid] = candidate
                        }
                    }

                    const networks = []

                    for (const ssid in strongest)
                        networks.push(strongest[ssid])

                    networks.sort(function(left, right) {
                        if (left.connected !== right.connected)
                            return left.connected ? -1 : 1

                        return right.signal - left.signal
                    })

                    desktop.wifiNetworks = networks.slice(0, 6)
                    desktop.wifiScanning = false

                    if (desktop.wifiNetworks.length === 0
                            && desktop.wifiEnabled) {
                        desktop.wifiMessage = "No network found"
                    } else if (desktop.wifiMessage === "Scanning...") {
                        desktop.wifiMessage = ""
                    }
                }
            }

            onExited: function(exitCode, exitStatus) {
                desktop.wifiScanning = false

                if (exitCode !== 0)
                    desktop.wifiMessage = "Scan unavailable"
            }
        }

        Process {
            id: wifiConnector

            stdout: StdioCollector {
                onStreamFinished: {
                    const message = text.trim()

                    if (message.length > 0)
                        console.log("Wi-Fi connection:", message)
                }
            }

            stderr: StdioCollector {
                onStreamFinished: {
                    const message = text.trim()

                    if (message.length > 0)
                        console.warn("Wi-Fi connection:", message)
                }
            }

            onExited: function(exitCode, exitStatus) {
                desktop.wifiBusy = false
                desktop.wifiMessage = exitCode === 0
                    ? "Connected"
                    : "Password required or connection failed"
                wifiRefreshTimer.restart()
            }
        }

        Timer {
            id: wifiRefreshTimer
            interval: 900
            repeat: false

            onTriggered: {
                if (!wifiReader.running)
                    wifiReader.running = true

                if (desktop.wifiMenuOpen && desktop.wifiEnabled)
                    desktop.scanWifi()
            }
        }

        function refreshSystemState() {
            if (!batteryReader.running)
                batteryReader.running = true

            if (!volumeReader.running)
                volumeReader.running = true

            if (!brightnessReader.running)
                brightnessReader.running = true

            if (!wifiReader.running && !wifiBusy)
                wifiReader.running = true
        }

        Process {
            id: volumeWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    const message = text.trim()

                    if (message.length > 0)
                        console.warn("Volume control:", message)
                }
            }
        }

        Process {
            id: brightnessWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    const message = text.trim()

                    if (message.length > 0)
                        console.warn("Brightness control:", message)
                }
            }

            onExited: function(exitCode, exitStatus) {
                if (exitCode !== 0)
                    console.warn("brightnessctl exited with code", exitCode)

                desktop.flushBrightnessWrite()
            }
        }

        Timer {
            id: volumeWriteTimer
            interval: 45
            repeat: false

            onTriggered: {
                volumeWriter.exec([
                    "wpctl",
                    "set-volume",
                    "@DEFAULT_AUDIO_SINK@",
                    Math.round(desktop.pendingVolumeLevel * 100) + "%"
                ])
            }
        }

        function queueVolume(level) {
            const normalized = Math.max(0, Math.min(1, level))
            volumeLevel = normalized
            pendingVolumeLevel = normalized
            volumeWriteTimer.restart()
        }

        function flushBrightnessWrite() {
            if (brightnessWriter.running || !brightnessWriteQueued)
                return

            brightnessWriteQueued = false
            brightnessAppliedPercent = brightnessWritePercent

            brightnessWriter.exec([
                "brightnessctl",
                "-q",
                "-d",
                brightnessDevice,
                "set",
                brightnessAppliedPercent + "%"
            ])
        }

        function queueBrightness(level) {
            const normalized = Math.max(0.01, Math.min(1, level))
            const percent = Math.round(normalized * 100)

            brightnessLevel = normalized
            pendingBrightnessLevel = normalized
            brightnessWritePercent = percent

            if (percent === brightnessAppliedPercent
                    && !brightnessWriter.running) {
                brightnessWriteQueued = false
                return
            }

            brightnessWriteQueued = true
            flushBrightnessWrite()
        }

        function scanWifi() {
            if (!wifiEnabled || wifiScanner.running)
                return

            wifiScanning = true
            wifiMessage = "Scanning..."
            wifiScanner.running = true
        }

        function toggleWifiMenu() {
            wifiMenuOpen = !wifiMenuOpen

            if (wifiMenuOpen && wifiEnabled)
                scanWifi()
        }

        function connectWifi(ssid) {
            if (wifiBusy || ssid.length === 0)
                return

            if (wifiConnected && ssid === wifiSsid) {
                wifiMessage = "Already connected"
                return
            }

            wifiBusy = true
            wifiMessage = "Connecting to " + ssid + "..."

            wifiConnector.exec([
                "nmcli",
                "--wait",
                "15",
                "device",
                "wifi",
                "connect",
                ssid
            ])
        }

        function toggleWifi() {
            if (wifiBusy)
                return

            wifiTargetEnabled = !wifiEnabled
            wifiBusy = true
            wifiWriterError = ""
            wifiMessage = wifiTargetEnabled
                ? "Enabling Wi-Fi..."
                : "Disabling Wi-Fi..."

            wifiWriter.exec([
                "env",
                "LC_ALL=C",
                "nmcli",
                "--wait",
                "5",
                "radio",
                "wifi",
                wifiTargetEnabled ? "on" : "off"
            ])
        }

        Timer {
            interval: 2500
            running: true
            repeat: true
            triggeredOnStart: true
            onTriggered: desktop.refreshSystemState()
        }


        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "F1"
            onActivated: desktop.viewState = 1
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "F2"
            onActivated: {
                desktop.viewState = 2
                searchInput.forceActiveFocus()
            }
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "F3"
            onActivated: desktop.viewState = 3
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "F4"
            onActivated: {
                desktop.viewState = 4
                searchInput.forceActiveFocus()
            }
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "Escape"
            onActivated: {
                if (desktop.wifiMenuOpen)
                    desktop.wifiMenuOpen = false
                else
                    desktop.viewState = 1
            }
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "F11"
            onActivated: desktop.fullscreen = !desktop.fullscreen
        }

        Shortcut {
            context: Qt.ApplicationShortcut
            sequence: "Ctrl+Q"
            onActivated: Qt.quit()
        }


        Connections {
            target: Qt.application

            function onActiveChanged() {
                if (Qt.application.active && desktop.restoreWidgetsOnFocus) {
                    desktop.restoreWidgetsOnFocus = false
                    searchInput.text = ""
                    searchInput.focus = false
                    desktop.viewState = 4
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            color: desktop.ivory

            Image {
                id: wallpaper

                anchors.fill: parent
                source: Qt.resolvedUrl("assets/wallpaper.jpg")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true
                mipmap: true
            }

            Rectangle {
                anchors.fill: parent
                color: "#12F6F1E8"
            }

            Rectangle {
                id: topBar

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: desktop.s(30)
                color: "#EEFBF9F5"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: Math.max(1, desktop.s(0.7))
                    color: "#2FD8CCBC"
                }

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: desktop.s(20)
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: desktop.s(19)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/system-mark.svg")
                        size: desktop.s(10.5)
                        iconOpacity: 0.94
                    }

                    Item {
                        width: desktop.s(38)
                        height: desktop.s(20)

                        Text {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                                topMargin: desktop.s(2)
                            }

                            text: "Home"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: desktop.s(8.8)
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            width: desktop.s(2)
                            height: desktop.s(2)
                            radius: desktop.s(1)
                            color: desktop.softInk

                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: desktop.s(0.5)
                            }
                        }
                    }

                    Text {
                        text: "Work"
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(8.8)
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: Qt.formatDateTime(desktop.now, "ddd, MMM d    h:mm AP")
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(8)
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: desktop.s(18)
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: desktop.s(10)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/volume.svg")
                        size: desktop.s(10.5)
                        iconOpacity: 0.9
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/wifi.svg")
                        size: desktop.s(11.5)
                        iconOpacity: desktop.wifiEnabled ? 0.9 : 0.32
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/battery.svg")
                        size: desktop.s(12.5)
                        iconOpacity: 0.9
                    }

                    Text {
                        text: desktop.batteryPercent + "%"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(8)
                    }
                }
            }

            Column {
                x: desktop.s(140)
                y: desktop.s(226)
                spacing: desktop.s(7)

                Text {
                    text: desktop.greetingLabel(desktop.now)
                    color: desktop.graphite
                    font.family: "Inter"
                    font.pixelSize: desktop.s(27)
                    font.weight: Font.Light
                }

                Text {
                    text: desktop.fullDateLabel(desktop.now)
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(13)
                    font.weight: Font.Normal
                }
            }

            Column {
                anchors {
                    right: parent.right
                    rightMargin: desktop.s(74)
                    top: parent.top
                    topMargin: desktop.s(76)
                }

                spacing: desktop.s(5.5)

                Row {
                    spacing: desktop.s(8)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/brightness.svg")
                        size: desktop.s(23)
                        iconOpacity: 0.92
                    }

                    Text {
                        text: "18°"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(21.5)
                        font.weight: Font.Light
                    }
                }

                Text {
                    text: "Versailles"
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(9.3)
                }

                Text {
                    text: "Sunny"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(9.3)
                }

                Rectangle {
                    width: desktop.s(78)
                    height: Math.max(1, desktop.s(0.7))
                    color: "#55D8CCBC"
                }

                Row {
                    spacing: desktop.s(7)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/calendar.svg")
                        size: desktop.s(14)
                        iconOpacity: 0.88
                    }

                    Text {
                        text: "Design system"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(9.3)
                    }
                }

                Text {
                    text: "in 40 min"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(9.3)
                }
            }

            Rectangle {
                id: libraryPanel

                property bool opened: desktop.viewState === 4

                anchors {
                    left: parent.left
                    leftMargin: desktop.p(26)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(29)
                }

                width: desktop.p(146)
                height: desktop.p(160)
                radius: desktop.p(10)

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.7))
                border.color: desktop.panelBorder

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: desktop.p(15)
                    }

                    spacing: desktop.p(11)

                    Text {
                        text: "Apps"
                        color: desktop.graphite
                        font.family: "Inter"
                        font.pixelSize: desktop.p(9)
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "Recent"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8)
                    }

                    Text {
                        text: "Documents"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8)
                    }

                    Text {
                        text: "Downloads"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8)
                    }

                    Item {
                        width: 1
                        height: desktop.p(4)
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(1, desktop.p(0.7))
                        color: "#50D8CCBC"
                    }

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - desktop.p(20)
                            text: "Show All"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8)
                        }

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/expand.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.85
                        }
                    }
                }
            }

            Rectangle {
                id: commandPalette

                property bool opened: desktop.viewState === 2 || desktop.viewState === 4

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(97)
                }

                width: desktop.p(552)
                height: desktop.p(123)
                radius: desktop.p(10)

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.7))
                border.color: desktop.panelBorder
                clip: true

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation {
                        duration: 165
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 165
                        easing.type: Easing.OutCubic
                    }
                }

                Item {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }

                    height: desktop.p(45)

                    PremiumIcon {
                        anchors {
                            left: parent.left
                            leftMargin: desktop.p(18)
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/search.svg")
                        size: desktop.p(13)
                        iconOpacity: 0.9
                    }

                    TextField {
                        id: searchInput

                        anchors {
                            left: parent.left
                            leftMargin: desktop.p(38)
                            right: parent.right
                            rightMargin: desktop.p(48)
                            verticalCenter: parent.verticalCenter
                        }

                        height: desktop.p(25)
                        color: desktop.graphite
                        selectedTextColor: desktop.graphite
                        selectionColor: desktop.sand
                        placeholderText: "Search or type a command..."
                        placeholderTextColor: "#A19990"
                        font.family: "Inter"
                        font.pixelSize: desktop.p(9.4)
                        selectByMouse: true
                        leftPadding: desktop.p(6)
                        rightPadding: desktop.p(0)
                        topPadding: 0
                        bottomPadding: 0
                        verticalAlignment: TextInput.AlignVCenter
                        background: Item {}

                        Keys.onReturnPressed: {
                            const matches = desktop.filteredAppItems()

                            if (matches.length > 0)
                                desktop.launchApplication(matches[0])
                        }

                        Keys.onEnterPressed: {
                            const matches = desktop.filteredAppItems()

                            if (matches.length > 0)
                                desktop.launchApplication(matches[0])
                        }
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: desktop.p(17)
                            verticalCenter: parent.verticalCenter
                        }

                        text: "⌘ K"
                        color: "#A89F96"
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.3)
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: desktop.p(45)
                    }

                    height: Math.max(1, desktop.p(0.7))
                    color: "#55D8CCBC"
                }

                Text {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        verticalCenter: parent.verticalCenter
                        verticalCenterOffset: desktop.p(23)
                    }

                    visible: desktop.filteredAppItems().length === 0
                    text: "No matching application"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(8)
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: desktop.p(12)
                    }

                    spacing: desktop.p(26)

                    Repeater {
                        model: desktop.filteredAppItems()

                        delegate: Item {
                            id: appTile

                            width: desktop.p(64)
                            height: desktop.p(56)

                            Rectangle {
                                anchors {
                                    horizontalCenter: parent.horizontalCenter
                                    bottom: parent.bottom
                                    bottomMargin: desktop.p(1)
                                }

                                width: desktop.p(22)
                                height: Math.max(1, desktop.p(0.7))
                                radius: height / 2
                                color: desktop.softInk
                                opacity: tileMouse.containsMouse ? 0.48 : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 85
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: desktop.p(3)

                                PremiumIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: Qt.resolvedUrl("icons/" + modelData.icon)
                                    size: desktop.p(20)
                                    iconOpacity: tileMouse.containsMouse ? 1.0 : 0.88
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.title
                                    color: tileMouse.containsMouse ? desktop.graphite : desktop.softInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(8.4)
                                    font.weight: Font.Normal
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.subtitle
                                    color: desktop.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(6.9)
                                }
                            }

                            MouseArea {
                                id: tileMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: desktop.launchApplication(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: settingsPanel

                property bool opened: desktop.viewState === 3 || desktop.viewState === 4

                anchors {
                    right: parent.right
                    rightMargin: desktop.p(26)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(29)
                }

                width: desktop.p(160)
                height: desktop.p(168)
                radius: desktop.p(10)

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.65))
                border.color: desktop.panelBorder

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: desktop.p(12)
                    }

                    spacing: desktop.p(7)

                    Item {
                        width: parent.width
                        height: desktop.p(15)

                        PremiumIcon {
                            id: wifiRowIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/wifi.svg")
                            size: desktop.p(12)
                            iconOpacity: desktop.wifiEnabled ? 0.88 : 0.40
                        }

                        Text {
                            anchors {
                                left: wifiRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(42)
                            text: "Wi-Fi"
                            color: desktop.wifiEnabled
                                ? desktop.graphite
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.8)
                        }

                        Rectangle {
                            id: wifiToggle

                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(20)
                            height: desktop.p(11)
                            radius: height / 2
                            color: desktop.wifiEnabled
                                ? desktop.softInk
                                : "#B9B1A8"
                            opacity: desktop.wifiBusy ? 0.58 : 1

                            Rectangle {
                                width: desktop.p(7)
                                height: desktop.p(7)
                                radius: width / 2
                                color: desktop.warmWhite

                                anchors.verticalCenter: parent.verticalCenter

                                x: desktop.wifiEnabled
                                    ? parent.width - width - desktop.p(2)
                                    : desktop.p(2)

                                Behavior on x {
                                    NumberAnimation {
                                        duration: 110
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }

                        Text {
                            anchors {
                                right: wifiToggle.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(38)
                            text: desktop.wifiBusy
                                ? "..."
                                : (!desktop.wifiEnabled
                                    ? "Off"
                                    : (desktop.wifiConnected
                                        ? desktop.wifiSsid
                                        : "On"))
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(6.9)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                right: wifiToggle.left
                                rightMargin: desktop.p(5)
                            }

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: desktop.toggleWifiMenu()
                        }

                        MouseArea {
                            anchors.fill: wifiToggle
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !desktop.wifiBusy
                            onClicked: desktop.toggleWifi()
                        }
                    }

                    Repeater {
                        model: [
                            {
                                "icon": "bluetooth.svg",
                                "label": "Bluetooth",
                                "state": "On",
                                "enabled": true
                            },
                            {
                                "icon": "moon.svg",
                                "label": "Do Not Disturb",
                                "state": "Off",
                                "enabled": false
                            }
                        ]

                        delegate: Item {
                            width: parent.width
                            height: desktop.p(15)

                            PremiumIcon {
                                id: rowIcon
                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }
                                source: Qt.resolvedUrl("icons/" + modelData.icon)
                                size: desktop.p(12)
                                iconOpacity: 0.88
                            }

                            Text {
                                anchors {
                                    left: rowIcon.right
                                    leftMargin: desktop.p(7)
                                    verticalCenter: parent.verticalCenter
                                }
                                width: desktop.p(72)
                                text: modelData.label
                                color: modelData.enabled
                                    ? desktop.graphite
                                    : desktop.softInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(7.8)
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                id: toggle
                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }
                                width: desktop.p(20)
                                height: desktop.p(11)
                                radius: height / 2
                                color: modelData.enabled
                                    ? desktop.softInk
                                    : "#B9B1A8"

                                Rectangle {
                                    width: desktop.p(7)
                                    height: desktop.p(7)
                                    radius: width / 2
                                    color: desktop.warmWhite

                                    anchors.verticalCenter: parent.verticalCenter

                                    x: modelData.enabled
                                        ? parent.width - width - desktop.p(2)
                                        : desktop.p(2)

                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 110
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }

                            Text {
                                anchors {
                                    right: toggle.left
                                    rightMargin: desktop.p(7)
                                    verticalCenter: parent.verticalCenter
                                }
                                width: desktop.p(28)
                                text: modelData.state
                                horizontalAlignment: Text.AlignRight
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.9)
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(1, desktop.p(0.65))
                        color: "#52D8CCBC"
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(15)

                        PremiumIcon {
                            id: displayIcon
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/display.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.88
                        }

                        Text {
                            anchors {
                                left: displayIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }
                            text: "Display"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.8)
                        }

                        PremiumIcon {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/chevron-right.svg")
                            size: desktop.p(10)
                            iconOpacity: 0.78
                        }
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(16)

                        PremiumIcon {
                            id: volumeLeft
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/volume.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.84
                        }

                        PremiumIcon {
                            id: volumeRight
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/volume.svg")
                            size: desktop.p(10)
                            iconOpacity: 0.74
                        }

                        Slider {
                            id: volumeSlider

                            anchors {
                                left: volumeLeft.right
                                leftMargin: desktop.p(7)
                                right: volumeRight.left
                                rightMargin: desktop.p(7)
                                top: parent.top
                                bottom: parent.bottom
                            }

                            implicitHeight: desktop.p(16)
                            z: 2
                            hoverEnabled: true

                            from: 0
                            to: 1
                            value: desktop.volumeLevel
                            padding: 0

                            live: true

                            onMoved: desktop.queueVolume(value)

                            onPressedChanged: {
                                if (!pressed)
                                    desktop.queueVolume(value)
                            }

                            background: Rectangle {
                                x: volumeSlider.leftPadding
                                y: volumeSlider.topPadding
                                    + volumeSlider.availableHeight / 2
                                    - height / 2
                                width: volumeSlider.availableWidth
                                height: desktop.p(1.6)
                                radius: height / 2
                                color: "#CBC1B5"

                                Rectangle {
                                    width: volumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: desktop.softInk
                                }
                            }

                            handle: Rectangle {
                                x: volumeSlider.leftPadding
                                    + volumeSlider.visualPosition
                                    * (volumeSlider.availableWidth - width)
                                y: volumeSlider.topPadding
                                    + volumeSlider.availableHeight / 2
                                    - height / 2
                                width: desktop.p(8)
                                height: desktop.p(8)
                                radius: width / 2
                                color: desktop.warmWhite
                                border.width: Math.max(1, desktop.p(0.6))
                                border.color: "#AFA69D"
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(16)

                        PremiumIcon {
                            id: brightnessLeft
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/brightness.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.84
                        }

                        PremiumIcon {
                            id: brightnessRight
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }
                            source: Qt.resolvedUrl("icons/brightness.svg")
                            size: desktop.p(10)
                            iconOpacity: 0.74
                        }

                        Slider {
                            id: brightnessSlider

                            anchors {
                                left: brightnessLeft.right
                                leftMargin: desktop.p(7)
                                right: brightnessRight.left
                                rightMargin: desktop.p(7)
                                top: parent.top
                                bottom: parent.bottom
                            }

                            implicitHeight: desktop.p(16)
                            z: 2
                            hoverEnabled: true

                            from: 0.01
                            to: 1
                            value: desktop.brightnessLevel
                            padding: 0

                            live: true

                            onMoved: desktop.queueBrightness(value)

                            onPressedChanged: {
                                if (!pressed)
                                    desktop.queueBrightness(value)
                            }

                            background: Rectangle {
                                x: brightnessSlider.leftPadding
                                y: brightnessSlider.topPadding
                                    + brightnessSlider.availableHeight / 2
                                    - height / 2
                                width: brightnessSlider.availableWidth
                                height: desktop.p(1.6)
                                radius: height / 2
                                color: "#CBC1B5"

                                Rectangle {
                                    width: brightnessSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: desktop.softInk
                                }
                            }

                            handle: Rectangle {
                                x: brightnessSlider.leftPadding
                                    + brightnessSlider.visualPosition
                                    * (brightnessSlider.availableWidth - width)
                                y: brightnessSlider.topPadding
                                    + brightnessSlider.availableHeight / 2
                                    - height / 2
                                width: desktop.p(8)
                                height: desktop.p(8)
                                radius: width / 2
                                color: desktop.warmWhite
                                border.width: Math.max(1, desktop.p(0.6))
                                border.color: "#AFA69D"
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: wifiMenu

                anchors {
                    right: settingsPanel.left
                    rightMargin: desktop.p(9)
                    bottom: settingsPanel.bottom
                }

                width: desktop.p(178)
                height: desktop.p(170)
                radius: desktop.p(10)
                z: 20

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.65))
                border.color: desktop.panelBorder

                visible: opacity > 0
                enabled: desktop.wifiMenuOpen
                opacity: desktop.wifiMenuOpen ? 1 : 0
                scale: desktop.wifiMenuOpen ? 1 : 0.985

                Behavior on opacity {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: 140
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    z: 1
                    acceptedButtons: Qt.AllButtons
                    preventStealing: true
                    propagateComposedEvents: false

                    onPressed: function(mouse) {
                        mouse.accepted = true
                    }

                    onClicked: function(mouse) {
                        mouse.accepted = true
                    }
                }

                Column {
                    z: 2

                    anchors {
                        fill: parent
                        margins: desktop.p(12)
                    }

                    spacing: desktop.p(7)

                    Item {
                        width: parent.width
                        height: desktop.p(17)

                        Text {
                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            text: "Wi-Fi"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.7)
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: desktop.wifiScanning ? "Scanning..." : "Refresh"
                            color: desktop.wifiScanning
                                ? desktop.mutedInk
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(6.8)

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -desktop.p(5)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: desktop.wifiEnabled
                                    && !desktop.wifiScanning
                                onClicked: desktop.scanWifi()
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.max(1, desktop.p(0.65))
                        color: "#52D8CCBC"
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(15)

                        PremiumIcon {
                            id: activeWifiIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/wifi.svg")
                            size: desktop.p(11)
                            iconOpacity: desktop.wifiConnected ? 0.90 : 0.44
                        }

                        Text {
                            anchors {
                                left: activeWifiIcon.right
                                leftMargin: desktop.p(7)
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: !desktop.wifiEnabled
                                ? "Wi-Fi is off"
                                : (desktop.wifiConnected
                                    ? desktop.wifiSsid
                                    : "Not connected")
                            color: desktop.wifiConnected
                                ? desktop.graphite
                                : desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.5)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: desktop.wifiEnabled
                                ? Qt.ArrowCursor
                                : Qt.PointingHandCursor
                            enabled: !desktop.wifiEnabled
                                && !desktop.wifiBusy
                            onClicked: desktop.toggleWifi()
                        }
                    }

                    ListView {
                        id: wifiNetworkList

                        width: parent.width
                        height: desktop.p(88)
                        clip: true
                        spacing: desktop.p(1)
                        model: desktop.wifiNetworks
                        interactive: contentHeight > height
                        visible: desktop.wifiEnabled

                        delegate: Item {
                            required property var modelData

                            width: wifiNetworkList.width
                            height: desktop.p(20)

                            Rectangle {
                                anchors.fill: parent
                                radius: desktop.p(5)
                                color: networkMouse.containsMouse
                                    ? "#3AD8CCBC"
                                    : "transparent"
                            }

                            PremiumIcon {
                                id: networkIcon

                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }

                                source: Qt.resolvedUrl("icons/wifi.svg")
                                size: desktop.p(10)
                                iconOpacity: modelData.connected ? 0.95 : 0.68
                            }

                            Column {
                                anchors {
                                    left: networkIcon.right
                                    leftMargin: desktop.p(6)
                                    right: signalText.left
                                    rightMargin: desktop.p(7)
                                    verticalCenter: parent.verticalCenter
                                }

                                spacing: desktop.p(0.5)

                                Text {
                                    width: parent.width
                                    text: modelData.ssid
                                    color: modelData.connected
                                        ? desktop.graphite
                                        : desktop.softInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(7.2)
                                    font.weight: modelData.connected
                                        ? Font.Medium
                                        : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.connected
                                        ? "Connected"
                                        : (modelData.security.length > 0
                                            && modelData.security !== "--"
                                            ? "Secured"
                                            : "Open")
                                    color: desktop.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(5.8)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: signalText

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                text: modelData.signal + "%"
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.3)
                            }

                            MouseArea {
                                id: networkMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !desktop.wifiBusy
                                onClicked: desktop.connectWifi(modelData.ssid)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        height: desktop.p(12)
                        visible: desktop.wifiMessage.length > 0
                        text: desktop.wifiMessage
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(6.2)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
