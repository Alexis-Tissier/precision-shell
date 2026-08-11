import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls
import QtQuick.Effects

ShellRoot {
    id: root

    property bool launcherOpen: false
    property bool launcherAllMode: false
    property bool dashboardOpen: false
    property bool dashboardWifiMenuOpen: false
    property bool dashboardBluetoothMenuOpen: false
    property bool desktopWidgetsVisible: true
    property bool settingsOpen: false
    property real panelOpacity: 0.96
    property real overlayDarkness: 0.16
    property int defaultViewState: 4

    function openSettings(section) {
        if (root.launcherOpen)
            root.closeLauncher()
        if (root.dashboardOpen)
            root.closeDashboard()
        if (root.switcherOpen)
            root.closeSwitcher()

        settingsOpen = true
        if (section !== undefined)
            precisionSettings.selectedSection = Math.max(0, Math.min(3, section))
    }

    function closeSettings() {
        settingsOpen = false
        precisionSettings.clearConfirmation()
    }

    function toggleSettings() {
        if (settingsOpen)
            closeSettings()
        else
            openSettings(0)
    }

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

function openLauncher(showAll) {
    settingsOpen = false
    dashboardOpen = false
    launcherAllMode = showAll === true
    launcherOpen = true
    launcherSearch.text = ""

    if (launcherAllMode
            && !desktop.allAppsLoaded
            && !allAppsReader.running) {
        allAppsReader.running = true
    }

    Qt.callLater(function() {
        launcherSearch.forceActiveFocus()
    })
}

function openAllApplications() {
    openLauncher(true)
}

function closeLauncher() {
    launcherOpen = false
    launcherSearch.text = ""
    launcherSearch.focus = false
    launcherAllMode = false
}

function toggleLauncher() {
    if (launcherOpen)
        closeLauncher()
    else
        openLauncher(false)
}

    function openDashboard() {
        // Lot 1: reset detail menus
        root.dashboardWifiMenuOpen = false
        root.dashboardBluetoothMenuOpen = false
    settingsOpen = false
    if (root.launcherOpen) {
        root.closeLauncher()
    }
        launcherOpen = false
        dashboardOpen = true
        dashboardSearch.text = ""
        // Lot 1: Super+D opens ready to type
        Qt.callLater(function() {
            dashboardSearch.forceActiveFocus()
        })
    }

    function closeDashboard() {
        root.dashboardWifiMenuOpen = false
        root.dashboardBluetoothMenuOpen = false
        dashboardOpen = false
        dashboardSearch.text = ""
        dashboardSearch.focus = false
    }

    function toggleDashboard() {
    if (root.launcherOpen) {
        root.closeLauncher()
    }
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

    function appIconSource(iconName, fallbackIcon) {
        const icon = (iconName || "").trim()
        const fallback = (fallbackIcon || "apps.svg").trim()

        if (icon.length > 0) {
            if (icon.indexOf("file:") === 0)
                return encodeURI(icon)

            if (icon.indexOf("/") === 0)
                return encodeURI("file://" + icon)

            const themedIcon = Quickshell.iconPath(icon, true)

            if (themedIcon && themedIcon.length > 0)
                return themedIcon

            if (/\.(svg|png|jpe?g|webp|xpm)$/i.test(icon))
                return Qt.resolvedUrl("icons/" + icon)
        }

        return Qt.resolvedUrl("icons/" + fallback)
    }

    function desktopEntryIcon(appId, title) {
        let entry = null

        if (appId && appId.length > 0)
            entry = DesktopEntries.heuristicLookup(appId)

        if (entry === null && title && title.length > 0)
            entry = DesktopEntries.heuristicLookup(title)

        return entry !== null && entry.icon
            ? entry.icon
            : ""
    }

    function applicationItemDesktopIcon(item) {
        if (!item)
            return ""

        const candidates = []

        function addCandidate(value) {
            const candidate = String(value || "").trim()

            if (candidate.length > 0
                    && candidates.indexOf(candidate) === -1)
                candidates.push(candidate)
        }

        addCandidate(item.desktopId)

        if (item.desktopFile) {
            const path = String(item.desktopFile)
            const slash = path.lastIndexOf("/")
            const fileName = slash >= 0
                ? path.substring(slash + 1)
                : path

            addCandidate(fileName)

            if (/\.desktop$/i.test(fileName))
                addCandidate(fileName.replace(/\.desktop$/i, ""))
        }

        addCandidate(item.lookup)
        addCandidate(item.title)

        for (let index = 0; index < candidates.length; index++) {
            const entry = DesktopEntries.heuristicLookup(candidates[index])

            if (entry !== null
                    && entry.icon
                    && String(entry.icon).trim().length > 0)
                return String(entry.icon).trim()
        }

        return ""
    }

    function enrichApplicationIcons(items) {
        const enriched = []

        for (let index = 0; index < items.length; index++) {
            const item = Object.assign({}, items[index])
            const listedIcon = String(item.icon || "").trim()
            const resolvedIcon = applicationItemDesktopIcon(item)

            if (!item.fallbackIcon
                    || String(item.fallbackIcon).trim().length === 0) {
                item.fallbackIcon = listedIcon.length > 0
                    ? listedIcon
                    : "apps.svg"
            }

            if (resolvedIcon.length > 0)
                item.icon = resolvedIcon

            enriched.push(item)
        }

        return enriched
    }

    function switcherFallbackIcon(appId) {
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
                "icon": desktopEntryIcon(
                    windowData.app_id || "",
                    windowData.title || ""
                ),
                "fallbackIcon": switcherFallbackIcon(
                    windowData.app_id || ""
                ),
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
    settingsOpen = false
    if (root.launcherOpen) {
        root.closeLauncher()
    }
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

        interval: 30000
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


        function confirm(): void {
            root.confirmSwitcher()
        }
}

    IpcHandler {
        target: "settingsPage"

        function open(): void { root.openSettings(0) }
        function appearance(): void { root.openSettings(0) }
        function system(): void { root.openSettings(1) }
        function shortcuts(): void { root.openSettings(2) }
        function session(): void { root.openSettings(3) }
        function close(): void { root.closeSettings() }
        function toggle(): void { root.toggleSettings() }
        function isOpen(): bool { return root.settingsOpen }
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
        target: "desktopView"

        function hide(): void { desktop.applyViewState(1) }
        function palette(): void { desktop.applyViewState(2) }
        function settings(): void { desktop.applyViewState(3) }
        function all(): void { desktop.applyViewState(4) }
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

                if (root.settingsOpen)
                    root.closeSettings()
            }
        }
    }

    function friendlyAppName(appId, title) {
        const id = (appId || "").toLowerCase()

        if (id.indexOf("horizon") !== -1)
            return "Horizon"

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
        property bool batteryCharging: false
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
        property int wifiSignal: 0
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

        property bool dndEnabled: false
        property bool dndBusy: false
        property string dndError: ""

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
        readonly property color panelSurface: Qt.rgba(251 / 255, 249 / 255, 245 / 255, root.panelOpacity)
property real weatherTemperature: NaN
property int weatherCode: -1
property bool weatherIsDay: true
property string weatherSummary: "Updating..."
property string weatherSymbol: "◌"
property string weatherLocation: "__WEATHER_LOCATION__"
property real weatherLatitude: 48.8014
property real weatherLongitude: 2.1301
property date weatherUpdatedAt: new Date(0)

function applyViewState(state) {
    root.desktopWidgetsVisible = true
    viewState = state
    wifiMenuOpen = false
    bluetoothMenuOpen = false

    if (state === 2 || state === 4) {
        Qt.callLater(function() {
            searchInput.forceActiveFocus()
        })
    } else {
        searchInput.text = ""
        searchInput.focus = false
    }
}

function weatherSummaryForCode(code) {
    if (code === 0) return weatherIsDay ? "Clear" : "Clear night"
    if (code === 1) return "Mostly clear"
    if (code === 2) return "Partly cloudy"
    if (code === 3) return "Overcast"
    if (code === 45 || code === 48) return "Fog"
    if (code >= 51 && code <= 57) return "Drizzle"
    if (code >= 61 && code <= 67) return "Rain"
    if (code >= 71 && code <= 77) return "Snow"
    if (code >= 80 && code <= 82) return "Showers"
    if (code === 85 || code === 86) return "Snow showers"
    if (code >= 95) return "Thunderstorm"
    return "Weather unavailable"
}

function weatherSymbolForCode(code) {
    if (code === 0) return weatherIsDay ? "☀" : "☾"
    if (code <= 2) return weatherIsDay ? "◐" : "☾"
    if (code === 3 || code === 45 || code === 48) return "☁"
    if (code >= 51 && code <= 67) return "☂"
    if (code >= 71 && code <= 77) return "❄"
    if (code >= 80 && code <= 82) return "☂"
    if (code === 85 || code === 86) return "❄"
    if (code >= 95) return "⚡"
    return "◌"
}

function refreshWeather() {
    if (!weatherReader.running)
        weatherReader.running = true
}

Process {
    id: weatherReader
    command: [
        "bash",
        "-lc",
        "curl -fsS --connect-timeout 5 --max-time 12 "
        + "\"https://api.open-meteo.com/v1/forecast?latitude="
        + desktop.weatherLatitude
        + "&longitude="
        + desktop.weatherLongitude
        + "&current=temperature_2m,weather_code,is_day&timezone=auto&forecast_days=1\""
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            try {
                const payload = JSON.parse(text)
                const current = payload.current || {}
                const temperature = parseFloat(current.temperature_2m)
                const code = parseInt(current.weather_code)
                const day = parseInt(current.is_day)

                if (!isNaN(temperature))
                    desktop.weatherTemperature = temperature

                if (!isNaN(code))
                    desktop.weatherCode = code

                if (!isNaN(day))
                    desktop.weatherIsDay = day === 1

                desktop.weatherSummary = desktop.weatherSummaryForCode(desktop.weatherCode)
                desktop.weatherSymbol = desktop.weatherSymbolForCode(desktop.weatherCode)
                desktop.weatherUpdatedAt = new Date()
            } catch (error) {
                if (desktop.weatherCode < 0)
                    desktop.weatherSummary = "Weather unavailable"
                console.warn("Weather parse error:", error)
            }
        }
    }

    onExited: function(exitCode, exitStatus) {
        if (exitCode !== 0 && desktop.weatherCode < 0)
            desktop.weatherSummary = "Weather unavailable"
    }
}

