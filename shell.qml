import Quickshell
import QtQuick
import QtQuick.Controls

ShellRoot {
    FloatingWindow {
        id: desktop

        visible: true
        fullscreen: true
        implicitWidth: 1180
        implicitHeight: 663
        title: "Precision Shell — Home V6"
        color: "#F6F1E8"

        readonly property real designWidth: 1180
        readonly property real designHeight: 663
        readonly property real uiScale: Math.min(width / designWidth, height / designHeight)
        readonly property real panelScale: uiScale * 1.09

        function s(value) {
            return value * uiScale
        }

        function p(value) {
            return value * panelScale
        }

        property int viewState: 4
        property date now: new Date()

        readonly property color ivory: "#F6F1E8"
        readonly property color warmWhite: "#FBF9F5"
        readonly property color sand: "#D8CCBC"
        readonly property color graphite: "#302D29"
        readonly property color softInk: "#6D675F"
        readonly property color mutedInk: "#948B82"
        readonly property color panelBorder: "#62CFC4B6"
        readonly property color panelSurface: "#E7FBF9F5"

        property var appItems: [
            { "icon": "browser.svg",  "title": "Browse",   "subtitle": "Internet" },
            { "icon": "terminal.svg", "title": "Terminal", "subtitle": "System" },
            { "icon": "files.svg",    "title": "Files",    "subtitle": "Documents" },
            { "icon": "notes.svg",    "title": "Notes",    "subtitle": "Quick capture" },
            { "icon": "calendar.svg", "title": "Calendar", "subtitle": "Schedule" },
            { "icon": "mail.svg",     "title": "Mail",     "subtitle": "Inbox" }
        ]

        Timer {
            interval: 30000
            running: true
            repeat: true
            onTriggered: desktop.now = new Date()
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
            onActivated: desktop.viewState = 1
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

                height: desktop.s(42)
                color: "#F8FBF9F5"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: Math.max(1, desktop.s(0.7))
                    color: "#40D8CCBC"
                }

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: desktop.s(18)
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: desktop.s(22)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/system-mark.svg")
                        size: desktop.s(14)
                        iconOpacity: 0.94
                    }

                    Item {
                        width: desktop.s(42)
                        height: desktop.s(26)

                        Text {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                                topMargin: desktop.s(2)
                            }

                            text: "Home"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: desktop.s(10)
                            font.weight: Font.Medium
                        }

                        Rectangle {
                            width: desktop.s(2.4)
                            height: desktop.s(2.4)
                            radius: desktop.s(1.2)
                            color: desktop.softInk

                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: desktop.s(1)
                            }
                        }
                    }

                    Text {
                        text: "Work"
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(10)
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: Qt.formatDateTime(desktop.now, "ddd, MMM d    h:mm AP")
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(9)
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: desktop.s(16)
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: desktop.s(12)

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/volume.svg")
                        size: desktop.s(13)
                        iconOpacity: 0.9
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/wifi.svg")
                        size: desktop.s(13)
                        iconOpacity: 0.9
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/battery.svg")
                        size: desktop.s(15)
                        iconOpacity: 0.9
                    }

                    Text {
                        text: "100%"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(9)
                    }
                }
            }

            Column {
                x: desktop.s(140)
                y: desktop.s(211)
                spacing: desktop.s(0)

                Text {
                    text: "Focus"
                    color: desktop.graphite
                    font.family: "Inter"
                    font.pixelSize: desktop.s(32)
                    font.weight: Font.Light
                }

                Text {
                    text: "is a form of precision."
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(30)
                    font.weight: Font.Light
                }

                Text {
                    topPadding: desktop.s(18)
                    text: "Good evening, Alexis."
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(9.2)
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
                        size: desktop.s(21)
                        iconOpacity: 0.92
                    }

                    Text {
                        text: "18°"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(20)
                        font.weight: Font.Light
                    }
                }

                Text {
                    text: "Versailles"
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(8.8)
                }

                Text {
                    text: "Sunny"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(8.8)
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
                        size: desktop.s(13)
                        iconOpacity: 0.88
                    }

                    Text {
                        text: "Design system"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: desktop.s(8.8)
                    }
                }

                Text {
                    text: "in 40 min"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: desktop.s(8.8)
                }
            }

            Rectangle {
                id: libraryPanel

                property bool opened: desktop.viewState === 4

                anchors {
                    left: parent.left
                    leftMargin: desktop.p(26)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(28)
                }

                width: desktop.p(152)
                height: desktop.p(174)
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

                    spacing: desktop.p(13)

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
                        height: desktop.p(9)
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
                    bottomMargin: desktop.p(93)
                }

                width: desktop.p(586)
                height: desktop.p(130)
                radius: desktop.p(11)

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

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: desktop.p(12)
                    }

                    spacing: desktop.p(26)

                    Repeater {
                        model: desktop.appItems

                        delegate: Column {
                            width: desktop.p(64)
                            spacing: desktop.p(3)

                            PremiumIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Qt.resolvedUrl("icons/" + modelData.icon)
                                size: desktop.p(20)
                                iconOpacity: 0.94
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.title
                                color: desktop.graphite
                                font.family: "Inter"
                                font.pixelSize: desktop.p(8)
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.subtitle
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: desktop.p(6.5)
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
                    rightMargin: desktop.p(24)
                    bottom: parent.bottom
                    bottomMargin: desktop.p(28)
                }

                width: desktop.p(166)
                height: desktop.p(174)
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

                    Repeater {
                        model: [
                            {
                                "icon": "wifi.svg",
                                "label": "Wi-Fi",
                                "state": "Studio",
                                "enabled": true
                            },
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
                                color: modelData.enabled ? desktop.graphite : desktop.softInk
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
                                color: modelData.enabled ? desktop.softInk : "#B9B1A8"

                                Rectangle {
                                    width: desktop.p(7)
                                    height: desktop.p(7)
                                    radius: width / 2
                                    color: desktop.warmWhite
                                    anchors {
                                        verticalCenter: parent.verticalCenter
                                        right: modelData.enabled ? parent.right : undefined
                                        left: modelData.enabled ? undefined : parent.left
                                        rightMargin: modelData.enabled ? desktop.p(2) : 0
                                        leftMargin: modelData.enabled ? 0 : desktop.p(2)
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

                        Rectangle {
                            anchors {
                                left: volumeLeft.right
                                leftMargin: desktop.p(7)
                                right: volumeRight.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }
                            height: desktop.p(1.6)
                            radius: height / 2
                            color: "#CBC1B5"

                            Rectangle {
                                width: parent.width * 0.56
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }

                            Rectangle {
                                x: parent.width * 0.56 - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: desktop.p(7)
                                height: desktop.p(7)
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

                        Rectangle {
                            anchors {
                                left: brightnessLeft.right
                                leftMargin: desktop.p(7)
                                right: brightnessRight.left
                                rightMargin: desktop.p(7)
                                verticalCenter: parent.verticalCenter
                            }
                            height: desktop.p(1.6)
                            radius: height / 2
                            color: "#CBC1B5"

                            Rectangle {
                                width: parent.width * 0.34
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }

                            Rectangle {
                                x: parent.width * 0.34 - width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                width: desktop.p(7)
                                height: desktop.p(7)
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
    }
}
