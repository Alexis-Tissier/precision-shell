import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls

ShellRoot {
    id: root

    property bool launcherOpen: false
    property bool dashboardOpen: false
    property bool desktopWidgetsVisible: true

    property var niriWorkspaces: []
    property var niriWindows: []
    property int focusedWorkspaceId: -1
    property int focusedWindowId: -1
    property bool workspaceHasWindows: false
    property string activeAppLabel: "Precision"

    property bool switcherOpen: false
    property var switcherItems: []
    property int switcherIndex: 0
    property var windowHistory: []

    property bool osdWindowActive: false
    property bool osdShown: false
    property string osdKind: "volume"
    property real osdLevel: 0.0

    function showOsd(kind, level) {
        osdKind = kind
        osdLevel = Math.max(0, Math.min(1, level))
        osdWindowActive = true
        osdShown = true
        osdHideTimer.restart()
    }

    Timer {
        id: osdHideTimer
        interval: 950
        repeat: false

        onTriggered: {
            root.osdShown = false
            osdDisposeTimer.restart()
        }
    }

    Timer {
        id: osdDisposeTimer
        interval: 170
        repeat: false

        onTriggered: {
            if (!root.osdShown)
                root.osdWindowActive = false
        }
    }

    function openLauncher() {
        dashboardOpen = false
        launcherOpen = true
        launcherSearch.text = ""

        Qt.callLater(function() {
            launcherSearch.forceActiveFocus()
        })
    }

    function closeLauncher() {
        launcherOpen = false
        launcherSearch.text = ""
        launcherSearch.focus = false
    }

    function toggleLauncher() {
        if (launcherOpen)
            closeLauncher()
        else
            openLauncher()
    }

    function openDashboard() {
        launcherOpen = false
        dashboardOpen = true
        dashboardSearch.text = ""
    }

    function closeDashboard() {
        dashboardOpen = false
        dashboardSearch.text = ""
        dashboardSearch.focus = false
    }

    function toggleDashboard() {
        if (dashboardOpen)
            closeDashboard()
        else
            openDashboard()
    }

    function runNiriAction(actionName) {
        Quickshell.execDetached({
            command: [
                "niri",
                "msg",
                "action",
                actionName
            ]
        })
    }

    function switcherIcon(appId) {
        const id = (appId || "").toLowerCase()

        if (id.indexOf("brave") !== -1
                || id.indexOf("chromium") !== -1
                || id.indexOf("firefox") !== -1)
            return "browser.svg"

        if (id.indexOf("alacritty") !== -1
                || id.indexOf("terminal") !== -1
                || id.indexOf("kitty") !== -1)
            return "terminal.svg"

        if (id.indexOf("nautilus") !== -1
                || id.indexOf("files") !== -1)
            return "files.svg"

        if (id.indexOf("text-editor") !== -1
                || id.indexOf("gedit") !== -1
                || id.indexOf("code") !== -1)
            return "notes.svg"

        return "system-mark.svg"
    }

    function shortWindowTitle(windowData) {
        const title = windowData && windowData.title
            ? windowData.title.trim()
            : ""

        if (title.length === 0)
            return "Open window"

        return title
    }

    function rememberWindow(windowId) {
        const parsed = parseInt(windowId)

        if (isNaN(parsed) || parsed < 0)
            return

        const updated = [parsed]

        for (let index = 0; index < windowHistory.length; index++) {
            const existing = parseInt(windowHistory[index])

            if (!isNaN(existing) && existing !== parsed)
                updated.push(existing)
        }

        windowHistory = updated
    }

    function syncWindowHistory() {
        const available = {}

        for (let index = 0; index < niriWindows.length; index++)
            available[niriWindows[index].id] = true

        const updated = []

        if (focusedWindowId >= 0 && available[focusedWindowId])
            updated.push(focusedWindowId)

        for (let index = 0; index < windowHistory.length; index++) {
            const existing = parseInt(windowHistory[index])

            if (available[existing] && updated.indexOf(existing) === -1)
                updated.push(existing)
        }

        for (let index = 0; index < niriWindows.length; index++) {
            const id = niriWindows[index].id

            if (updated.indexOf(id) === -1)
                updated.push(id)
        }

        windowHistory = updated
    }

    function windowById(windowId) {
        for (let index = 0; index < niriWindows.length; index++) {
            if (niriWindows[index].id === windowId)
                return niriWindows[index]
        }

        return null
    }

    function actualFocusedWindowId() {
        if (focusedWindowId >= 0
                && windowById(focusedWindowId) !== null) {
            return focusedWindowId
        }

        for (let index = 0; index < niriWindows.length; index++) {
            if (niriWindows[index].is_focused)
                return niriWindows[index].id
        }

        return -1
    }

    function buildSwitcherItems() {
        syncWindowHistory()

        const currentId = actualFocusedWindowId()
        const orderedIds = []

        if (currentId >= 0)
            orderedIds.push(currentId)

        for (let index = 0; index < windowHistory.length; index++) {
            const id = parseInt(windowHistory[index])

            if (!isNaN(id) && orderedIds.indexOf(id) === -1)
                orderedIds.push(id)
        }

        for (let index = 0; index < niriWindows.length; index++) {
            const id = niriWindows[index].id

            if (orderedIds.indexOf(id) === -1)
                orderedIds.push(id)
        }

        const items = []

        for (let index = 0; index < orderedIds.length; index++) {
            const windowData = windowById(orderedIds[index])

            if (windowData === null)
                continue

            items.push({
                "id": windowData.id,
                "appName": friendlyAppName(
                    windowData.app_id || "",
                    windowData.title || ""
                ),
                "title": shortWindowTitle(windowData),
                "icon": switcherIcon(windowData.app_id || ""),
                "workspaceId": windowData.workspace_id
            })
        }

        return items
    }

    function switcherDisplayItems() {
        const count = switcherItems.length

        if (count <= 5) {
            return switcherItems.map(function(item, index) {
                return Object.assign({}, item, {
                    "selected": index === switcherIndex
                })
            })
        }

        let start = switcherIndex - 2
        start = Math.max(0, Math.min(start, count - 5))

        const result = []

        for (let index = start; index < start + 5; index++) {
            result.push(Object.assign({}, switcherItems[index], {
                "selected": index === switcherIndex
            }))
        }

        return result
    }

    function beginSwitcher(direction) {
        const items = buildSwitcherItems()

        if (items.length < 2)
            return

        switcherItems = items

        // buildSwitcherItems() always places the currently focused
        // window first. The first Alt+Tab therefore selects the most
        // recently used *other* window.
        switcherIndex = direction >= 0
            ? 1
            : items.length - 1

        switcherOpen = true
        switcherSafetyTimer.restart()

        Qt.callLater(function() {
            switcherKeyCatcher.forceActiveFocus()
        })
    }

    function stepSwitcher(direction) {
        if (!switcherOpen || switcherItems.length < 2)
            return

        switcherIndex = (
            switcherIndex + direction + switcherItems.length
        ) % switcherItems.length

        switcherSafetyTimer.restart()
    }

    function closeSwitcher() {
        switcherOpen = false
        switcherItems = []
        switcherIndex = 0
        switcherSafetyTimer.stop()
    }

    function confirmSwitcher() {
        if (!switcherOpen || switcherItems.length === 0) {
            closeSwitcher()
            return
        }

        const selected = switcherItems[switcherIndex]
        const windowId = parseInt(selected.id)

        closeSwitcher()

        if (isNaN(windowId))
            return

        Quickshell.execDetached({
            command: [
                "niri",
                "msg",
                "action",
                "focus-window",
                "--id",
                String(windowId)
            ]
        })
    }

    function cancelSwitcher() {
        closeSwitcher()
    }

    Timer {
        id: switcherSafetyTimer

        interval: 1500
        repeat: false

        onTriggered: root.confirmSwitcher()
    }

    IpcHandler {
        target: "launcher"

        function open(): void {
            root.openLauncher()
        }

        function close(): void {
            root.closeLauncher()
        }

        function toggle(): void {
            root.toggleLauncher()
        }

        function isOpen(): bool {
            return root.launcherOpen
        }
    }

    IpcHandler {
        target: "dashboard"

        function open(): void {
            root.openDashboard()
        }

        function close(): void {
            root.closeDashboard()
        }

        function toggle(): void {
            root.toggleDashboard()
        }

        function isOpen(): bool {
            return root.dashboardOpen
        }
    }

    IpcHandler {
        target: "switcher"

        function next(): void {
            if (root.switcherOpen)
                root.stepSwitcher(1)
            else
                root.beginSwitcher(1)
        }

        function previous(): void {
            if (root.switcherOpen)
                root.stepSwitcher(-1)
            else
                root.beginSwitcher(-1)
        }

        function close(): void {
            root.cancelSwitcher()
        }
    }

    IpcHandler {
        target: "desktopWidgets"

        function show(): void {
            root.desktopWidgetsVisible = true
        }

        function hide(): void {
            root.desktopWidgetsVisible = false
        }

        function toggle(): void {
            root.desktopWidgetsVisible = !root.desktopWidgetsVisible
        }

        function isVisible(): bool {
            return root.desktopWidgetsVisible
        }
    }

    IpcHandler {
        target: "media"

        function volumeUp(): void {
            desktop.adjustVolume(0.05)
        }

        function volumeDown(): void {
            desktop.adjustVolume(-0.05)
        }

        function brightnessUp(): void {
            desktop.adjustBrightness(0.05)
        }

        function brightnessDown(): void {
            desktop.adjustBrightness(-0.05)
        }
    }

    IpcHandler {
        target: "osd"

        function show(kind: string, level: string): void {
            const parsed = parseFloat(level)

            if (!isNaN(parsed))
                root.showOsd(kind, parsed)
        }
    }

    Connections {
        target: Qt.application

        function onActiveChanged() {
            if (!Qt.application.active) {
                if (root.launcherOpen)
                    root.closeLauncher()

                if (root.dashboardOpen)
                    root.closeDashboard()
            }
        }
    }

    function friendlyAppName(appId, title) {
        const id = (appId || "").toLowerCase()

        if (id.indexOf("brave") !== -1)
            return "Brave"

        if (id.indexOf("alacritty") !== -1)
            return "Alacritty"

        if (id.indexOf("nautilus") !== -1)
            return "Files"

        if (id.indexOf("gnome-text-editor") !== -1)
            return "Text Editor"

        if (id.indexOf("calendar") !== -1)
            return "Calendar"

        if (id.indexOf("thunderbird") !== -1)
            return "Thunderbird"

        if (title && title.length > 0) {
            const separators = [" — ", " - "]

            for (let index = 0; index < separators.length; index++) {
                const separator = separators[index]
                const position = title.indexOf(separator)

                if (position > 0)
                    return title.substring(0, position)
            }

            return title
        }

        return appId && appId.length > 0 ? appId : "Precision"
    }

    function updateNiriDerivedState() {
        let workspaceId = focusedWorkspaceId

        if (workspaceId < 0) {
            for (let index = 0; index < niriWorkspaces.length; index++) {
                const workspace = niriWorkspaces[index]

                if (workspace.is_focused) {
                    workspaceId = workspace.id
                    break
                }
            }
        }

        focusedWorkspaceId = workspaceId

        let activeWindowId = focusedWindowId

        for (let index = 0; index < niriWorkspaces.length; index++) {
            const workspace = niriWorkspaces[index]

            if (workspace.id === workspaceId
                    && workspace.active_window_id !== null
                    && workspace.active_window_id !== undefined) {
                activeWindowId = workspace.active_window_id
                break
            }
        }

        let hasWindows = false
        let focusedCandidate = null
        let explicitFocusCandidate = null
        let activeCandidate = null

        for (let index = 0; index < niriWindows.length; index++) {
            const window = niriWindows[index]

            if (window.workspace_id === workspaceId)
                hasWindows = true

            if (window.id === focusedWindowId)
                explicitFocusCandidate = window

            if (window.is_focused)
                focusedCandidate = window

            if (window.id === activeWindowId)
                activeCandidate = window
        }

        const activeWindow = explicitFocusCandidate
            || focusedCandidate
            || activeCandidate

        workspaceHasWindows = hasWindows

        if (activeWindow !== null) {
            focusedWindowId = activeWindow.id
            activeAppLabel = friendlyAppName(
                activeWindow.app_id || "",
                activeWindow.title || ""
            )
        } else {
            activeAppLabel = hasWindows ? "Workspace" : "Precision"
        }
    }

    function replaceNiriWindow(windowData) {
        const updated = []
        let replaced = false

        for (let index = 0; index < niriWindows.length; index++) {
            const existing = niriWindows[index]

            if (existing.id === windowData.id) {
                updated.push(windowData)
                replaced = true
            } else {
                updated.push(existing)
            }
        }

        if (!replaced)
            updated.push(windowData)

        niriWindows = updated
    }

    function removeNiriWindow(windowId) {
        const updated = []

        for (let index = 0; index < niriWindows.length; index++) {
            if (niriWindows[index].id !== windowId)
                updated.push(niriWindows[index])
        }

        niriWindows = updated

        if (focusedWindowId === windowId)
            focusedWindowId = -1

        const history = []

        for (let index = 0; index < windowHistory.length; index++) {
            if (windowHistory[index] !== windowId)
                history.push(windowHistory[index])
        }

        windowHistory = history
    }

    function handleNiriEvent(line) {
        const trimmed = line.trim()

        if (trimmed.length === 0)
            return

        let event = null

        try {
            event = JSON.parse(trimmed)
        } catch (error) {
            console.warn("Niri IPC parse error:", error, trimmed)
            return
        }

        if (event.WorkspacesChanged !== undefined) {
            niriWorkspaces = event.WorkspacesChanged.workspaces || []
        } else if (event.WorkspaceActivated !== undefined) {
            if (event.WorkspaceActivated.focused)
                focusedWorkspaceId = event.WorkspaceActivated.id
        } else if (event.WorkspaceActiveWindowChanged !== undefined) {
            const change = event.WorkspaceActiveWindowChanged
            const updated = []

            for (let index = 0; index < niriWorkspaces.length; index++) {
                const workspace = Object.assign({}, niriWorkspaces[index])

                if (workspace.id === change.workspace_id)
                    workspace.active_window_id = change.active_window_id

                updated.push(workspace)
            }

            niriWorkspaces = updated
        } else if (event.WindowsChanged !== undefined) {
            niriWindows = event.WindowsChanged.windows || []
        } else if (event.WindowOpenedOrChanged !== undefined) {
            replaceNiriWindow(event.WindowOpenedOrChanged.window)
        } else if (event.WindowClosed !== undefined) {
            removeNiriWindow(event.WindowClosed.id)
        } else if (event.WindowFocusChanged !== undefined) {
            focusedWindowId = event.WindowFocusChanged.id === null
                ? -1
                : event.WindowFocusChanged.id

            const updated = []

            for (let index = 0; index < niriWindows.length; index++) {
                const windowData = Object.assign({}, niriWindows[index])
                windowData.is_focused = windowData.id === focusedWindowId
                updated.push(windowData)
            }

            niriWindows = updated

            if (focusedWindowId >= 0)
                rememberWindow(focusedWindowId)
        }

        updateNiriDerivedState()
        syncWindowHistory()
    }

    Process {
        id: niriEventStream

        running: true
        command: ["niri", "msg", "--json", "event-stream"]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleNiriEvent(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"

            onRead: data => {
                const message = data.trim()

                if (message.length > 0)
                    console.warn("Niri IPC:", message)
            }
        }

        onExited: function(exitCode, exitStatus) {
            niriEventRestart.restart()
        }
    }

    Timer {
        id: niriEventRestart
        interval: 1000
        repeat: false

        onTriggered: {
            if (!niriEventStream.running)
                niriEventStream.running = true
        }
    }

    PanelWindow {
        id: desktop

        visible: true

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        focusable: true

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "precision-shell-desktop"

        color: "#F6F1E8"

        readonly property real designWidth: 1180
        readonly property real designHeight: 663
        readonly property real uiScale: Math.min(width / designWidth, height / designHeight)
        readonly property real panelScale: uiScale * 1.18

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

        property bool bluetoothEnabled: true
        property bool bluetoothBusy: false
        property bool bluetoothMenuOpen: false
        property string bluetoothConnectedName: ""
        property string bluetoothMessage: ""
        property string bluetoothError: ""
        property var bluetoothDevices: []

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
            restoreWidgetsOnFocus = false
            wifiMenuOpen = false
            bluetoothMenuOpen = false

            // The desktop lives on the Wayland Bottom layer. Normal Niri
            // windows cover it, and the widgets become visible again as soon
            // as the workspace is empty.
            viewState = 4
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
                    const normalized = text.replace(/\r/g, "").trim()
                    const lines = normalized.length > 0
                        ? normalized.split("\n")
                        : []
                    const radioState = lines.length > 0
                        ? lines[0].trim()
                        : ""
                    const connectionName = lines.length > 1
                        ? lines.slice(1).join("\n").trim()
                        : ""

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

                if (!wifiReader.running)
                    wifiReader.running = true

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

        Process {
            id: bluetoothReader
            command: [
                "bash",
                "-lc",
                "export LC_ALL=C; "
                + "powered=$(bluetoothctl show 2>/dev/null "
                + "| awk -F': ' '/Powered:/ {print $2; exit}'); "
                + "printf 'POWER:%s\n' \"$powered\"; "
                + "bluetoothctl devices Paired 2>/dev/null "
                + "| sed 's/^Device /PAIRED:/'; "
                + "bluetoothctl devices Connected 2>/dev/null "
                + "| sed 's/^Device /CONNECTED:/'"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    const normalized = text.replace(/\r/g, "").trim()
                    const lines = normalized.length > 0
                        ? normalized.split("\n")
                        : []
                    const devicesByAddress = {}
                    const connected = {}

                    for (let index = 0; index < lines.length; index++) {
                        const line = lines[index].trim()

                        if (line.indexOf("POWER:") === 0) {
                            desktop.bluetoothEnabled =
                                line.substring(6).trim() === "yes"
                            continue
                        }

                        if (line.indexOf("CONNECTED:") === 0) {
                            const payload = line.substring(10).trim()
                            const separator = payload.indexOf(" ")

                            if (separator > 0) {
                                const address = payload.substring(0, separator)
                                connected[address] = true
                            }

                            continue
                        }

                        if (line.indexOf("PAIRED:") === 0) {
                            const payload = line.substring(7).trim()
                            const separator = payload.indexOf(" ")

                            if (separator <= 0)
                                continue

                            const address = payload.substring(0, separator)
                            const name = payload.substring(separator + 1).trim()

                            devicesByAddress[address] = {
                                "address": address,
                                "name": name,
                                "connected": false
                            }
                        }
                    }

                    const devices = []
                    let connectedName = ""

                    for (const address in devicesByAddress) {
                        const device = devicesByAddress[address]
                        device.connected = connected[address] === true

                        if (device.connected && connectedName.length === 0)
                            connectedName = device.name

                        devices.push(device)
                    }

                    devices.sort(function(left, right) {
                        if (left.connected !== right.connected)
                            return left.connected ? -1 : 1

                        return left.name.localeCompare(right.name)
                    })

                    desktop.bluetoothDevices = devices
                    desktop.bluetoothConnectedName = connectedName

                    if (!desktop.bluetoothEnabled) {
                        desktop.bluetoothConnectedName = ""
                    }
                }
            }
        }

        Process {
            id: bluetoothPowerWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    desktop.bluetoothError = text.trim()

                    if (desktop.bluetoothError.length > 0)
                        console.warn("Bluetooth power:", desktop.bluetoothError)
                }
            }

            onExited: function(exitCode, exitStatus) {
                desktop.bluetoothBusy = false

                if (exitCode !== 0) {
                    desktop.bluetoothMessage =
                        desktop.bluetoothError.length > 0
                        ? desktop.bluetoothError
                        : "Unable to change Bluetooth state"
                } else {
                    desktop.bluetoothMessage = desktop.bluetoothEnabled
                        ? "Bluetooth enabled"
                        : "Bluetooth disabled"
                }

                bluetoothRefreshTimer.restart()
            }
        }

        Process {
            id: bluetoothDeviceWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    desktop.bluetoothError = text.trim()

                    if (desktop.bluetoothError.length > 0)
                        console.warn("Bluetooth device:", desktop.bluetoothError)
                }
            }

            onExited: function(exitCode, exitStatus) {
                desktop.bluetoothBusy = false

                if (exitCode !== 0) {
                    desktop.bluetoothMessage =
                        desktop.bluetoothError.length > 0
                        ? desktop.bluetoothError
                        : "Bluetooth action failed"
                } else {
                    desktop.bluetoothMessage = "Bluetooth updated"
                }

                bluetoothRefreshTimer.restart()
            }
        }

        Timer {
            id: bluetoothRefreshTimer
            interval: 1100
            repeat: false

            onTriggered: {
                if (!bluetoothReader.running)
                    bluetoothReader.running = true
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

            if (!bluetoothReader.running && !bluetoothBusy)
                bluetoothReader.running = true
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
            root.showOsd("volume", normalized)
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
            root.showOsd("brightness", normalized)

            if (percent === brightnessAppliedPercent
                    && !brightnessWriter.running) {
                brightnessWriteQueued = false
                return
            }

            brightnessWriteQueued = true
            flushBrightnessWrite()
        }

        function adjustVolume(delta) {
            queueVolume(volumeLevel + delta)
        }

        function adjustBrightness(delta) {
            queueBrightness(brightnessLevel + delta)
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

            if (wifiMenuOpen) {
                bluetoothMenuOpen = false

                if (wifiEnabled)
                    scanWifi()
            }
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
            wifiEnabled = wifiTargetEnabled
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

        function toggleBluetoothMenu() {
            bluetoothMenuOpen = !bluetoothMenuOpen

            if (bluetoothMenuOpen) {
                wifiMenuOpen = false

                if (!bluetoothReader.running)
                    bluetoothReader.running = true
            }
        }

        function toggleBluetooth() {
            if (bluetoothBusy)
                return

            const nextState = !bluetoothEnabled
            bluetoothBusy = true
            bluetoothEnabled = nextState
            bluetoothError = ""
            bluetoothMessage = nextState
                ? "Enabling Bluetooth..."
                : "Disabling Bluetooth..."

            if (!nextState) {
                bluetoothConnectedName = ""
                bluetoothDevices = []
            }

            bluetoothPowerWriter.exec([
                "env",
                "LC_ALL=C",
                "bluetoothctl",
                "power",
                nextState ? "on" : "off"
            ])
        }

        function toggleBluetoothDevice(address, connected) {
            if (bluetoothBusy || address.length === 0)
                return

            bluetoothBusy = true
            bluetoothError = ""
            bluetoothMessage = connected
                ? "Disconnecting..."
                : "Connecting..."

            bluetoothDeviceWriter.exec([
                "env",
                "LC_ALL=C",
                "bluetoothctl",
                connected ? "disconnect" : "connect",
                address
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
                else if (desktop.bluetoothMenuOpen)
                    desktop.bluetoothMenuOpen = false
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
                visible: false

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
                id: greetingBlock

                x: desktop.s(140)
                y: desktop.s(226)
                spacing: desktop.s(7)

                visible: opacity > 0
                opacity: root.workspaceHasWindows ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

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
                id: weatherBlock

                anchors {
                    right: parent.right
                    rightMargin: desktop.s(74)
                    top: parent.top
                    topMargin: desktop.s(76)
                }

                spacing: desktop.s(5.5)

                visible: opacity > 0
                opacity: root.workspaceHasWindows ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

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

                Text {
                    text: Qt.formatDateTime(desktop.now, "HH:mm")
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(21.5)
                    font.weight: Font.Light
                }
            }

            Rectangle {
                id: libraryPanel

                property bool opened: desktop.viewState === 4 && root.desktopWidgetsVisible && !root.workspaceHasWindows

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

                property bool opened: (desktop.viewState === 2 || desktop.viewState === 4) && root.desktopWidgetsVisible && !root.workspaceHasWindows

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(97)
                }

                width: desktop.p(438)
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
                        font.pixelSize: desktop.p(9.8)
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

                        text: "SUPER  SPACE"
                        color: "#A89F96"
                        font.family: "Inter"
                        font.pixelSize: desktop.p(6.1)
                        font.letterSpacing: desktop.p(0.35)
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

                    spacing: desktop.p(31)

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
                                    font.pixelSize: desktop.p(8.8)
                                    font.weight: Font.Normal
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.subtitle
                                    color: desktop.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(7.2)
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

                property bool opened: (desktop.viewState === 3 || desktop.viewState === 4) && root.desktopWidgetsVisible && !root.workspaceHasWindows

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
                            font.pixelSize: desktop.p(8.2)
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
                            font.pixelSize: desktop.p(7.2)
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

                    Item {
                        width: parent.width
                        height: desktop.p(15)

                        PremiumIcon {
                            id: bluetoothRowIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/bluetooth.svg")
                            size: desktop.p(12)
                            iconOpacity: desktop.bluetoothEnabled ? 0.88 : 0.40
                        }

                        Text {
                            anchors {
                                left: bluetoothRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(62)
                            text: "Bluetooth"
                            color: desktop.bluetoothEnabled
                                ? desktop.graphite
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.2)
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: bluetoothToggle

                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(20)
                            height: desktop.p(11)
                            radius: height / 2
                            color: desktop.bluetoothEnabled
                                ? desktop.softInk
                                : "#B9B1A8"
                            opacity: desktop.bluetoothBusy ? 0.58 : 1

                            Rectangle {
                                width: desktop.p(7)
                                height: desktop.p(7)
                                radius: width / 2
                                color: desktop.warmWhite
                                anchors.verticalCenter: parent.verticalCenter

                                x: desktop.bluetoothEnabled
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
                                right: bluetoothToggle.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(38)
                            text: desktop.bluetoothBusy
                                ? "..."
                                : (!desktop.bluetoothEnabled
                                    ? "Off"
                                    : (desktop.bluetoothConnectedName.length > 0
                                        ? desktop.bluetoothConnectedName
                                        : "On"))
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.2)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                right: bluetoothToggle.left
                                rightMargin: desktop.p(5)
                            }

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: desktop.toggleBluetoothMenu()
                        }

                        MouseArea {
                            anchors.fill: bluetoothToggle
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !desktop.bluetoothBusy
                            onClicked: desktop.toggleBluetooth()
                        }
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(15)

                        PremiumIcon {
                            id: dndRowIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/moon.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.88
                        }

                        Text {
                            anchors {
                                left: dndRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(72)
                            text: "Do Not Disturb"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.2)
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(20)
                            height: desktop.p(11)
                            radius: height / 2
                            color: "#B9B1A8"

                            Rectangle {
                                width: desktop.p(7)
                                height: desktop.p(7)
                                radius: width / 2
                                color: desktop.warmWhite
                                anchors.verticalCenter: parent.verticalCenter
                                x: desktop.p(2)
                            }
                        }

                        Text {
                            anchors {
                                right: parent.right
                                rightMargin: desktop.p(27)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(28)
                            text: "Off"
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.2)
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
                            id: batteryRowIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/battery.svg")
                            size: desktop.p(12)
                            iconOpacity: 0.88
                        }

                        Text {
                            anchors {
                                left: batteryRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            text: "Battery"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.2)
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: desktop.batteryPercent + "%"
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.2)
                            font.weight: Font.Normal
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

            MouseArea {
                id: detailMenuDismissLayer

                anchors.fill: parent
                z: 19

                visible: desktop.wifiMenuOpen
                    || desktop.bluetoothMenuOpen
                enabled: visible

                acceptedButtons: Qt.AllButtons
                cursorShape: Qt.ArrowCursor
                preventStealing: true
                propagateComposedEvents: false

                onPressed: function(mouse) {
                    mouse.accepted = true
                }

                onClicked: function(mouse) {
                    desktop.wifiMenuOpen = false
                    desktop.bluetoothMenuOpen = false
                    mouse.accepted = true
                }
            }

            Rectangle {
                id: bluetoothMenu

                anchors {
                    right: settingsPanel.left
                    rightMargin: desktop.p(9)
                    bottom: settingsPanel.bottom
                }

                width: desktop.p(178)
                height: desktop.p(170)
                radius: desktop.p(10)
                z: 21

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.65))
                border.color: desktop.panelBorder

                visible: opacity > 0
                enabled: desktop.bluetoothMenuOpen
                opacity: desktop.bluetoothMenuOpen ? 1 : 0
                scale: desktop.bluetoothMenuOpen ? 1 : 0.985

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

                            text: "Bluetooth"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: desktop.p(9.0)
                            font.weight: Font.Medium
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: "Refresh"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.1)

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -desktop.p(5)
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !desktop.bluetoothBusy
                                onClicked: {
                                    if (!bluetoothReader.running)
                                        bluetoothReader.running = true
                                }
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
                            id: activeBluetoothIcon

                            anchors {
                                left: parent.left
                                verticalCenter: parent.verticalCenter
                            }

                            source: Qt.resolvedUrl("icons/bluetooth.svg")
                            size: desktop.p(11)
                            iconOpacity: desktop.bluetoothEnabled ? 0.90 : 0.44
                        }

                        Text {
                            anchors {
                                left: activeBluetoothIcon.right
                                leftMargin: desktop.p(7)
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: !desktop.bluetoothEnabled
                                ? "Bluetooth is off"
                                : (desktop.bluetoothConnectedName.length > 0
                                    ? desktop.bluetoothConnectedName
                                    : "No device connected")
                            color: desktop.bluetoothConnectedName.length > 0
                                ? desktop.graphite
                                : desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.9)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: desktop.bluetoothEnabled
                                ? Qt.ArrowCursor
                                : Qt.PointingHandCursor
                            enabled: !desktop.bluetoothEnabled
                                && !desktop.bluetoothBusy
                            onClicked: desktop.toggleBluetooth()
                        }
                    }

                    ListView {
                        id: bluetoothDeviceList

                        width: parent.width
                        height: desktop.p(88)
                        clip: true
                        spacing: desktop.p(1)
                        model: desktop.bluetoothDevices
                        interactive: contentHeight > height
                        visible: desktop.bluetoothEnabled

                        delegate: Item {
                            required property var modelData

                            width: bluetoothDeviceList.width
                            height: desktop.p(22)

                            Rectangle {
                                anchors.fill: parent
                                radius: desktop.p(5)
                                color: bluetoothDeviceMouse.containsMouse
                                    ? "#3AD8CCBC"
                                    : "transparent"
                            }

                            PremiumIcon {
                                id: bluetoothDeviceIcon

                                anchors {
                                    left: parent.left
                                    verticalCenter: parent.verticalCenter
                                }

                                source: Qt.resolvedUrl("icons/bluetooth.svg")
                                size: desktop.p(10)
                                iconOpacity: modelData.connected ? 0.95 : 0.68
                            }

                            Column {
                                anchors {
                                    left: bluetoothDeviceIcon.right
                                    leftMargin: desktop.p(6)
                                    right: bluetoothDeviceState.left
                                    rightMargin: desktop.p(7)
                                    verticalCenter: parent.verticalCenter
                                }

                                spacing: desktop.p(0.5)

                                Text {
                                    width: parent.width
                                    text: modelData.name
                                    color: modelData.connected
                                        ? desktop.graphite
                                        : desktop.softInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(7.5)
                                    font.weight: modelData.connected
                                        ? Font.Medium
                                        : Font.Normal
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: modelData.connected
                                        ? "Connected"
                                        : "Paired"
                                    color: desktop.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(6.1)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: bluetoothDeviceState

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                text: modelData.connected ? "Disconnect" : "Connect"
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.1)
                            }

                            MouseArea {
                                id: bluetoothDeviceMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: !desktop.bluetoothBusy
                                onClicked: desktop.toggleBluetoothDevice(
                                    modelData.address,
                                    modelData.connected
                                )
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        height: desktop.p(12)
                        visible: desktop.bluetoothMessage.length > 0
                        text: desktop.bluetoothMessage
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(6.6)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
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
                            font.pixelSize: desktop.p(9.0)
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
                            font.pixelSize: desktop.p(7.1)

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
                            font.pixelSize: desktop.p(7.9)
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
                                    font.pixelSize: desktop.p(7.5)
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
                                    font.pixelSize: desktop.p(6.1)
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
                        font.pixelSize: desktop.p(6.6)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }


    PanelWindow {
        id: dashboardWindow

        visible: root.dashboardOpen

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        focusable: true

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        WlrLayershell.namespace: "precision-shell-dashboard"

        color: "#3017130F"

        function filteredItems() {
            const query = dashboardSearch.text.trim().toLowerCase()

            if (query.length === 0)
                return desktop.appItems

            return desktop.appItems.filter(function(item) {
                return item.title.toLowerCase().indexOf(query) !== -1
                    || item.subtitle.toLowerCase().indexOf(query) !== -1
                    || item.lookup.toLowerCase().indexOf(query) !== -1
            })
        }

        function launchItem(item) {
            const desktopEntry = DesktopEntries.heuristicLookup(item.lookup)

            if (desktopEntry !== null) {
                desktopEntry.execute()
            } else {
                Quickshell.execDetached({
                    command: item.fallback
                })
            }

            root.closeDashboard()
        }

        Shortcut {
            enabled: root.dashboardOpen
            context: Qt.ApplicationShortcut
            sequence: "Escape"
            onActivated: root.closeDashboard()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeDashboard()
        }

        Rectangle {
            id: dashboardLibrary

            anchors {
                left: parent.left
                leftMargin: desktop.p(26)
                bottom: parent.bottom
                bottomMargin: desktop.p(29)
            }

            width: desktop.p(146)
            height: desktop.p(160)
            radius: desktop.p(10)

            color: "#F5FBF9F5"
            border.width: Math.max(1, desktop.p(0.65))
            border.color: "#72CFC4B6"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
                onPressed: function(mouse) {
                    mouse.accepted = true
                }
            }

            Column {
                anchors {
                    fill: parent
                    margins: desktop.p(14)
                }

                spacing: desktop.p(11)

                Text {
                    text: "Apps"
                    color: desktop.graphite
                    font.family: "Inter"
                    font.pixelSize: desktop.p(9.0)
                    font.weight: Font.Medium
                }

                Repeater {
                    model: ["Recent", "Documents", "Downloads"]

                    delegate: Text {
                        required property string modelData

                        text: modelData
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.9)
                    }
                }

                Item {
                    width: 1
                    height: desktop.p(4)
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(1, desktop.p(0.65))
                    color: "#52D8CCBC"
                }

                Item {
                    width: parent.width
                    height: desktop.p(14)

                    Text {
                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        text: "Show All"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.5)
                    }

                    PremiumIcon {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/expand.svg")
                        size: desktop.p(9)
                        iconOpacity: 0.72
                    }
                }
            }
        }

        Rectangle {
            id: dashboardPalette

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: desktop.p(97)
            }

            width: desktop.p(438)
            height: desktop.p(123)
            radius: desktop.p(10)

            color: "#F5FBF9F5"
            border.width: Math.max(1, desktop.p(0.7))
            border.color: "#72CFC4B6"
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
                onPressed: function(mouse) {
                    mouse.accepted = true
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
                    id: dashboardSearch

                    anchors {
                        left: parent.left
                        leftMargin: desktop.p(38)
                        right: parent.right
                        rightMargin: desktop.p(72)
                        verticalCenter: parent.verticalCenter
                    }

                    height: desktop.p(25)
                    color: desktop.graphite
                    selectedTextColor: desktop.graphite
                    selectionColor: desktop.sand
                    placeholderText: "Search or type a command..."
                    placeholderTextColor: "#A19990"
                    font.family: "Inter"
                    font.pixelSize: desktop.p(9.8)
                    selectByMouse: true
                    leftPadding: desktop.p(6)
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    background: Item {}

                    Keys.onReturnPressed: {
                        const matches = dashboardWindow.filteredItems()

                        if (matches.length > 0)
                            dashboardWindow.launchItem(matches[0])
                    }

                    Keys.onEnterPressed: {
                        const matches = dashboardWindow.filteredItems()

                        if (matches.length > 0)
                            dashboardWindow.launchItem(matches[0])
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: desktop.p(17)
                        verticalCenter: parent.verticalCenter
                    }

                    text: "SUPER  D"
                    color: "#A89F96"
                    font.family: "Inter"
                    font.pixelSize: desktop.p(6.1)
                    font.letterSpacing: desktop.p(0.35)
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

            Row {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(12)
                }

                spacing: desktop.p(31)

                Repeater {
                    model: dashboardWindow.filteredItems()

                    delegate: Item {
                        id: dashboardTile

                        required property var modelData

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
                            opacity: dashboardTileMouse.containsMouse ? 0.48 : 0
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: desktop.p(3)

                            PremiumIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Qt.resolvedUrl(
                                    "icons/" + modelData.icon
                                )
                                size: desktop.p(20)
                                iconOpacity: dashboardTileMouse.containsMouse
                                    ? 1.0
                                    : 0.88
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.title
                                color: dashboardTileMouse.containsMouse
                                    ? desktop.graphite
                                    : desktop.softInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(8.8)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.subtitle
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(7.2)
                            }
                        }

                        MouseArea {
                            id: dashboardTileMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: dashboardWindow.launchItem(modelData)
                        }
                    }
                }
            }
        }

        Rectangle {
            id: dashboardSettings

            anchors {
                right: parent.right
                rightMargin: desktop.p(26)
                bottom: parent.bottom
                bottomMargin: desktop.p(29)
            }

            width: desktop.p(160)
            height: desktop.p(190)
            radius: desktop.p(10)

            color: "#F5FBF9F5"
            border.width: Math.max(1, desktop.p(0.65))
            border.color: "#72CFC4B6"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false
                onPressed: function(mouse) {
                    mouse.accepted = true
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
                        id: dashboardWifiIcon

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
                            left: dashboardWifiIcon.right
                            leftMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        text: "Wi-Fi"
                        color: desktop.wifiEnabled
                            ? desktop.graphite
                            : desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8.2)
                    }

                    Text {
                        anchors {
                            right: dashboardWifiSwitch.left
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
                        font.pixelSize: desktop.p(7.2)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: dashboardWifiSwitch

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

                        Rectangle {
                            width: desktop.p(7)
                            height: desktop.p(7)
                            radius: width / 2
                            color: desktop.warmWhite
                            anchors.verticalCenter: parent.verticalCenter
                            x: desktop.wifiEnabled
                                ? parent.width - width - desktop.p(2)
                                : desktop.p(2)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !desktop.wifiBusy
                            onClicked: desktop.toggleWifi()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: desktop.p(15)

                    PremiumIcon {
                        id: dashboardBluetoothIcon

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/bluetooth.svg")
                        size: desktop.p(12)
                        iconOpacity: desktop.bluetoothEnabled ? 0.88 : 0.40
                    }

                    Text {
                        anchors {
                            left: dashboardBluetoothIcon.right
                            leftMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        text: "Bluetooth"
                        color: desktop.bluetoothEnabled
                            ? desktop.graphite
                            : desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8.2)
                    }

                    Text {
                        anchors {
                            right: dashboardBluetoothSwitch.left
                            rightMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        width: desktop.p(38)
                        text: desktop.bluetoothBusy
                            ? "..."
                            : (!desktop.bluetoothEnabled
                                ? "Off"
                                : (desktop.bluetoothConnectedName.length > 0
                                    ? desktop.bluetoothConnectedName
                                    : "On"))
                        horizontalAlignment: Text.AlignRight
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.2)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: dashboardBluetoothSwitch

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        width: desktop.p(20)
                        height: desktop.p(11)
                        radius: height / 2
                        color: desktop.bluetoothEnabled
                            ? desktop.softInk
                            : "#B9B1A8"

                        Rectangle {
                            width: desktop.p(7)
                            height: desktop.p(7)
                            radius: width / 2
                            color: desktop.warmWhite
                            anchors.verticalCenter: parent.verticalCenter
                            x: desktop.bluetoothEnabled
                                ? parent.width - width - desktop.p(2)
                                : desktop.p(2)
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !desktop.bluetoothBusy
                            onClicked: desktop.toggleBluetooth()
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: desktop.p(15)

                    PremiumIcon {
                        id: dashboardDndIcon

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/moon.svg")
                        size: desktop.p(12)
                        iconOpacity: 0.88
                    }

                    Text {
                        anchors {
                            left: dashboardDndIcon.right
                            leftMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        width: desktop.p(72)
                        text: "Do Not Disturb"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8.2)
                        elide: Text.ElideRight
                    }

                    Rectangle {
                        id: dashboardDndSwitch

                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        width: desktop.p(20)
                        height: desktop.p(11)
                        radius: height / 2
                        color: "#B9B1A8"

                        Rectangle {
                            width: desktop.p(7)
                            height: desktop.p(7)
                            radius: width / 2
                            color: desktop.warmWhite
                            anchors.verticalCenter: parent.verticalCenter
                            x: desktop.p(2)
                        }
                    }

                    Text {
                        anchors {
                            right: dashboardDndSwitch.left
                            rightMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        width: desktop.p(28)
                        text: "Off"
                        horizontalAlignment: Text.AlignRight
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.2)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Math.max(1, desktop.p(0.65))
                    color: "#52D8CCBC"
                }

                Item {
                    width: parent.width
                    height: desktop.p(16)

                    PremiumIcon {
                        id: dashboardBatteryIcon

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/battery.svg")
                        size: desktop.p(12)
                        iconOpacity: 0.82
                    }

                    Text {
                        anchors {
                            left: dashboardBatteryIcon.right
                            leftMargin: desktop.p(7)
                            verticalCenter: parent.verticalCenter
                        }

                        text: "Battery"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8.1)
                    }

                    Text {
                        anchors {
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                        }

                        text: desktop.batteryPercent + "%"
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(7.2)
                        font.weight: Font.Normal
                    }
                }

                Item {
                    width: parent.width
                    height: desktop.p(18)

                    PremiumIcon {
                        id: dashboardVolumeLeft

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/volume.svg")
                        size: desktop.p(10)
                        iconOpacity: 0.74
                    }

                    Slider {
                        anchors {
                            left: dashboardVolumeLeft.right
                            leftMargin: desktop.p(7)
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }

                        from: 0
                        to: 1
                        value: desktop.volumeLevel
                        live: true
                        padding: 0

                        onMoved: desktop.queueVolume(value)

                        background: Rectangle {
                            x: parent.leftPadding
                            y: parent.topPadding
                                + parent.availableHeight / 2
                                - height / 2
                            width: parent.availableWidth
                            height: desktop.p(1.6)
                            radius: height / 2
                            color: "#CBC1B5"

                            Rectangle {
                                width: parent.parent.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }
                        }

                        handle: Rectangle {
                            x: parent.leftPadding
                                + parent.visualPosition
                                * (parent.availableWidth - width)
                            y: parent.topPadding
                                + parent.availableHeight / 2
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
                    height: desktop.p(18)

                    PremiumIcon {
                        id: dashboardBrightnessLeft

                        anchors {
                            left: parent.left
                            verticalCenter: parent.verticalCenter
                        }

                        source: Qt.resolvedUrl("icons/brightness.svg")
                        size: desktop.p(10)
                        iconOpacity: 0.74
                    }

                    Slider {
                        anchors {
                            left: dashboardBrightnessLeft.right
                            leftMargin: desktop.p(7)
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                        }

                        from: 0.01
                        to: 1
                        value: desktop.brightnessLevel
                        live: true
                        padding: 0

                        onMoved: desktop.queueBrightness(value)

                        background: Rectangle {
                            x: parent.leftPadding
                            y: parent.topPadding
                                + parent.availableHeight / 2
                                - height / 2
                            width: parent.availableWidth
                            height: desktop.p(1.6)
                            radius: height / 2
                            color: "#CBC1B5"

                            Rectangle {
                                width: parent.parent.visualPosition * parent.width
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }
                        }

                        handle: Rectangle {
                            x: parent.leftPadding
                                + parent.visualPosition
                                * (parent.availableWidth - width)
                            y: parent.topPadding
                                + parent.availableHeight / 2
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
    }

    PanelWindow {
        id: launcherWindow

        visible: root.launcherOpen

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
        WlrLayershell.namespace: "precision-shell-launcher"

        color: "transparent"

        function filteredItems() {
            const query = launcherSearch.text.trim().toLowerCase()

            if (query.length === 0)
                return desktop.appItems

            return desktop.appItems.filter(function(item) {
                return item.title.toLowerCase().indexOf(query) !== -1
                    || item.subtitle.toLowerCase().indexOf(query) !== -1
                    || item.lookup.toLowerCase().indexOf(query) !== -1
            })
        }

        function launchItem(item) {
            const desktopEntry = DesktopEntries.heuristicLookup(item.lookup)

            if (desktopEntry !== null) {
                desktopEntry.execute()
            } else {
                Quickshell.execDetached({
                    command: item.fallback
                })
            }

            root.closeLauncher()
        }

        Shortcut {
            enabled: root.launcherOpen
            context: Qt.ApplicationShortcut
            sequence: "Escape"
            onActivated: root.closeLauncher()
        }

        Rectangle {
            anchors.fill: parent
            color: "#52000000"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeLauncher()
        }

        Rectangle {
            id: launcherCard

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: desktop.p(97)
            }

            width: desktop.p(438)
            height: desktop.p(123)
            radius: desktop.p(10)

            color: desktop.panelSurface
            border.width: Math.max(1, desktop.p(0.7))
            border.color: desktop.panelBorder
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.AllButtons
                propagateComposedEvents: false

                onPressed: function(mouse) {
                    mouse.accepted = true
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
                    id: launcherSearch

                    anchors {
                        left: parent.left
                        leftMargin: desktop.p(38)
                        right: parent.right
                        rightMargin: desktop.p(72)
                        verticalCenter: parent.verticalCenter
                    }

                    height: desktop.p(25)
                    color: desktop.graphite
                    selectedTextColor: desktop.graphite
                    selectionColor: desktop.sand
                    placeholderText: "Search or type a command..."
                    placeholderTextColor: "#A19990"
                    font.family: "Inter"
                    font.pixelSize: desktop.p(9.8)
                    selectByMouse: true
                    leftPadding: desktop.p(6)
                    rightPadding: 0
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    background: Item {}

                    Keys.onReturnPressed: {
                        const matches = launcherWindow.filteredItems()

                        if (matches.length > 0)
                            launcherWindow.launchItem(matches[0])
                    }

                    Keys.onEnterPressed: {
                        const matches = launcherWindow.filteredItems()

                        if (matches.length > 0)
                            launcherWindow.launchItem(matches[0])
                    }
                }

                Text {
                    anchors {
                        right: parent.right
                        rightMargin: desktop.p(17)
                        verticalCenter: parent.verticalCenter
                    }

                    text: "SUPER  SPACE"
                    color: "#A89F96"
                    font.family: "Inter"
                    font.pixelSize: desktop.p(6.1)
                    font.letterSpacing: desktop.p(0.35)
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

                visible: launcherWindow.filteredItems().length === 0
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

                spacing: desktop.p(31)

                Repeater {
                    model: launcherWindow.filteredItems()

                    delegate: Item {
                        id: launcherTile

                        required property var modelData

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
                            opacity: launcherTileMouse.containsMouse ? 0.48 : 0

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
                                source: Qt.resolvedUrl(
                                    "icons/" + modelData.icon
                                )
                                size: desktop.p(20)
                                iconOpacity: launcherTileMouse.containsMouse
                                    ? 1.0
                                    : 0.88
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.title
                                color: launcherTileMouse.containsMouse
                                    ? desktop.graphite
                                    : desktop.softInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(8.8)
                                font.weight: Font.Normal
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.subtitle
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(7.2)
                            }
                        }

                        MouseArea {
                            id: launcherTileMouse

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcherWindow.launchItem(modelData)
                        }
                    }
                }
            }
        }
    }


    PanelWindow {
        id: precisionSwitcherWindow

        visible: root.switcherOpen

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
        WlrLayershell.namespace: "precision-shell-window-switcher"

        color: "transparent"

        Rectangle {
            anchors.fill: parent
            color: "#78000000"
        }

        Item {
            id: switcherKeyCatcher

            anchors.fill: parent
            focus: root.switcherOpen

            Keys.onPressed: function(event) {
                if (event.key === Qt.Key_Tab) {
                    root.stepSwitcher(
                        event.modifiers & Qt.ShiftModifier ? -1 : 1
                    )
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Backtab) {
                    root.stepSwitcher(-1)
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Escape) {
                    root.cancelSwitcher()
                    event.accepted = true
                    return
                }

                if (event.key === Qt.Key_Return
                        || event.key === Qt.Key_Enter) {
                    root.confirmSwitcher()
                    event.accepted = true
                }
            }

            Keys.onReleased: function(event) {
                if (event.key === Qt.Key_Alt) {
                    root.confirmSwitcher()
                    event.accepted = true
                }
            }
        }

        Rectangle {
            id: switcherCard

            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.max(desktop.p(72), parent.height * 0.16)

            width: Math.min(
                parent.width - desktop.p(44),
                desktop.p(
                    62
                    + Math.max(
                        2,
                        Math.min(5, root.switcherItems.length)
                    ) * 151
                )
            )
            height: desktop.p(162)
            radius: desktop.p(18)

            color: "#FAF7F2FA"
            border.width: Math.max(1, desktop.p(0.8))
            border.color: "#A0CFC4B6"

            Text {
                anchors {
                    left: parent.left
                    leftMargin: desktop.p(20)
                    top: parent.top
                    topMargin: desktop.p(15)
                }

                text: "Open windows"
                color: desktop.graphite
                font.family: "Inter"
                font.pixelSize: desktop.p(9.2)
                font.weight: Font.Normal
                font.letterSpacing: desktop.p(0.08)
            }

            Text {
                anchors {
                    right: parent.right
                    rightMargin: desktop.p(20)
                    top: parent.top
                    topMargin: desktop.p(16)
                }

                text: "Release Alt to switch"
                color: desktop.mutedInk
                font.family: "Inter"
                font.pixelSize: desktop.p(7.2)
                font.weight: Font.Normal
            }

            Row {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(20)
                }

                spacing: desktop.p(9)

                Repeater {
                    model: root.switcherDisplayItems()

                    delegate: Rectangle {
                        id: switcherTile

                        required property var modelData

                        width: desktop.p(142)
                        height: desktop.p(103)
                        radius: desktop.p(12)

                        color: modelData.selected
                            ? "#F2E7D9"
                            : "#F8F4EE"

                        border.width: modelData.selected
                            ? Math.max(1, desktop.p(1.1))
                            : Math.max(1, desktop.p(0.65))

                        border.color: modelData.selected
                            ? "#B3A391"
                            : "#58D8CCBC"

                        Column {
                            anchors {
                                fill: parent
                                margins: desktop.p(11)
                            }

                            spacing: desktop.p(7)

                            Row {
                                width: parent.width
                                spacing: desktop.p(8)

                                Rectangle {
                                    width: desktop.p(36)
                                    height: desktop.p(36)
                                    radius: desktop.p(9)
                                    color: modelData.selected
                                        ? "#DDFBF9F5"
                                        : "#B8FBF9F5"

                                    PremiumIcon {
                                        anchors.centerIn: parent
                                        source: Qt.resolvedUrl(
                                            "icons/" + modelData.icon
                                        )
                                        size: desktop.p(20)
                                        iconOpacity: 0.92
                                    }
                                }

                                Column {
                                    width: parent.width - desktop.p(44)
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: desktop.p(2)

                                    Text {
                                        width: parent.width
                                        text: modelData.appName
                                        color: desktop.graphite
                                        font.family: "Inter"
                                        font.pixelSize: desktop.p(10)
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width
                                        text: "Workspace "
                                            + modelData.workspaceId
                                        color: desktop.mutedInk
                                        font.family: "Inter"
                                        font.pixelSize: desktop.p(7)
                                        font.weight: Font.Normal
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Text {
                                width: parent.width
                                text: modelData.title
                                color: desktop.softInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(8)
                                font.weight: Font.Normal
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: desktop.p(6)
                            }

                            visible: modelData.selected
                            width: desktop.p(34)
                            height: desktop.p(2)
                            radius: height / 2
                            color: desktop.softInk
                            opacity: 0.72
                        }
                    }
                }
            }
        }
    }


    PanelWindow {
        id: osdWindow

        visible: root.osdWindowActive

        anchors {
            top: true
            left: true
            right: true
        }

        implicitHeight: desktop.s(92)
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "precision-shell-osd"

        color: "transparent"

        Rectangle {
            id: osdCard

            anchors.horizontalCenter: parent.horizontalCenter

            y: root.osdShown ? desktop.s(40) : desktop.s(33)
            width: desktop.p(178)
            height: desktop.p(36)
            radius: desktop.p(10)

            color: "#F4FBF9F5"
            border.width: Math.max(1, desktop.p(0.7))
            border.color: "#70CFC4B6"
            opacity: root.osdShown ? 1 : 0

            Behavior on y {
                NumberAnimation {
                    duration: 145
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 145
                    easing.type: Easing.OutCubic
                }
            }

            PremiumIcon {
                id: osdIcon

                anchors {
                    left: parent.left
                    leftMargin: desktop.p(12)
                    verticalCenter: parent.verticalCenter
                }

                source: Qt.resolvedUrl(
                    root.osdKind === "brightness"
                        ? "icons/brightness.svg"
                        : "icons/volume.svg"
                )
                size: desktop.p(14)
                iconOpacity: 0.90
            }

            Column {
                anchors {
                    left: osdIcon.right
                    leftMargin: desktop.p(10)
                    right: osdPercent.left
                    rightMargin: desktop.p(10)
                    verticalCenter: parent.verticalCenter
                }

                spacing: desktop.p(4)

                Text {
                    text: root.osdKind === "brightness"
                        ? "Brightness"
                        : "Volume"
                    color: desktop.graphite
                    font.family: "Inter"
                    font.pixelSize: desktop.p(7.4)
                    font.weight: Font.Normal
                }

                Rectangle {
                    width: parent.width
                    height: desktop.p(1.9)
                    radius: height / 2
                    color: "#C9C0B6"

                    Rectangle {
                        width: parent.width * root.osdLevel
                        height: parent.height
                        radius: parent.radius
                        color: desktop.softInk
                    }
                }
            }

            Text {
                id: osdPercent

                anchors {
                    right: parent.right
                    rightMargin: desktop.p(12)
                    verticalCenter: parent.verticalCenter
                }

                width: desktop.p(27)
                text: Math.round(root.osdLevel * 100) + "%"
                horizontalAlignment: Text.AlignRight
                color: desktop.graphite
                font.family: "Inter"
                font.pixelSize: desktop.p(8.1)
                font.weight: Font.Normal
            }
        }
    }


}