Timer {
    id: weatherRefreshTimer
    interval: 900000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: desktop.refreshWeather()
}


        property var appItems: [
            {
                "icon": "brave-browser",
                "fallbackIcon": "browser.svg",
                "title": "Brave",
                "subtitle": "",
                "lookup": "Brave",
                "fallback": ["brave-browser"]
            },
            {
                "icon": "org.gnome.Nautilus",
                "fallbackIcon": "files.svg",
                "title": "Files",
                "subtitle": "",
                "lookup": "Files",
                "fallback": ["nautilus"]
            },
            {
                "icon": "Alacritty",
                "fallbackIcon": "terminal.svg",
                "title": "Terminal",
                "subtitle": "",
                "desktopFile": "__HOME__/.local/share/applications/precision-alacritty.desktop",
                "lookup": "Precision Terminal",
                "fallback": ["__HOME__/.local/bin/precision-alacritty"]
            },
            {
                "icon": "org.gnome.Settings",
                "fallbackIcon": "apps.svg",
                "title": "Settings",
                "subtitle": "",
                "lookup": "Fedora Settings via Precision",
                "fallback": ["__HOME__/.local/bin/precision-open-fedora-settings"],
                "action": "fedora-settings"
            }
        ]


        property var searchActionItems: [
            {
                "icon": "apps.svg",
                "title": "Wi-Fi",
                "subtitle": "Open wireless network settings",
                "action": "command",
                "command": [
                    "bash",
                    "-lc",
                    "if command -v gnome-control-center >/dev/null 2>&1; then exec gnome-control-center wifi; elif command -v nm-connection-editor >/dev/null 2>&1; then exec nm-connection-editor; else notify-send \"Wi-Fi\" \"No network settings application found\"; fi"
                ],
                "keywords": "wifi wi fi wireless network internet reseau réseau connexion sans fil wlan",
                "searchPriority": 90
            },
            {
                "icon": "apps.svg",
                "title": "Bluetooth",
                "subtitle": "Open Bluetooth settings",
                "action": "command",
                "command": [
                    "bash",
                    "-lc",
                    "if command -v gnome-control-center >/dev/null 2>&1; then exec gnome-control-center bluetooth; elif command -v blueman-manager >/dev/null 2>&1; then exec blueman-manager; else notify-send \"Bluetooth\" \"No Bluetooth settings application found\"; fi"
                ],
                "keywords": "bluetooth bt appareil devices casque ecouteurs écouteurs souris clavier",
                "searchPriority": 90
            },
            {
                "icon": "apps.svg",
                "title": "Appearance",
                "subtitle": "Precision Shell appearance settings",
                "action": "precision-settings",
                "section": 0,
                "keywords": "appearance apparence theme thème wallpaper fond ecran écran couleur style",
                "searchPriority": 72
            },
            {
                "icon": "apps.svg",
                "title": "System",
                "subtitle": "Precision Shell system settings",
                "action": "precision-settings",
                "section": 1,
                "keywords": "system système parametres paramètres settings configuration",
                "searchPriority": 70
            },
            {
                "icon": "apps.svg",
                "title": "Shortcuts",
                "subtitle": "Keyboard shortcuts",
                "action": "precision-settings",
                "section": 2,
                "keywords": "shortcuts raccourcis clavier touches keyboard hotkeys",
                "searchPriority": 70
            },
            {
                "icon": "apps.svg",
                "title": "Session & power",
                "subtitle": "Lock, suspend and session settings",
                "action": "precision-settings",
                "section": 3,
                "keywords": "session power alimentation eteindre éteindre shutdown reboot redemarrer redémarrer veille suspend logout deconnexion déconnexion",
                "searchPriority": 76
            },
            {
                "icon": "apps.svg",
                "title": "Lock screen",
                "subtitle": "Lock the current session",
                "action": "command",
                "command": ["loginctl", "lock-session"],
                "keywords": "lock verrouiller verrouillage ecran écran session",
                "searchPriority": 80
            },
            {
                "icon": "apps.svg",
                "title": "Suspend",
                "subtitle": "Put the computer to sleep",
                "action": "command",
                "command": ["systemctl", "suspend"],
                "keywords": "suspend sleep veille dormir ordinateur",
                "searchPriority": 78
            },
            {
                "icon": "apps.svg",
                "title": "Screenshot",
                "subtitle": "Capture a selected area",
                "action": "command",
                "command": ["niri", "msg", "action", "screenshot"],
                "keywords": "screenshot capture ecran écran image print screen selection zone",
                "searchPriority": 74
            },
            {
                "icon": "apps.svg",
                "title": "Task Manager",
                "subtitle": "Open the system monitor",
                "action": "command",
                "command": [
                    "bash",
                    "-lc",
                    "if command -v gnome-system-monitor >/dev/null 2>&1; then exec gnome-system-monitor; else exec precision-alacritty -e sh -lc 'top; exec sh'; fi"
                ],
                "keywords": "task manager gestionnaire taches tâches processus cpu ram memoire mémoire system monitor",
                "searchPriority": 72
            }
        ]

        property var searchAliases: ({
            "internet": ["brave", "browser", "web", "navigateur"],
            "web": ["brave", "browser", "internet", "navigateur"],
            "navigateur": ["brave", "browser", "internet", "web"],
            "fichier": ["files", "nautilus", "fichiers", "dossier"],
            "fichiers": ["files", "nautilus", "fichier", "dossier"],
            "dossier": ["files", "nautilus", "fichiers"],
            "explorateur": ["files", "nautilus", "fichiers"],
            "parametre": ["settings", "reglages", "configuration"],
            "parametres": ["settings", "reglages", "configuration"],
            "reglage": ["settings", "parametres", "configuration"],
            "reglages": ["settings", "parametres", "configuration"],
            "terminal": ["alacritty", "ptyxis", "console", "shell"],
            "console": ["terminal", "alacritty", "ptyxis", "shell"],
            "photo": ["darktable", "image", "photographie"],
            "photos": ["darktable", "image", "photographie"],
            "image": ["photo", "darktable", "graphisme"],
            "code": ["editor", "developpement", "programmation"],
            "editeur": ["editor", "code", "texte"],
            "wifi": ["wireless", "network", "reseau", "internet"],
            "reseau": ["network", "wifi", "wireless", "internet"],
            "bluetooth": ["bt", "devices", "appareil"],
            "capture": ["screenshot", "ecran", "image"],
            "verrouiller": ["lock", "verrouillage", "session"],
            "veille": ["suspend", "sleep"],
            "eteindre": ["shutdown", "power", "session"],
            "redemarrer": ["reboot", "restart", "session"]
        })

        property var searchUsage: ({})

        function normalizeSearch(value) {
            return String(value || "")
                .toLowerCase()
                .replace(/[àáâãäå]/g, "a")
                .replace(/[ç]/g, "c")
                .replace(/[èéêë]/g, "e")
                .replace(/[ìíîï]/g, "i")
                .replace(/[ñ]/g, "n")
                .replace(/[òóôõö]/g, "o")
                .replace(/[ùúûü]/g, "u")
                .replace(/[ýÿ]/g, "y")
                .replace(/[œ]/g, "oe")
                .replace(/[æ]/g, "ae")
                .replace(/[^a-z0-9]+/g, " ")
                .trim()
        }

        function searchWords(value) {
            const normalized = normalizeSearch(value)
            return normalized.length > 0
                ? normalized.split(/\s+/)
                : []
        }

        function searchItemKey(item) {
            if (item.desktopFile)
                return "desktop:" + item.desktopFile

            if (item.action)
                return "action:" + item.action
                    + ":" + (item.section !== undefined ? item.section : "")
                    + ":" + (item.title || "")

            return "item:" + (item.lookup || item.title || "")
        }

        function recordSearchUse(item) {
            const key = searchItemKey(item)
            searchUsage[key] = (searchUsage[key] || 0) + 1
        }

        function levenshteinDistance(left, right) {
            if (left === right)
                return 0
            if (left.length === 0)
                return right.length
            if (right.length === 0)
                return left.length

            let previous = []
            let current = []

            for (let column = 0; column <= right.length; column++)
                previous[column] = column

            for (let row = 1; row <= left.length; row++) {
                current = [row]

                for (let column = 1; column <= right.length; column++) {
                    const cost = left.charAt(row - 1) === right.charAt(column - 1)
                        ? 0
                        : 1

                    current[column] = Math.min(
                        current[column - 1] + 1,
                        previous[column] + 1,
                        previous[column - 1] + cost
                    )
                }

                previous = current
            }

            return previous[right.length]
        }

        function wordMatchScore(queryWord, targetWord) {
            if (!queryWord || !targetWord)
                return -1
            if (targetWord === queryWord)
                return 210
            if (targetWord.indexOf(queryWord) === 0)
                return 170
            if (targetWord.indexOf(queryWord) !== -1)
                return 125
            if (queryWord.length < 3)
                return -1

            const maximumDistance = queryWord.length >= 7 ? 2 : 1

            if (Math.abs(targetWord.length - queryWord.length) > maximumDistance)
                return -1

            const distance = levenshteinDistance(queryWord, targetWord)

            return distance <= maximumDistance
                ? 92 - distance * 22
                : -1
        }

        function queryVariants(word) {
            const variants = [word]
            const aliases = searchAliases[word] || []

            for (let index = 0; index < aliases.length; index++) {
                const normalized = normalizeSearch(aliases[index])

                if (normalized.length > 0
                        && variants.indexOf(normalized) === -1)
                    variants.push(normalized)
            }

            return variants
        }

        function itemSearchFields(item) {
            const title = normalizeSearch(item.title)
            const subtitle = normalizeSearch(item.subtitle)
            const lookup = normalizeSearch(item.lookup)
            const metadata = normalizeSearch(
                [
                    item.genericName,
                    item.comment,
                    item.keywords,
                    item.categories,
                    item.exec,
                    item.searchText
                ].join(" ")
            )

            return {
                "title": title,
                "subtitle": subtitle,
                "lookup": lookup,
                "titleWords": searchWords(title),
                "allWords": searchWords(
                    [title, subtitle, lookup, metadata].join(" ")
                )
            }
        }

        function scoreSearchItem(item, rawQuery) {
            const query = normalizeSearch(rawQuery)

            if (query.length === 0)
                return 0

            const fields = itemSearchFields(item)
            const queryWords = searchWords(query)
            let score = Number(item.searchPriority || 0)

            if (fields.title === query)
                score += 1500
            else if (fields.title.indexOf(query) === 0)
                score += 1120
            else if (fields.title.indexOf(query) !== -1)
                score += 760

            if (fields.lookup === query)
                score += 900
            else if (fields.lookup.indexOf(query) === 0)
                score += 620

            for (let queryIndex = 0; queryIndex < queryWords.length; queryIndex++) {
                const variants = queryVariants(queryWords[queryIndex])
                let bestScore = -1

                for (let variantIndex = 0; variantIndex < variants.length; variantIndex++) {
                    const synonymPenalty = variantIndex === 0 ? 0 : 28

                    for (let wordIndex = 0; wordIndex < fields.allWords.length; wordIndex++) {
                        const candidateScore = wordMatchScore(
                            variants[variantIndex],
                            fields.allWords[wordIndex]
                        )

                        if (candidateScore >= 0)
                            bestScore = Math.max(
                                bestScore,
                                candidateScore - synonymPenalty
                            )
                    }
                }

                if (bestScore < 0)
                    return -1

                score += bestScore
            }

            if (queryWords.length > 0) {
                for (let index = 0; index < fields.titleWords.length; index++) {
                    if (fields.titleWords[index] === queryWords[0]) {
                        score += 130
                        break
                    }
                }
            }

            score += Math.min(
                120,
                (searchUsage[searchItemKey(item)] || 0) * 18
            )

            return score
        }

        function isPinnedSearchItem(item) {
            const key = searchItemKey(item)

            for (let index = 0; index < appItems.length; index++) {
                if (searchItemKey(appItems[index]) === key)
                    return true
            }

            return false
        }

        function smartSearchItems(rawQuery, limit, allWhenEmpty) {
            const query = normalizeSearch(rawQuery)

            if (query.length === 0)
                return allWhenEmpty ? allAppItems : appItems

            const pool = []
            const seen = ({})
            const sources = [appItems, searchActionItems, allAppItems]

            for (let sourceIndex = 0; sourceIndex < sources.length; sourceIndex++) {
                const source = sources[sourceIndex]

                for (let itemIndex = 0; itemIndex < source.length; itemIndex++) {
                    const item = source[itemIndex]
                    const key = searchItemKey(item)

                    if (!seen[key]) {
                        seen[key] = true
                        pool.push(item)
                    }
                }
            }

            const scored = []

            for (let index = 0; index < pool.length; index++) {
                const item = pool[index]
                let score = scoreSearchItem(item, query)

                if (score < 0)
                    continue

                if (isPinnedSearchItem(item))
                    score += 46

                scored.push({
                    "item": item,
                    "score": score
                })
            }

            scored.sort(function(left, right) {
                if (right.score !== left.score)
                    return right.score - left.score

                return String(left.item.title || "").localeCompare(
                    String(right.item.title || "")
                )
            })

            const results = scored.map(function(entry) {
                return entry.item
            })

            return limit > 0
                ? results.slice(0, limit)
                : results
        }

        function executeSearchAction(item) {
            if (!item)
                return false

            if (item.action === "precision-settings") {
                root.openSettings(
                    item.section !== undefined
                        ? item.section
                        : 0
                )
                return true
            }

            if (item.action === "fedora-settings") {
                Quickshell.execDetached({
                    command: [
                        "__HOME__/.local/bin/precision-open-fedora-settings"
                    ]
                })
                root.closeLauncher()
                root.closeDashboard()
                return true
            }

            if (item.action === "command"
                    && item.command
                    && item.command.length > 0) {
                root.closeLauncher()
                root.closeDashboard()

                Quickshell.execDetached({
                    command: item.command
                })
                return true
            }

            return false
        }

        property var allAppItems: []
        property bool allAppsLoaded: false

