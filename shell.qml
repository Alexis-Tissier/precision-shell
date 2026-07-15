import Quickshell
import QtQuick

ShellRoot {
    FloatingWindow {
        id: desktop

        visible: true
        width: 1648
        height: 928
        fullscreen: true
        title: "Precision Shell — Home V2"
        color: "#F6F1E8"

        property int viewState: 4
        property date now: new Date()

        property color ivory: "#F6F1E8"
        property color warmWhite: "#FBF9F5"
        property color sand: "#D8CCBC"
        property color graphite: "#302D29"
        property color softInk: "#6D675F"
        property color mutedInk: "#948B82"
        property color panelBorder: "#88D8CCBC"

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

        Component.onCompleted: searchInput.forceActiveFocus()

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
            }

            Rectangle {
                anchors.fill: parent
                color: "#16F6F1E8"
            }

            Rectangle {
                id: topBar
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: 42
                color: "#F6FBF9F5"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }
                    height: 1
                    color: "#42D8CCBC"
                }

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 18
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 22

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/system-mark.svg")
                        size: 16
                    }

                    Item {
                        width: 42
                        height: 26

                        Text {
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                top: parent.top
                                topMargin: 2
                            }
                            text: "Home"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: 11
                        }

                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: desktop.softInk
                            anchors {
                                horizontalCenter: parent.horizontalCenter
                                bottom: parent.bottom
                                bottomMargin: 1
                            }
                        }
                    }

                    Text {
                        text: "Work"
                        color: desktop.mutedInk
                        font.family: "Inter"
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: Qt.formatDateTime(desktop.now, "ddd, MMM d    hh:mm AP")
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: 10
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 16
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 13

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/volume.svg")
                        size: 15
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/wifi.svg")
                        size: 15
                    }

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/battery.svg")
                        size: 17
                    }

                    Text {
                        text: "100%"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 10
                    }
                }
            }

            Column {
                x: parent.width * 0.118
                y: parent.height * 0.317
                spacing: 0

                Text {
                    text: "Focus"
                    color: desktop.graphite
                    font.family: "Inter"
                    font.pixelSize: 34
                    font.weight: Font.Light
                }

                Text {
                    text: "is a form of precision."
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: 32
                    font.weight: Font.Light
                }

                Text {
                    topPadding: 22
                    text: "Good evening, Alexis."
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: 10
                }
            }

            Column {
                anchors {
                    right: parent.right
                    rightMargin: parent.width * 0.078
                    top: parent.top
                    topMargin: parent.height * 0.145
                }
                spacing: 7

                Row {
                    spacing: 9

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/brightness.svg")
                        size: 22
                    }

                    Text {
                        text: "18°"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 20
                        font.weight: Font.Light
                    }
                }

                Text {
                    text: "Versailles"
                    color: desktop.softInk
                    font.family: "Inter"
                    font.pixelSize: 9
                }

                Text {
                    text: "Sunny"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: 9
                }

                Rectangle {
                    width: 72
                    height: 1
                    color: "#60D8CCBC"
                }

                Row {
                    spacing: 7

                    PremiumIcon {
                        source: Qt.resolvedUrl("icons/calendar.svg")
                        size: 13
                    }

                    Text {
                        text: "Design system"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 9
                    }
                }

                Text {
                    text: "in 40 min"
                    color: desktop.mutedInk
                    font.family: "Inter"
                    font.pixelSize: 9
                }
            }

            Rectangle {
                id: libraryPanel
                property bool opened: desktop.viewState === 4

                anchors {
                    left: parent.left
                    leftMargin: 26
                    bottom: parent.bottom
                    bottomMargin: 27
                }

                width: 148
                height: 174
                radius: 10
                color: "#EFFBF9F5"
                border.width: 1
                border.color: desktop.panelBorder

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: 15
                    }
                    spacing: 13

                    Text {
                        text: "Apps"
                        color: desktop.graphite
                        font.family: "Inter"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "Recent"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 9
                    }

                    Text {
                        text: "Documents"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 9
                    }

                    Text {
                        text: "Downloads"
                        color: desktop.softInk
                        font.family: "Inter"
                        font.pixelSize: 9
                    }

                    Item { width: 1; height: 9 }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#55D8CCBC"
                    }

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - 20
                            text: "Show All"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: 9
                        }

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/expand.svg")
                            size: 13
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
                    bottomMargin: 99
                }

                width: Math.min(parent.width * 0.48, 568)
                height: 125
                radius: 11
                color: "#EFFBF9F5"
                border.width: 1
                border.color: desktop.panelBorder
                clip: true

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation { duration: 165; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 165; easing.type: Easing.OutCubic }
                }

                Item {
                    anchors {
                        top: parent.top
                        left: parent.left
                        right: parent.right
                    }
                    height: 43

                    PremiumIcon {
                        anchors {
                            left: parent.left
                            leftMargin: 16
                            verticalCenter: parent.verticalCenter
                        }
                        source: Qt.resolvedUrl("icons/search.svg")
                        size: 15
                    }

                    TextInput {
                        id: searchInput
                        anchors {
                            left: parent.left
                            leftMargin: 42
                            right: parent.right
                            rightMargin: 48
                            verticalCenter: parent.verticalCenter
                        }

                        height: 25
                        color: desktop.graphite
                        selectionColor: desktop.sand
                        selectedTextColor: desktop.graphite
                        font.family: "Inter"
                        font.pixelSize: 10
                        selectByMouse: true
                        cursorVisible: activeFocus
                    }

                    Text {
                        anchors {
                            left: searchInput.left
                            verticalCenter: searchInput.verticalCenter
                        }
                        visible: searchInput.text.length === 0
                        text: "Search or type a command..."
                        color: "#A19990"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 15
                            verticalCenter: parent.verticalCenter
                        }
                        text: "⌘ K"
                        color: "#A89F96"
                        font.family: "Inter"
                        font.pixelSize: 8
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 43
                    }
                    height: 1
                    color: "#5AD8CCBC"
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 12
                    }
                    spacing: 26

                    Repeater {
                        model: desktop.appItems

                        delegate: Column {
                            width: 64
                            spacing: 4

                            PremiumIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: Qt.resolvedUrl("icons/" + modelData.icon)
                                size: 21
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.title
                                color: desktop.graphite
                                font.family: "Inter"
                                font.pixelSize: 9
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.subtitle
                                color: desktop.mutedInk
                                font.family: "Inter"
                                font.pixelSize: 7
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
                    rightMargin: 26
                    bottom: parent.bottom
                    bottomMargin: 27
                }

                width: 174
                height: 174
                radius: 10
                color: "#EFFBF9F5"
                border.width: 1
                border.color: desktop.panelBorder

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened

                Behavior on opacity {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Behavior on scale {
                    NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: 13
                    }
                    spacing: 9

                    Row {
                        width: parent.width
                        spacing: 9

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/wifi.svg")
                            size: 14
                        }

                        Text {
                            width: 85
                            text: "Wi-Fi"
                            color: desktop.graphite
                            font.family: "Inter"
                            font.pixelSize: 9
                        }

                        Text {
                            width: 31
                            text: "Studio"
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: 8
                        }

                        Rectangle {
                            width: 22
                            height: 12
                            radius: 6
                            color: desktop.softInk

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: desktop.warmWhite
                                anchors {
                                    right: parent.right
                                    rightMargin: 2
                                    verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 9

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/bluetooth.svg")
                            size: 14
                        }

                        Text {
                            width: 85
                            text: "Bluetooth"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: 9
                        }

                        Text {
                            width: 31
                            text: "On"
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: 8
                        }

                        Rectangle {
                            width: 22
                            height: 12
                            radius: 6
                            color: desktop.softInk

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: desktop.warmWhite
                                anchors {
                                    right: parent.right
                                    rightMargin: 2
                                    verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 9

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/moon.svg")
                            size: 14
                        }

                        Text {
                            width: 85
                            text: "Do Not Disturb"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: 9
                        }

                        Text {
                            width: 31
                            text: "Off"
                            horizontalAlignment: Text.AlignRight
                            color: desktop.mutedInk
                            font.family: "Inter"
                            font.pixelSize: 8
                        }

                        Rectangle {
                            width: 22
                            height: 12
                            radius: 6
                            color: "#B6AEA5"

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: desktop.warmWhite
                                anchors {
                                    left: parent.left
                                    leftMargin: 2
                                    verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#5AD8CCBC"
                    }

                    Row {
                        width: parent.width
                        spacing: 9

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/display.svg")
                            size: 14
                        }

                        Text {
                            width: parent.width - 33
                            text: "Display"
                            color: desktop.softInk
                            font.family: "Inter"
                            font.pixelSize: 9
                        }

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/chevron-right.svg")
                            size: 12
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/volume.svg")
                            size: 14
                        }

                        Rectangle {
                            width: 100
                            height: 2
                            radius: 1
                            color: "#CBC1B5"

                            Rectangle {
                                width: 56
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: desktop.warmWhite
                                border.width: 1
                                border.color: "#AFA69D"
                                anchors {
                                    left: parent.left
                                    leftMargin: 52
                                    verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/volume.svg")
                            size: 12
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/brightness.svg")
                            size: 14
                        }

                        Rectangle {
                            width: 100
                            height: 2
                            radius: 1
                            color: "#CBC1B5"

                            Rectangle {
                                width: 35
                                height: parent.height
                                radius: parent.radius
                                color: desktop.softInk
                            }

                            Rectangle {
                                width: 8
                                height: 8
                                radius: 4
                                color: desktop.warmWhite
                                border.width: 1
                                border.color: "#AFA69D"
                                anchors {
                                    left: parent.left
                                    leftMargin: 31
                                    verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        PremiumIcon {
                            source: Qt.resolvedUrl("icons/brightness.svg")
                            size: 12
                        }
                    }
                }
            }
        }
    }
}