function launchPinnedApplication(desktopFile, lookup, fallback) {
    if (desktopFile && desktopFile.length > 0) {
        Quickshell.execDetached({
            command: ["gio", "launch", desktopFile]
        })
    } else {
        const entry = DesktopEntries.heuristicLookup(lookup)

        if (entry !== null) {
            entry.execute()
        } else {
            Quickshell.execDetached({
                command: fallback
            })
        }
    }

    root.closeLauncher()
    root.closeDashboard()
}

Process {
    id: allAppsReader


    running: true
    command: [
        "bash",
        "-lc",
        "$HOME/.local/bin/precision-list-apps-safe"
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            try {
                const parsed = JSON.parse(text)
                if (Array.isArray(parsed)) {
                    desktop.allAppItems = root.enrichApplicationIcons(parsed)
                    desktop.allAppsLoaded = true
                }
            } catch (error) {
                console.warn("Application list:", error)
            }
        }
    }
}

                function filteredAppItems() {
            return desktop.smartSearchItems(
                searchInput.text,
                4,
                false
            )
        }

        function launchApplication(item) {
            desktop.recordSearchUse(item)
            const handled = desktop.executeSearchAction(item)

            if (!handled) {
                if (item.desktopFile && item.desktopFile.length > 0) {
                    Quickshell.execDetached({
                        command: ["gio", "launch", item.desktopFile]
                    })
                } else {
                    const desktopEntry = DesktopEntries.heuristicLookup(item.lookup)

                    if (desktopEntry !== null) {
                        desktopEntry.execute()
                    } else if (item.fallback && item.fallback.length > 0) {
                        Quickshell.execDetached({
                            command: item.fallback
                        })
                    }
                }
            }

            searchInput.text = ""
            searchInput.focus = false
            restoreWidgetsOnFocus = false
            wifiMenuOpen = false
            bluetoothMenuOpen = false
            viewState = 4
        }


        function openLibraryLocation(location) {
            let command = ""

            if (location === "recent") {
                command = "gio open recent:/// 2>/dev/null "
                    + "|| xdg-open recent:///"
            } else if (location === "documents") {
                command = "folder=$(xdg-user-dir DOCUMENTS 2>/dev/null); "
                    + "[ -n \"$folder\" ] || folder=\"$HOME/Documents\"; "
                    + "mkdir -p \"$folder\"; xdg-open \"$folder\""
            } else if (location === "downloads") {
                command = "folder=$(xdg-user-dir DOWNLOAD 2>/dev/null); "
                    + "[ -n \"$folder\" ] || folder=\"$HOME/Downloads\"; "
                    + "mkdir -p \"$folder\"; xdg-open \"$folder\""
            }

            if (command.length === 0)
                return

            Quickshell.execDetached({
                command: ["bash", "-lc", command]
            })

            root.closeDashboard()
        }

function showAllApplications() {
    root.openAllApplications()
}

        function toggleDnd() {
            if (dndBusy)
                return

            dndBusy = true
            dndError = ""

            dndWriter.exec([
                "bash",
                "-lc",
                "$HOME/.local/bin/precision-dnd toggle"
            ])
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
        + "| awk "
        + "'/percentage:/ {gsub(\"%\", \"\", $2); percentage=$2} "
        + "/state:/ {state=$2} "
        + "END {if (percentage != \"\") {print percentage; print state}}'"
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            const lines = text.replace(/\r/g, "").trim().split("\n")
            const parsed = parseInt(lines.length > 0 ? lines[0] : "")
            const state = lines.length > 1
                ? lines[1].trim().toLowerCase()
                : ""

            if (!isNaN(parsed))
                desktop.batteryPercent = Math.max(0, Math.min(100, parsed))

            desktop.batteryCharging = state === "charging"
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
        + "ssid=\"\"; signal=\"0\"; "
        + "if [ -n \"$device\" ]; then "
        + "ssid=$(nmcli -g GENERAL.CONNECTION device show \"$device\" "
        + "2>/dev/null | head -n1); "
        + "signal=$(nmcli -t -f IN-USE,SIGNAL device wifi list "
        + "ifname \"$device\" --rescan no 2>/dev/null "
        + "| awk -F: '$1 == \"*\" {print $2; exit}'); "
        + "fi; "
        + "[ \"$ssid\" = \"--\" ] && ssid=\"\"; "
        + "[ -z \"$signal\" ] && signal=\"0\"; "
        + "printf '%s\\n%s\\n%s\\n' \"$radio\" \"$ssid\" \"$signal\""
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            const normalized = text.replace(/\r/g, "").trim()
            const lines = normalized.length > 0
                ? normalized.split("\n")
                : []
            const radioState = lines.length > 0
                ? lines[0].trim().toLowerCase()
                : "disabled"
            const connectionName = lines.length > 1
                ? lines[1].trim()
                : ""
            const parsedSignal = lines.length > 2
                ? parseInt(lines[2].trim())
                : 0

            desktop.wifiEnabled = radioState === "enabled"
            desktop.wifiSsid = connectionName
            desktop.wifiConnected = desktop.wifiEnabled
                && connectionName.length > 0
            desktop.wifiSignal = desktop.wifiConnected
                && !isNaN(parsedSignal)
                ? Math.max(0, Math.min(100, parsedSignal))
                : 0
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


        Process {
            id: dndReader

            command: [
                "bash",
                "-lc",
                "$HOME/.local/bin/precision-dnd status"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    desktop.dndEnabled =
                        text.trim().toLowerCase() === "on"
                }
            }
        }

        Process {
            id: dndWriter

            stderr: StdioCollector {
                onStreamFinished: {
                    desktop.dndError = text.trim()

                    if (desktop.dndError.length > 0)
                        console.warn("DND control:", desktop.dndError)
                }
            }

            onExited: function(exitCode, exitStatus) {
                desktop.dndBusy = false

                if (!dndReader.running)
                    dndReader.running = true
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
            wifiMessage = ""
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
                if (root.dashboardWifiMenuOpen
                        || root.dashboardBluetoothMenuOpen) {
                    root.dashboardWifiMenuOpen = false
                    root.dashboardBluetoothMenuOpen = false
                } else if (root.dashboardOpen) {
                    root.closeDashboard()
                } else if (root.launcherOpen) {
                    root.closeLauncher()
                } else if (desktop.wifiMenuOpen) {
                    desktop.wifiMenuOpen = false
                } else if (desktop.bluetoothMenuOpen) {
                    desktop.bluetoothMenuOpen = false
                } else {
                    desktop.viewState = 1
                }
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

    width: desktop.s(92)
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
        width: parent.width
        spacing: desktop.s(8)

        Text {
            width: desktop.s(23)
            text: desktop.weatherSymbol
            color: desktop.softInk
            font.pixelSize: desktop.s(20)
            horizontalAlignment: Text.AlignHCenter
        }

        Text {
            text: isNaN(desktop.weatherTemperature)
                ? "--°"
                : Math.round(desktop.weatherTemperature) + "°"
            color: desktop.softInk
            font.family: "Inter"
            font.pixelSize: desktop.s(21.5)
            font.weight: Font.Light
        }
    }

    Text {
        width: parent.width
        text: desktop.weatherLocation
        color: desktop.softInk
        font.family: "Inter"
        font.pixelSize: desktop.s(9.3)
        elide: Text.ElideRight
    }

    Text {
        width: parent.width
        text: desktop.weatherSummary
        color: desktop.mutedInk
        font.family: "Inter"
        font.pixelSize: desktop.s(9.3)
        elide: Text.ElideRight
    }

    Rectangle {
        width: parent.width
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
    id: libraryPanelShadowSource
    x: libraryPanel.x
    y: libraryPanel.y
    width: libraryPanel.width
    height: libraryPanel.height
    radius: libraryPanel.radius
    scale: libraryPanel.scale
    visible: false
    layer.enabled: true
}

MultiEffect {
    source: libraryPanelShadowSource
    anchors.fill: libraryPanelShadowSource
    z: 2
    visible: libraryPanel.opened
    autoPaddingEnabled: true
    shadowEnabled: true
    shadowColor: "#60000000"
    shadowOpacity: 0.22
    shadowBlur: 1.0
    blurMax: 30
    shadowHorizontalOffset: 0
    shadowVerticalOffset: desktop.p(5)
    shadowScale: 1.01
    opacity: libraryPanel.opened ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
}

Rectangle {
    id: libraryPanel

    z: 3

    property bool opened: desktop.viewState === 4
        && root.desktopWidgetsVisible
        && !root.workspaceHasWindows

    anchors {
        left: parent.left
        leftMargin: desktop.p(26)
        bottom: parent.bottom
        bottomMargin: desktop.p(29)
    }

    width: desktop.p(150)
    height: desktop.p(214)
    radius: desktop.p(10)
    color: desktop.panelSurface
    border.width: Math.max(1, desktop.p(0.7))
    border.color: desktop.panelBorder

    opacity: opened ? 1 : 0
    scale: opened ? 1 : 0.985
    enabled: opened

    Column {
        anchors {
            fill: parent
            margins: desktop.p(12)
        }
        spacing: desktop.p(4)

        Text {
            width: parent.width
            height: desktop.p(18)
            text: "Apps"
            color: desktop.graphite
            font.family: "Inter"
            font.pixelSize: desktop.p(9.2)
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: [
                {
                    "title": "Atlas Portfolio",
                    "icon": "atlas-portfolio",
                    "fallbackIcon": "apps.svg",
                    "desktopFile": "/usr/share/applications/Atlas Portfolio.desktop",
                    "lookup": "Atlas Portfolio",
                    "fallback": ["atlas-portfolio"]
                },
                {
                    "title": "darktable AI",
                    "icon": "darktable-ai",
                    "fallbackIcon": "darktable.svg",
                    "desktopFile": "__HOME__/.local/share/applications/darktable-ai.desktop",
                    "lookup": "darktable AI",
                    "fallback": ["__HOME__/.local/bin/darktable-ai"]
                },
                {
                    "title": "Détour",
                    "icon": "detour",
                    "fallbackIcon": "apps.svg",
                    "desktopFile": "__HOME__/.local/share/applications/precision-settings.desktop",
                    "lookup": "Détour",
                    "fallback": ["__HOME__/.local/bin/precision-settings"]
                },
                {
                    "title": "Libris",
                    "icon": "libris-menu.png",
                    "desktopFile": "",
                    "lookup": "Libris",
                    "fallback": ["libris"]
                },
                {
                    "title": "Horizon",
                    "icon": "horizon.svg",
                    "desktopFile": "__HOME__/.local/share/applications/horizon.desktop",
                    "lookup": "Horizon",
                    "fallback": ["__HOME__/.local/bin/horizon"]
                }

            ]

            delegate: Item {
                required property var modelData
                width: parent.width
                height: desktop.p(23)

                Rectangle {
                    x: -desktop.p(5)
                    width: parent.width + desktop.p(10)
                    height: parent.height
                    radius: desktop.p(5)
                    color: libPinnedMouse.containsMouse
                        ? "#EEE5D9"
                        : "transparent"
                }

                AppIcon {
                    id: libPinnedIcon
                    anchors {
                        left: parent.left
                        leftMargin: desktop.p(1)
                        verticalCenter: parent.verticalCenter
                    }
                    source: root.appIconSource(
                        modelData.icon,
                        modelData.fallbackIcon
                    )
                    size: modelData.title === "Libris" ? desktop.p(14) : desktop.p(12)
                    iconOpacity: 0.92
                }

                Text {
                    anchors {
                        left: libPinnedIcon.right
                        leftMargin: desktop.p(7)
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData.title
                    color: libPinnedMouse.containsMouse
                        ? desktop.graphite
                        : desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(8.5)
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: libPinnedMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: modelData.available !== false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: desktop.launchPinnedApplication(
                        modelData.desktopFile,
                        modelData.lookup,
                        modelData.fallback
                    )
                }
            }
        }

        Item { width: 1; height: desktop.p(1) }

        Rectangle {
            width: parent.width
            height: Math.max(1, desktop.p(0.7))
            color: "#50D8CCBC"
        }

Item {
    id: libShowAllRow
    width: parent.width
    height: desktop.p(23)

    Rectangle {
        anchors.fill: parent
        radius: desktop.p(5.5)
        color: libShowAllMouse.containsMouse ? "#EEE5D9" : "transparent"
        border.width: libShowAllMouse.containsMouse ? Math.max(1, desktop.p(0.55)) : 0
        border.color: "#55CFC4B6"
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }
        text: "Show All"
        color: libShowAllMouse.containsMouse ? desktop.graphite : desktop.softInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
    }

    PremiumIcon {
        anchors {
            right: parent.right
            rightMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }
        source: Qt.resolvedUrl("icons/expand.svg")
        size: desktop.p(10.5)
        iconOpacity: 0.78
    }

    MouseArea {
        id: libShowAllMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: desktop.showAllApplications()
    }
}
    }
}

            Rectangle {
    id: commandPaletteShadowSource
    x: commandPalette.x
    y: commandPalette.y
    width: commandPalette.width
    height: commandPalette.height
    radius: commandPalette.radius
    scale: commandPalette.scale
    visible: false
    layer.enabled: true
}

MultiEffect {
    source: commandPaletteShadowSource
    anchors.fill: commandPaletteShadowSource
    z: 2
    visible: commandPalette.opened
    autoPaddingEnabled: true
    shadowEnabled: true
    shadowColor: "#60000000"
    shadowOpacity: 0.22
    shadowBlur: 1.0
    blurMax: 30
    shadowHorizontalOffset: 0
    shadowVerticalOffset: desktop.p(5)
    shadowScale: 1.01
    opacity: commandPalette.opened ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
}

Rectangle {
                id: commandPalette

    z: 3

                property bool opened: (desktop.viewState === 2 || desktop.viewState === 4) && root.desktopWidgetsVisible && !root.workspaceHasWindows

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(97)
                }

                width: desktop.p(438)
                height: desktop.p(106)
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

                    height: desktop.p(40)

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


                        onTextChanged: {
                            if (text.trim().length > 0
                                    && !desktop.allAppsLoaded
                                    && !allAppsReader.running) {
                                allAppsReader.running = true
                            }
                        }
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
                        topMargin: desktop.p(40)
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
                    text: "No matching application or command"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(8)
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: desktop.p(8)
                    }

                    spacing: desktop.p(31)

                    Repeater {
                        model: desktop.filteredAppItems()

                        delegate: Item {
                            id: appTile

                            width: desktop.p(64)
                            height: desktop.p(46)

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
                                spacing: desktop.p(2)

                                AppIcon {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: root.appIconSource(
                                        modelData.icon,
                                        modelData.fallbackIcon
                                    )
                                    size: desktop.p(18)
                                    iconOpacity: tileMouse.containsMouse ? 1.0 : 0.96
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.title
                                    color: tileMouse.containsMouse ? desktop.graphite : desktop.softInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(8.8)
                                    font.weight: Font.Normal
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
    id: settingsPanelShadowSource
    x: settingsPanel.x
    y: settingsPanel.y
    width: settingsPanel.width
    height: settingsPanel.height
    radius: settingsPanel.radius
    scale: settingsPanel.scale
    visible: false
    layer.enabled: true
}

MultiEffect {
    source: settingsPanelShadowSource
    anchors.fill: settingsPanelShadowSource
    z: 2
    visible: settingsPanel.opened
    autoPaddingEnabled: true
    shadowEnabled: true
    shadowColor: "#60000000"
    shadowOpacity: 0.22
    shadowBlur: 1.0
    blurMax: 30
    shadowHorizontalOffset: 0
    shadowVerticalOffset: desktop.p(5)
    shadowScale: 1.01
    opacity: settingsPanel.opened ? 1 : 0
    Behavior on opacity {
        NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
}

Rectangle {
                id: settingsPanel

    z: 3

                property bool opened: (desktop.viewState === 3 || desktop.viewState === 4) && root.desktopWidgetsVisible && !root.workspaceHasWindows

                anchors {
                    right: parent.right
                    rightMargin: desktop.p(26)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(29)
                }

                width: desktop.p(174)
                height: desktop.p(154) + (desktopMediaRow.visible ? desktop.p(45) : 0) + desktopSessionRow.height + desktop.p(9)
                radius: desktop.p(10)

                Behavior on height {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

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
                        margins: desktop.p(11)
                    }

                    spacing: desktop.p(6)

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
    size: desktop.p(13)
    iconOpacity: desktop.wifiEnabled ? 0.88 : 0.40
}

                        Text {
                            anchors {
                                left: wifiRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(44)
                            text: "Wi-Fi"
                            color: desktop.wifiEnabled
                                ? desktop.graphite
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.8)
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

                            width: desktop.p(40)
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
                            font.pixelSize: desktop.p(7.7)
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
    size: desktop.p(13)
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
                            font.pixelSize: desktop.p(8.8)
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

                            width: desktop.p(40)
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
                            font.pixelSize: desktop.p(7.7)
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
    id: dndRow

    width: parent.width
    height: desktop.p(15)

    PremiumIcon {
        id: dndRowIcon

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        source: Qt.resolvedUrl("icons/moon.svg")
        size: desktop.p(13)
        iconOpacity: desktop.dndEnabled ? 0.96 : 0.58
    }

    Text {
        anchors {
            left: dndRowIcon.right
            leftMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(72)
        text: "Do Not Disturb"
        color: desktop.dndEnabled
            ? desktop.graphite
            : desktop.softInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
        elide: Text.ElideRight
    }

    Rectangle {
        id: dndSwitch

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(20)
        height: desktop.p(11)
        radius: height / 2
        color: desktop.dndEnabled
            ? desktop.softInk
            : "#B9B1A8"
        opacity: desktop.dndBusy ? 0.58 : 1

        Rectangle {
            width: desktop.p(7)
            height: desktop.p(7)
            radius: width / 2
            color: desktop.warmWhite
            anchors.verticalCenter: parent.verticalCenter

            x: desktop.dndEnabled
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
            right: dndSwitch.left
            rightMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(28)
        text: desktop.dndBusy
            ? "..."
            : (desktop.dndEnabled ? "On" : "Off")
        horizontalAlignment: Text.AlignRight
        color: desktop.mutedInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !desktop.dndBusy
        onClicked: desktop.toggleDnd()
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
    size: desktop.p(13)
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
                            font.pixelSize: desktop.p(8.8)
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: desktop.batteryPercent + "%"
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.7)
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
    size: desktop.p(13)
    iconOpacity: 0.84
}

PremiumIcon {
    id: volumeRight
    anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/volume.svg")
    size: desktop.p(11)
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
    size: desktop.p(13)
    iconOpacity: 0.84
}

PremiumIcon {
    id: brightnessRight
    anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/brightness.svg")
    size: desktop.p(11)
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

Rectangle {
    id: desktopMediaRowSeparator
    width: parent.width
    height: Math.max(1, desktop.p(0.65))
    color: "#52D8CCBC"
    visible: desktopMediaRow.visible
}

PrecisionMediaRow {
    id: desktopMediaRow
    width: parent.width
    unit: desktop.p(1)
    graphite: desktop.graphite
    softInk: desktop.softInk
    mutedInk: desktop.mutedInk
}

Rectangle {
    id: desktopSessionRowSeparator
    width: parent.width
    height: Math.max(1, desktop.p(0.65))
    color: "#52D8CCBC"
}

PrecisionSessionRow {
    id: desktopSessionRow
    width: parent.width
    unit: desktop.p(1)
    graphite: desktop.graphite
    softInk: desktop.softInk
    mutedInk: desktop.mutedInk
    helperPath: "__HOME__/.local/bin/precision-session-action"
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
                        model: desktop.wifiNetworks.filter(function(network) {
                            return !network.connected
                        })
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
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "precision-shell-dashboard"

        color: Qt.rgba(0, 0, 0, root.overlayDarkness)
        function filteredItems() {
            return desktop.smartSearchItems(
                dashboardSearch.text,
                4,
                false
            )
        }

        function launchItem(item) {
            desktop.recordSearchUse(item)
            const handled = desktop.executeSearchAction(item)

            if (!handled) {
                if (item.desktopFile && item.desktopFile.length > 0) {
                    Quickshell.execDetached({
                        command: ["gio", "launch", item.desktopFile]
                    })
                } else {
                    const desktopEntry = DesktopEntries.heuristicLookup(item.lookup)

                    if (desktopEntry !== null) {
                        desktopEntry.execute()
                    } else if (item.fallback && item.fallback.length > 0) {
                        Quickshell.execDetached({
                            command: item.fallback
                        })
                    }
                }
            }

            dashboardSearch.text = ""
            root.closeDashboard()
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeDashboard()
        }





Rectangle {
    id: dashboardWeatherCard

    anchors {
        right: parent.right
        rightMargin: desktop.s(48)
        top: parent.top
        topMargin: desktop.s(49)
    }

    width: desktop.s(136)
    height: desktop.s(150)
    radius: desktop.s(14)
    z: 1
    color: "#FFFBF8F3"
    border.width: Math.max(1, desktop.s(0.9))
    border.color: "#B0CFC4B6"

    Column {
        id: dashboardWeatherBlock
        anchors {
            fill: parent
            leftMargin: desktop.s(20)
            rightMargin: desktop.s(20)
            topMargin: desktop.s(17)
            bottomMargin: desktop.s(17)
        }
        spacing: desktop.s(5.5)

        Row {
            width: parent.width
            spacing: desktop.s(8)

            Text {
                width: desktop.s(23)
                text: desktop.weatherSymbol
                color: desktop.softInk
                font.pixelSize: desktop.s(20)
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                text: isNaN(desktop.weatherTemperature)
                    ? "--°"
                    : Math.round(desktop.weatherTemperature) + "°"
                color: desktop.softInk
                font.family: "Inter"
                font.pixelSize: desktop.s(21.5)
                font.weight: Font.Light
            }
        }

        Text {
            width: parent.width
            text: desktop.weatherLocation
            color: desktop.softInk
            font.family: "Inter"
            font.pixelSize: desktop.s(9.3)
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: desktop.weatherSummary
            color: desktop.mutedInk
            font.family: "Inter"
            font.pixelSize: desktop.s(9.3)
            elide: Text.ElideRight
        }

        Rectangle {
            width: parent.width
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
}

Rectangle {
    id: dashboardLibrary

    anchors {
        left: parent.left
        leftMargin: desktop.p(26)
        bottom: parent.bottom
        bottomMargin: desktop.p(29)
    }

    width: desktop.p(150)
    height: desktop.p(214)
    radius: desktop.p(10)
    color: desktop.panelSurface
    border.width: Math.max(1, desktop.p(0.7))
    border.color: desktop.panelBorder

    Column {
        anchors {
            fill: parent
            margins: desktop.p(12)
        }
        spacing: desktop.p(4)

        Text {
            width: parent.width
            height: desktop.p(18)
            text: "Apps"
            color: desktop.graphite
            font.family: "Inter"
            font.pixelSize: desktop.p(9.2)
            font.weight: Font.Medium
            verticalAlignment: Text.AlignVCenter
        }

        Repeater {
            model: [
                {
                    "title": "Atlas Portfolio",
                    "icon": "atlas-portfolio",
                    "fallbackIcon": "apps.svg",
                    "desktopFile": "/usr/share/applications/Atlas Portfolio.desktop",
                    "lookup": "Atlas Portfolio",
                    "fallback": ["atlas-portfolio"]
                },
                {
                    "title": "darktable AI",
                    "icon": "darktable-ai",
                    "fallbackIcon": "darktable.svg",
                    "desktopFile": "__HOME__/.local/share/applications/darktable-ai.desktop",
                    "lookup": "darktable AI",
                    "fallback": ["__HOME__/.local/bin/darktable-ai"]
                },
                {
                    "title": "Détour",
                    "icon": "detour",
                    "fallbackIcon": "apps.svg",
                    "desktopFile": "__HOME__/.local/share/applications/precision-settings.desktop",
                    "lookup": "Détour",
                    "fallback": ["__HOME__/.local/bin/precision-settings"]
                },
                {
                    "title": "Libris",
                    "icon": "libris-menu.png",
                    "desktopFile": "",
                    "lookup": "Libris",
                    "fallback": ["libris"]
                },
                {
                    "title": "Horizon",
                    "icon": "horizon.svg",
                    "desktopFile": "__HOME__/.local/share/applications/horizon.desktop",
                    "lookup": "Horizon",
                    "fallback": ["__HOME__/.local/bin/horizon"]
                }

            ]

            delegate: Item {
                required property var modelData
                width: parent.width
                height: desktop.p(23)

                Rectangle {
                    x: -desktop.p(5)
                    width: parent.width + desktop.p(10)
                    height: parent.height
                    radius: desktop.p(5)
                    color: dashLibPinnedMouse.containsMouse
                        ? "#EEE5D9"
                        : "transparent"
                }

                AppIcon {
                    id: dashLibPinnedIcon
                    anchors {
                        left: parent.left
                        leftMargin: desktop.p(1)
                        verticalCenter: parent.verticalCenter
                    }
                    source: root.appIconSource(
                        modelData.icon,
                        modelData.fallbackIcon
                    )
                    size: modelData.title === "Libris" ? desktop.p(14) : desktop.p(12)
                    iconOpacity: 0.92
                }

                Text {
                    anchors {
                        left: dashLibPinnedIcon.right
                        leftMargin: desktop.p(7)
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData.title
                    color: dashLibPinnedMouse.containsMouse
                        ? desktop.graphite
                        : desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(8.5)
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: dashLibPinnedMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: modelData.available !== false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: desktop.launchPinnedApplication(
                        modelData.desktopFile,
                        modelData.lookup,
                        modelData.fallback
                    )
                }
            }
        }

        Item { width: 1; height: desktop.p(1) }

        Rectangle {
            width: parent.width
            height: Math.max(1, desktop.p(0.7))
            color: "#50D8CCBC"
        }

Item {
    id: dashLibShowAllRow
    width: parent.width
    height: desktop.p(23)

    Rectangle {
        anchors.fill: parent
        radius: desktop.p(5.5)
        color: dashLibShowAllMouse.containsMouse ? "#EEE5D9" : "transparent"
        border.width: dashLibShowAllMouse.containsMouse ? Math.max(1, desktop.p(0.55)) : 0
        border.color: "#55CFC4B6"
    }

    Text {
        anchors {
            left: parent.left
            leftMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }
        text: "Show All"
        color: dashLibShowAllMouse.containsMouse ? desktop.graphite : desktop.softInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
    }

    PremiumIcon {
        anchors {
            right: parent.right
            rightMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }
        source: Qt.resolvedUrl("icons/expand.svg")
        size: desktop.p(10.5)
        iconOpacity: 0.78
    }

    MouseArea {
        id: dashLibShowAllMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: desktop.showAllApplications()
    }
}
    }
}

                Rectangle {
            id: dashboardPaletteShadowSource

            x: dashboardPalette.x
            y: dashboardPalette.y
            width: dashboardPalette.width
            height: dashboardPalette.height
            radius: dashboardPalette.radius
            scale: dashboardPalette.scale

            visible: false
            layer.enabled: true
        }

        MultiEffect {
            source: dashboardPaletteShadowSource
            anchors.fill: dashboardPaletteShadowSource
            z: 2

            visible: root.dashboardOpen
            autoPaddingEnabled: true

            shadowEnabled: true
            shadowColor: "#65000000"
            shadowOpacity: 0.24
            shadowBlur: 1.0
            blurMax: 34
            shadowHorizontalOffset: 0
            shadowVerticalOffset: desktop.p(5)
            shadowScale: 1.01
        }

Rectangle {
            id: dashboardPalette

            z: 3

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: desktop.p(97)
            }

            width: desktop.p(438)
            height: desktop.p(106)
            radius: desktop.p(10)

            color: desktop.panelSurface
            border.width: Math.max(1, desktop.p(0.7))
            border.color: desktop.panelBorder
            clip: true

            opacity: root.dashboardOpen ? 1 : 0
            scale: root.dashboardOpen ? 1 : 0.975

            Behavior on opacity {
                NumberAnimation {
                    duration: 155
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.55
                }
            }

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

                height: desktop.p(40)

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
                    onTextChanged: {
                        if (text.trim().length > 0
                                && !desktop.allAppsLoaded
                                && !allAppsReader.running) {
                            allAppsReader.running = true
                        }
                    }

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

                    text: "SUPER D"
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
                    topMargin: desktop.p(40)
                }

                height: Math.max(1, desktop.p(0.7))
                color: "#55D8CCBC"
            }

            Row {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: desktop.p(8)
                }

                spacing: desktop.p(31)

                Repeater {
                    model: dashboardWindow.filteredItems()

                    delegate: Item {
                        id: dashboardTile

                        required property var modelData

                        width: desktop.p(64)
                        height: desktop.p(46)
                        scale: dashboardTileMouse.containsMouse ? 1.055 : 1.0

                        Behavior on scale {
                            NumberAnimation {
                                duration: 125
                                easing.type: Easing.OutCubic
                            }
                        }

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
                            spacing: desktop.p(2)

                            AppIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: root.appIconSource(
                                    modelData.icon,
                                    modelData.fallbackIcon
                                )
                                size: desktop.p(18)
                                iconOpacity: dashboardTileMouse.containsMouse
                                    ? 1.0
                                    : 0.96
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
                                visible: dashboardSearch.text.trim().length > 0
                                    && modelData.subtitle.length > 0
                                text: modelData.subtitle
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.8)
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

                property bool opened: true

                anchors {
                    right: parent.right
                    rightMargin: desktop.p(26)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(29)
                }

                width: desktop.p(174)
                height: desktop.p(154) + (dashboardMediaRow.visible ? desktop.p(45) : 0) + dashboardSessionRow.height + desktop.p(9)
                radius: desktop.p(10)

                Behavior on height {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.65))
                border.color: desktop.panelBorder

                opacity: 1
                scale: 1
                enabled: true

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
                        margins: desktop.p(11)
                    }

                    spacing: desktop.p(6)

                    Item {
                        width: parent.width
                        height: desktop.p(15)

PremiumIcon {
    id: dashMirrorWifiRowIcon

    anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
    }

    source: Qt.resolvedUrl("icons/wifi.svg")
    size: desktop.p(13)
    iconOpacity: desktop.wifiEnabled ? 0.88 : 0.40
}

                        Text {
                            anchors {
                                left: dashMirrorWifiRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(44)
                            text: "Wi-Fi"
                            color: desktop.wifiEnabled
                                ? desktop.graphite
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.8)
                        }

                        Rectangle {
                            id: dashMirrorWifiToggle

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
                                right: dashMirrorWifiToggle.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(40)
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
                            font.pixelSize: desktop.p(7.7)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                right: dashMirrorWifiToggle.left
                                rightMargin: desktop.p(5)
                            }

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.dashboardWifiMenuOpen =
                                    !root.dashboardWifiMenuOpen
                                root.dashboardBluetoothMenuOpen = false

                                if (root.dashboardWifiMenuOpen
                                        && desktop.wifiEnabled) {
                                    desktop.scanWifi()
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: dashMirrorWifiToggle
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
    id: dashMirrorBluetoothRowIcon

    anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
    }

    source: Qt.resolvedUrl("icons/bluetooth.svg")
    size: desktop.p(13)
    iconOpacity: desktop.bluetoothEnabled ? 0.88 : 0.40
}

                        Text {
                            anchors {
                                left: dashMirrorBluetoothRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(62)
                            text: "Bluetooth"
                            color: desktop.bluetoothEnabled
                                ? desktop.graphite
                                : desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.8)
                            elide: Text.ElideRight
                        }

                        Rectangle {
                            id: dashMirrorBluetoothToggle

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
                                right: dashMirrorBluetoothToggle.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            width: desktop.p(40)
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
                            font.pixelSize: desktop.p(7.7)
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors {
                                left: parent.left
                                top: parent.top
                                bottom: parent.bottom
                                right: dashMirrorBluetoothToggle.left
                                rightMargin: desktop.p(5)
                            }

                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.dashboardBluetoothMenuOpen =
                                    !root.dashboardBluetoothMenuOpen
                                root.dashboardWifiMenuOpen = false

                                if (root.dashboardBluetoothMenuOpen
                                        && !bluetoothReader.running) {
                                    bluetoothReader.running = true
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: dashMirrorBluetoothToggle
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: !desktop.bluetoothBusy
                            onClicked: desktop.toggleBluetooth()
                        }
                    }

Item {
    id: dashMirrorDndRow

    width: parent.width
    height: desktop.p(15)

    PremiumIcon {
        id: dashMirrorDndRowIcon

        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
        }

        source: Qt.resolvedUrl("icons/moon.svg")
        size: desktop.p(13)
        iconOpacity: desktop.dndEnabled ? 0.96 : 0.58
    }

    Text {
        anchors {
            left: dashMirrorDndRowIcon.right
            leftMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(72)
        text: "Do Not Disturb"
        color: desktop.dndEnabled
            ? desktop.graphite
            : desktop.softInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
        elide: Text.ElideRight
    }

    Rectangle {
        id: dashMirrorDndSwitch

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(20)
        height: desktop.p(11)
        radius: height / 2
        color: desktop.dndEnabled
            ? desktop.softInk
            : "#B9B1A8"
        opacity: desktop.dndBusy ? 0.58 : 1

        Rectangle {
            width: desktop.p(7)
            height: desktop.p(7)
            radius: width / 2
            color: desktop.warmWhite
            anchors.verticalCenter: parent.verticalCenter

            x: desktop.dndEnabled
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
            right: dashMirrorDndSwitch.left
            rightMargin: desktop.p(7)
            verticalCenter: parent.verticalCenter
        }

        width: desktop.p(28)
        text: desktop.dndBusy
            ? "..."
            : (desktop.dndEnabled ? "On" : "Off")
        horizontalAlignment: Text.AlignRight
        color: desktop.mutedInk
        font.family: "Inter"
        font.pixelSize: desktop.p(8.5)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        enabled: !desktop.dndBusy
        onClicked: desktop.toggleDnd()
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
    id: dashMirrorBatteryRowIcon

    anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
    }

    source: Qt.resolvedUrl("icons/battery.svg")
    size: desktop.p(13)
    iconOpacity: 0.88
}

                        Text {
                            anchors {
                                left: dashMirrorBatteryRowIcon.right
                                leftMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }

                            text: "Battery"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(8.8)
                        }

                        Text {
                            anchors {
                                right: parent.right
                                verticalCenter: parent.verticalCenter
                            }

                            text: desktop.batteryPercent + "%"
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: desktop.p(7.7)
                            font.weight: Font.Normal
                        }
                    }

                    Item {
                        width: parent.width
                        height: desktop.p(16)

PremiumIcon {
    id: dashMirrorVolumeLeft
    anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/volume.svg")
    size: desktop.p(13)
    iconOpacity: 0.84
}

PremiumIcon {
    id: dashMirrorVolumeRight
    anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/volume.svg")
    size: desktop.p(11)
    iconOpacity: 0.74
}

                        Slider {
                            id: dashMirrorVolumeSlider

                            anchors {
                                left: dashMirrorVolumeLeft.right
                                leftMargin: desktop.p(7)
                                right: dashMirrorVolumeRight.left
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
                                x: dashMirrorVolumeSlider.leftPadding
                                y: dashMirrorVolumeSlider.topPadding
                                    + dashMirrorVolumeSlider.availableHeight / 2
                                    - height / 2
                                width: dashMirrorVolumeSlider.availableWidth
                                height: desktop.p(1.6)
                                radius: height / 2
                                color: "#CBC1B5"

                                Rectangle {
                                    width: dashMirrorVolumeSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: desktop.softInk
                                }
                            }

                            handle: Rectangle {
                                x: dashMirrorVolumeSlider.leftPadding
                                    + dashMirrorVolumeSlider.visualPosition
                                    * (dashMirrorVolumeSlider.availableWidth - width)
                                y: dashMirrorVolumeSlider.topPadding
                                    + dashMirrorVolumeSlider.availableHeight / 2
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
    id: dashMirrorBrightnessLeft
    anchors {
        left: parent.left
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/brightness.svg")
    size: desktop.p(13)
    iconOpacity: 0.84
}

PremiumIcon {
    id: dashMirrorBrightnessRight
    anchors {
        right: parent.right
        verticalCenter: parent.verticalCenter
    }
    source: Qt.resolvedUrl("icons/brightness.svg")
    size: desktop.p(11)
    iconOpacity: 0.74
}

                        Slider {
                            id: dashMirrorBrightnessSlider

                            anchors {
                                left: dashMirrorBrightnessLeft.right
                                leftMargin: desktop.p(7)
                                right: dashMirrorBrightnessRight.left
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
                                x: dashMirrorBrightnessSlider.leftPadding
                                y: dashMirrorBrightnessSlider.topPadding
                                    + dashMirrorBrightnessSlider.availableHeight / 2
                                    - height / 2
                                width: dashMirrorBrightnessSlider.availableWidth
                                height: desktop.p(1.6)
                                radius: height / 2
                                color: "#CBC1B5"

                                Rectangle {
                                    width: dashMirrorBrightnessSlider.visualPosition * parent.width
                                    height: parent.height
                                    radius: parent.radius
                                    color: desktop.softInk
                                }
                            }

                            handle: Rectangle {
                                x: dashMirrorBrightnessSlider.leftPadding
                                    + dashMirrorBrightnessSlider.visualPosition
                                    * (dashMirrorBrightnessSlider.availableWidth - width)
                                y: dashMirrorBrightnessSlider.topPadding
                                    + dashMirrorBrightnessSlider.availableHeight / 2
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

Rectangle {
    id: dashboardMediaRowSeparator
    width: parent.width
    height: Math.max(1, desktop.p(0.65))
    color: "#52D8CCBC"
    visible: dashboardMediaRow.visible
}

PrecisionMediaRow {
    id: dashboardMediaRow
    width: parent.width
    unit: desktop.p(1)
    graphite: desktop.graphite
    softInk: desktop.softInk
    mutedInk: desktop.mutedInk
}

Rectangle {
    id: dashboardSessionRowSeparator
    width: parent.width
    height: Math.max(1, desktop.p(0.65))
    color: "#52D8CCBC"
}

PrecisionSessionRow {
    id: dashboardSessionRow
    width: parent.width
    unit: desktop.p(1)
    graphite: desktop.graphite
    softInk: desktop.softInk
    mutedInk: desktop.mutedInk
    helperPath: "__HOME__/.local/bin/precision-session-action"
}
                }
            }

MouseArea {
    id: dashboardDetailMenuDismissLayer

    anchors.fill: parent
    z: 89

    visible: root.dashboardWifiMenuOpen
        || root.dashboardBluetoothMenuOpen
    enabled: visible

    acceptedButtons: Qt.AllButtons
    cursorShape: Qt.ArrowCursor
    preventStealing: true
    propagateComposedEvents: false

    onPressed: function(mouse) {
        mouse.accepted = true
    }

    onClicked: function(mouse) {
        root.dashboardWifiMenuOpen = false
        root.dashboardBluetoothMenuOpen = false
        mouse.accepted = true
    }
}

            Rectangle {
                id: dashboardBluetoothMenu

                anchors {
                    right: dashboardSettings.left
                    rightMargin: desktop.p(9)
                    bottom: dashboardSettings.bottom
                }

                width: desktop.p(178)
                height: desktop.p(170)
                radius: desktop.p(10)
                z: 90

                color: desktop.panelSurface
                border.width: Math.max(1, desktop.p(0.65))
                border.color: desktop.panelBorder

                visible: opacity > 0
                enabled: root.dashboardBluetoothMenuOpen
                opacity: root.dashboardBluetoothMenuOpen ? 1 : 0
                scale: root.dashboardBluetoothMenuOpen ? 1 : 0.985

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

                            text: "Actualiser"
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
                            id: dashboardActiveBluetoothIcon

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
                                left: dashboardActiveBluetoothIcon.right
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
                        id: dashboardBluetoothDeviceList

                        width: parent.width
                        height: desktop.p(88)
                        clip: true
                        spacing: desktop.p(1)
                        model: desktop.bluetoothDevices
                        interactive: contentHeight > height
                        visible: desktop.bluetoothEnabled

                        delegate: Item {
                            required property var modelData

                            width: dashboardBluetoothDeviceList.width
                            height: desktop.p(22)

                            Rectangle {
                                anchors.fill: parent
                                radius: desktop.p(5)
                                color: dashboardBluetoothDeviceMouse.containsMouse
                                    ? "#3AD8CCBC"
                                    : "transparent"
                            }

                            PremiumIcon {
                                id: dashboardBluetoothDeviceIcon

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
                                    left: dashboardBluetoothDeviceIcon.right
                                    leftMargin: desktop.p(6)
                                    right: dashboardBluetoothDeviceState.left
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
                                        ? "Connecté"
                                        : "Appairé"
                                    color: desktop.mutedInk
                                    font.family: "Inter"
                                    font.pixelSize: desktop.p(6.1)
                                    elide: Text.ElideRight
                                }
                            }

                            Text {
                                id: dashboardBluetoothDeviceState

                                anchors {
                                    right: parent.right
                                    verticalCenter: parent.verticalCenter
                                }

                                text: modelData.connected ? "Déconnecter" : "Connecter"
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.1)
                            }

                            MouseArea {
                                id: dashboardBluetoothDeviceMouse

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
    id: dashboardWifiMenu

    anchors {
        right: dashboardSettings.left
        rightMargin: desktop.p(9)
        bottom: dashboardSettings.bottom
    }

    width: desktop.p(178)
    height: desktop.p(170)
    radius: desktop.p(10)
    z: 90

    color: desktop.panelSurface
    border.width: Math.max(1, desktop.p(0.65))
    border.color: desktop.panelBorder

    visible: opacity > 0
    enabled: root.dashboardWifiMenuOpen
    opacity: root.dashboardWifiMenuOpen ? 1 : 0
    scale: root.dashboardWifiMenuOpen ? 1 : 0.985

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

                text: desktop.wifiScanning
                    ? "Analyse..."
                    : "Actualiser"
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
                id: dashboardActiveWifiIcon

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
                    left: dashboardActiveWifiIcon.right
                    leftMargin: desktop.p(7)
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }

                text: !desktop.wifiEnabled
                    ? "Wi-Fi désactivé"
                    : (desktop.wifiConnected
                        ? desktop.wifiSsid
                        : "Non connecté")
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
            id: dashboardWifiNetworkList

            width: parent.width
            height: desktop.p(88)
            clip: true
            spacing: desktop.p(1)
            model: desktop.wifiNetworks.filter(function(network) {
                return !network.connected
            })
            interactive: contentHeight > height
            visible: desktop.wifiEnabled

            delegate: Item {
                required property var modelData

                width: dashboardWifiNetworkList.width
                height: desktop.p(20)

                Rectangle {
                    anchors.fill: parent
                    radius: desktop.p(5)
                    color: dashboardNetworkMouse.containsMouse
                        ? "#3AD8CCBC"
                        : "transparent"
                }

                PremiumIcon {
                    id: dashboardNetworkIcon

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
                        left: dashboardNetworkIcon.right
                        leftMargin: desktop.p(6)
                        right: dashboardSignalText.left
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
                            ? "Connecté"
                            : (modelData.security.length > 0
                                && modelData.security !== "--"
                                ? "Sécurisé"
                                : "Ouvert")
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(6.1)
                        elide: Text.ElideRight
                    }
                }

                Text {
                    id: dashboardSignalText

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
                    id: dashboardNetworkMouse

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

    SettingsWindow {
        id: precisionSettings
        shellRoot: root
        desktopContext: desktop
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
    return desktop.smartSearchItems(
        launcherSearch.text,
        root.launcherAllMode ? 0 : 4,
        root.launcherAllMode
    )
}

function launchItem(item) {
    desktop.recordSearchUse(item)
    const handled = desktop.executeSearchAction(item)

    if (!handled) {
        if (item.desktopFile && item.desktopFile.length > 0) {
            Quickshell.execDetached({
                command: ["gio", "launch", item.desktopFile]
            })
        } else {
            const entry = DesktopEntries.heuristicLookup(item.lookup)

            if (entry !== null) {
                entry.execute()
            } else if (item.fallback && item.fallback.length > 0) {
                Quickshell.execDetached({
                    command: item.fallback
                })
            }
        }
    }

    launcherSearch.text = ""
    root.closeLauncher()
}

        Rectangle {
            anchors.fill: parent
            color: "#24000000"
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.closeLauncher()
        }

Rectangle {
    id: allAppsBackdrop
    anchors.fill: parent
    visible: root.launcherAllMode
    color: "#30000000"

    MouseArea {
        anchors.fill: parent
        onClicked: root.closeLauncher()
    }
}

                Rectangle {
            id: launcherCardShadowSource

            x: launcherCard.x
            y: launcherCard.y
            width: launcherCard.width
            height: launcherCard.height
            radius: launcherCard.radius
            scale: launcherCard.scale

            visible: false
            layer.enabled: true
        }

        MultiEffect {
            source: launcherCardShadowSource
            anchors.fill: launcherCardShadowSource
            z: 2

            visible: root.launcherOpen
            autoPaddingEnabled: true

            shadowEnabled: true
            shadowColor: "#65000000"
            shadowOpacity: 0.24
            shadowBlur: 1.0
            blurMax: 34
            shadowHorizontalOffset: 0
            shadowVerticalOffset: desktop.p(5)
            shadowScale: 1.01
        }

Rectangle {
            id: launcherCard

            z: 3

            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.bottom
                bottomMargin: root.launcherAllMode ? desktop.p(58) : desktop.p(97)
            }

            width: root.launcherAllMode ? desktop.p(620) : desktop.p(438)
            height: root.launcherAllMode ? desktop.p(390) : desktop.p(106)
            radius: desktop.p(10)

            color: desktop.panelSurface
            border.width: Math.max(1, desktop.p(0.7))
            border.color: desktop.panelBorder
            clip: true

            opacity: root.launcherOpen ? 1 : 0
            scale: root.launcherOpen ? 1 : 0.975

            Behavior on opacity {
                NumberAnimation {
                    duration: 155
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.55
                }
            }

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

                height: root.launcherAllMode
                    ? desktop.p(45)
                    : desktop.p(40)

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


                    onTextChanged: {
                        if (text.trim().length > 0
                                && !desktop.allAppsLoaded
                                && !allAppsReader.running) {
                            allAppsReader.running = true
                        }
                    }
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
                    placeholderText: root.launcherAllMode
                        ? "Search all applications..."
                        : "Search or type a command..."
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

                    text: root.launcherAllMode
                        ? "ALL APPS"
                        : "SUPER  SPACE"
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
                    topMargin: root.launcherAllMode
                        ? desktop.p(45)
                        : desktop.p(40)
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
                text: "No matching application or command"
                color: desktop.mutedInk
                font.family: "Inter"
                font.pixelSize: desktop.p(8)
            }

Item {
    anchors {
        left: parent.left
        right: parent.right
        top: parent.top
        topMargin: root.launcherAllMode
            ? desktop.p(46)
            : desktop.p(41)
        bottom: parent.bottom
    }

    Row {
        visible: !root.launcherAllMode
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: desktop.p(8)
        }
        spacing: desktop.p(31)

        Repeater {
            model: launcherWindow.filteredItems()

            delegate: Item {
                id: launcherTile
                required property var modelData
                width: desktop.p(64)
                height: desktop.p(46)
                scale: quickTileMouse.containsMouse ? 1.055 : 1.0

                Behavior on scale {
                    NumberAnimation {
                        duration: 125
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: desktop.p(2)

                    AppIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        source: root.appIconSource(
                            modelData.icon,
                            modelData.fallbackIcon
                        )
                        size: desktop.p(18)
                        iconOpacity: quickTileMouse.containsMouse
                            ? 1
                            : 0.96
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.title
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(8.8)
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: launcherSearch.text.trim().length > 0
                            && modelData.subtitle.length > 0
                        text: modelData.subtitle
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.p(6.8)
                    }
                }

                MouseArea {
                    id: quickTileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: launcherWindow.launchItem(modelData)
                }
            }
        }
    }

    GridView {
        id: allAppsGrid
        visible: root.launcherAllMode

        anchors {
            fill: parent
            margins: desktop.p(15)
            topMargin: desktop.p(14)
        }

        clip: true
        cellWidth: desktop.p(116)
        cellHeight: desktop.p(72)
        model: launcherWindow.filteredItems()

        // Les événements restent gérés explicitement afin d'éviter le
        // défilement natif trop lent du GridView. Le facteur est volontairement
        // faible car le pavé tactile est également ralenti dans Niri.
        readonly property real wheelRowsPerNotch: 0.55
        readonly property real pixelWheelMultiplier: 0.55

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
        }

        delegate: Item {
            id: allAppsTile
            required property var modelData
            width: allAppsGrid.cellWidth
            height: allAppsGrid.cellHeight
            scale: allAppsMouse.containsMouse ? 1.035 : 1.0

            Behavior on scale {
                NumberAnimation {
                    duration: 120
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors {
                    fill: parent
                    margins: desktop.p(4)
                }
                radius: desktop.p(7)
                color: allAppsMouse.containsMouse
                    ? "#58D8CCBC"
                    : "transparent"
                border.width: allAppsMouse.containsMouse
                    ? Math.max(1, desktop.p(0.45))
                    : 0
                border.color: "#48A89E92"
            }

            Column {
                anchors {
                    fill: parent
                    margins: desktop.p(8)
                }
                spacing: desktop.p(4)

                AppIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    source: root.appIconSource(
                        modelData.icon,
                        modelData.fallbackIcon
                    )
                    size: desktop.p(22)
                    iconOpacity: 0.96
                }

                Text {
                    width: parent.width
                    text: modelData.title
                    horizontalAlignment: Text.AlignHCenter
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(8.2)
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    text: modelData.subtitle
                    horizontalAlignment: Text.AlignHCenter
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.p(6.8)
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: allAppsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: launcherWindow.launchItem(modelData)
            }
        }
    }

    MouseArea {
        id: allAppsWheelArea

        visible: root.launcherAllMode
        anchors.fill: allAppsGrid
        z: 100
        acceptedButtons: Qt.NoButton

        onWheel: function(wheel) {
            let movement = 0

            if (wheel.angleDelta.y !== 0) {
                movement = (wheel.angleDelta.y / 120)
                    * allAppsGrid.cellHeight
                    * allAppsGrid.wheelRowsPerNotch
            } else if (wheel.pixelDelta.y !== 0) {
                movement = wheel.pixelDelta.y
                    * allAppsGrid.pixelWheelMultiplier
            }

            if (movement === 0)
                return

            const minimum = allAppsGrid.originY
            const maximum = Math.max(
                minimum,
                allAppsGrid.originY
                    + allAppsGrid.contentHeight
                    - allAppsGrid.height
            )

            allAppsGrid.contentY = Math.max(
                minimum,
                Math.min(
                    maximum,
                    allAppsGrid.contentY - movement
                )
            )

            wheel.accepted = true
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
    // Le relâchement d'Alt est validé par
    // precision-alt-release.service.
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

                                    AppIcon {
                                        anchors.centerIn: parent
                                        source: root.appIconSource(
                                            modelData.icon,
                                            modelData.fallbackIcon
                                        )
                                        size: desktop.p(20)
                                        iconOpacity: 1.0
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
            bottom: true
            left: true
            right: true
        }

        // Espace suffisant pour ne pas couper le flou du shader.
        implicitHeight: desktop.s(116)
        exclusionMode: ExclusionMode.Ignore
        focusable: false

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "precision-shell-osd"

        color: "transparent"

        // Silhouette invisible utilisée uniquement comme source du shader.
        Rectangle {
            id: osdShadowSource

            x: osdCard.x
            y: osdCard.y
            width: osdCard.width
            height: osdCard.height
            radius: osdCard.radius

            color: osdCard.color
            visible: false
            layer.enabled: true
        }

        // Véritable ombre floutée continue : aucune couche en escalier.
        MultiEffect {
            id: osdShadowEffect

            source: osdShadowSource
            anchors.fill: osdShadowSource
            z: 1

            visible: root.osdShown
            autoPaddingEnabled: true

            shadowEnabled: true
            shadowColor: "#70000000"
            shadowOpacity: 0.24
            shadowBlur: 1.0
            blurMax: 40
            blurMultiplier: 1.0
            shadowHorizontalOffset: 0
            shadowVerticalOffset: desktop.p(3.5)
            shadowScale: 1.015

            opacity: root.osdShown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 145
                    easing.type: Easing.OutCubic
                }
            }
        }

        Rectangle {
            id: osdCard

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.osdShown
                ? desktop.s(34)
                : desktop.s(28)

            z: 2
            width: desktop.p(170)
            height: desktop.p(34)
            radius: desktop.p(9.5)

            color: "#F7F7F7"
            border.width: Math.max(1, desktop.p(0.55))
            border.color: "#22000000"
            opacity: root.osdShown ? 1 : 0

            Behavior on anchors.bottomMargin {
                NumberAnimation {
                    duration: 165
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 145
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: desktop.p(1)
                    leftMargin: desktop.p(8)
                    rightMargin: desktop.p(8)
                }

                height: Math.max(1, desktop.p(0.45))
                radius: height / 2
                color: "#5AFFFFFF"
                opacity: 0.55
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
                size: desktop.p(16)
                iconOpacity: 0.80
            }

            Rectangle {
                id: osdLevelBar

                anchors {
                    left: osdIcon.right
                    leftMargin: desktop.p(12)
                    right: parent.right
                    rightMargin: desktop.p(14)
                    verticalCenter: parent.verticalCenter
                }

                height: desktop.p(3)
                radius: height / 2
                color: "#D1D1D1"

                Rectangle {
                    width: parent.width * root.osdLevel
                    height: parent.height
                    radius: parent.radius
                    color: "#686868"
                }
            }
        }
    }


}
