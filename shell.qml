import Quickshell
import QtQuick

ShellRoot {
    FloatingWindow {
        id: desktop

        visible: true
        width: 1600
        height: 900
        fullscreen: true
        title: "Precision Shell — Prototype GNOME"
        color: "#F6F1E8"

        /*
         * États :
         * 1 = home au repos
         * 2 = palette universelle
         * 3 = réglages rapides
         * 4 = vue de référence avec tous les panneaux
         */
        property int viewState: 4
        property date now: new Date()

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
            id: background
            anchors.fill: parent

            gradient: Gradient {
                GradientStop {
                    position: 0.0
                    color: "#F8F4EC"
                }

                GradientStop {
                    position: 0.55
                    color: "#EEE6DA"
                }

                GradientStop {
                    position: 1.0
                    color: "#DDD0BE"
                }
            }

            /*
             * Image optionnelle :
             * ~/.config/quickshell/precision-prototype/assets/wallpaper.jpg
             */
            Image {
                id: wallpaper

                anchors.fill: parent
                source: Qt.resolvedUrl("assets/wallpaper.jpg")
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false

                opacity: status === Image.Ready ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                    }
                }
            }

            /*
             * Voile chaud pour garder la lisibilité,
             * même avec une photographie contrastée.
             */
            Rectangle {
                anchors.fill: parent
                color: wallpaper.status === Image.Ready
                       ? "#28F6F1E8"
                       : "transparent"
            }

            /*
             * Emplacement provisoire de la photographie.
             */
            Column {
                visible: wallpaper.status !== Image.Ready

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    verticalCenter: parent.verticalCenter
                }

                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "911"
                    color: "#B9AC99"
                    font.family: "Inter"
                    font.pixelSize: 86
                    font.weight: Font.Light
                    font.letterSpacing: 12
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 250
                    height: 1
                    color: "#C9BCAA"
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "assets/wallpaper.jpg"
                    color: "#847B70"
                    font.family: "Inter"
                    font.pixelSize: 12
                    font.letterSpacing: 1
                }
            }

            /*
             * Bande supérieure.
             */
            Rectangle {
                id: topBar

                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }

                height: 43
                color: "#EAFBF9F5"

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                    }

                    height: 1
                    color: "#45CFC4B6"
                }

                Row {
                    anchors {
                        left: parent.left
                        leftMargin: 28
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: 24

                    Text {
                        text: "⌁"
                        color: "#302D29"
                        font.pixelSize: 15
                    }

                    Text {
                        text: "Home"
                        color: "#302D29"
                        font.family: "Inter"
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Work"
                        color: "#817A72"
                        font.family: "Inter"
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.centerIn: parent

                    text: Qt.formatDateTime(
                              desktop.now,
                              "ddd d MMM  ·  hh:mm"
                          )

                    color: "#6D675F"
                    font.family: "Inter"
                    font.pixelSize: 11
                }

                Row {
                    anchors {
                        right: parent.right
                        rightMargin: 28
                        verticalCenter: parent.verticalCenter
                    }

                    spacing: 17

                    Text {
                        text: "⌁"
                        color: "#6D675F"
                        font.pixelSize: 12
                    }

                    Text {
                        text: "◉"
                        color: "#6D675F"
                        font.pixelSize: 10
                    }

                    Text {
                        text: "▰"
                        color: "#6D675F"
                        font.pixelSize: 11
                    }

                    Text {
                        text: "100%"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }
                }
            }

            /*
             * Phrase principale.
             */
            Column {
                x: parent.width * 0.145
                y: parent.height * 0.355
                spacing: 1

                Text {
                    text: "Focus"
                    color: "#302D29"
                    font.family: "Inter"
                    font.pixelSize: Math.max(27, parent.parent.width * 0.019)
                    font.weight: Font.Light
                }

                Text {
                    text: "is a form of precision."
                    color: "#615B54"
                    font.family: "Inter"
                    font.pixelSize: Math.max(25, parent.parent.width * 0.018)
                    font.weight: Font.Light
                }

                Text {
                    topPadding: 16
                    text: "Good evening."
                    color: "#8B837A"
                    font.family: "Inter"
                    font.pixelSize: 10
                    font.letterSpacing: 0.6
                }
            }

            /*
             * Information contextuelle optionnelle.
             */
            Column {
                anchors {
                    right: parent.right
                    rightMargin: parent.width * 0.08
                    top: parent.top
                    topMargin: parent.height * 0.18
                }

                spacing: 5

                Text {
                    text: "☼  18°"
                    color: "#514C46"
                    font.family: "Inter"
                    font.pixelSize: 18
                    font.weight: Font.Light
                }

                Text {
                    text: "Versailles"
                    color: "#6D675F"
                    font.family: "Inter"
                    font.pixelSize: 10
                }

                Text {
                    topPadding: 14
                    text: "□  Design system"
                    color: "#6D675F"
                    font.family: "Inter"
                    font.pixelSize: 10
                }

                Text {
                    text: "in 40 min"
                    color: "#938B82"
                    font.family: "Inter"
                    font.pixelSize: 9
                }
            }

            /*
             * Bibliothèque latérale.
             */
            Rectangle {
                id: libraryPanel

                property bool opened: desktop.viewState === 4

                anchors {
                    left: parent.left
                    leftMargin: 38
                    bottom: parent.bottom
                    bottomMargin: 56
                }

                width: 122
                height: 172
                radius: 9

                color: "#F2FBF9F5"
                border.width: 1
                border.color: "#80D8CCBC"

                opacity: opened ? 1 : 0
                y: opened ? parent.height - height - 56
                          : parent.height - height - 46

                enabled: opened

                Behavior on opacity {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 170
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: 18
                    }

                    spacing: 15

                    Text {
                        text: "Apps"
                        color: "#302D29"
                        font.family: "Inter"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                    }

                    Text {
                        text: "Recent"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Text {
                        text: "Documents"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Text {
                        text: "Downloads"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Item {
                        width: 1
                        height: 6
                    }

                    Text {
                        text: "Show all        ·"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }
                }
            }

            /*
             * Palette universelle.
             */
            Rectangle {
                id: commandPalette

                property bool opened: desktop.viewState === 2
                                      || desktop.viewState === 4

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: 58
                }

                width: Math.min(parent.width * 0.48, 720)
                height: 124
                radius: 11

                color: "#F4FBF9F5"
                border.width: 1
                border.color: "#98D8CCBC"

                opacity: opened ? 1 : 0
                scale: opened ? 1 : 0.985
                enabled: opened
                clip: true

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

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                    }

                    height: 47
                    color: "transparent"

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: 19
                            verticalCenter: parent.verticalCenter
                        }

                        text: "⌕"
                        color: "#817A72"
                        font.pixelSize: 15
                    }

                    TextInput {
                        id: searchInput

                        anchors {
                            left: parent.left
                            leftMargin: 45
                            right: parent.right
                            rightMargin: 52
                            verticalCenter: parent.verticalCenter
                        }

                        height: 28
                        color: "#302D29"
                        selectionColor: "#D8CCBC"
                        selectedTextColor: "#302D29"

                        font.family: "Inter"
                        font.pixelSize: 11

                        selectByMouse: true
                        cursorVisible: activeFocus
                    }

                    Text {
                        anchors {
                            left: searchInput.left
                            verticalCenter: searchInput.verticalCenter
                        }

                        visible: searchInput.text.length === 0

                        text: "Search or type a command…"
                        color: "#9A9289"
                        font.family: "Inter"
                        font.pixelSize: 11
                    }

                    Text {
                        anchors {
                            right: parent.right
                            rightMargin: 18
                            verticalCenter: parent.verticalCenter
                        }

                        text: "⌘ K"
                        color: "#AAA198"
                        font.family: "Inter"
                        font.pixelSize: 9
                    }
                }

                Rectangle {
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 47
                    }

                    height: 1
                    color: "#70D8CCBC"
                }

                Row {
                    anchors {
                        horizontalCenter: parent.horizontalCenter
                        bottom: parent.bottom
                        bottomMargin: 15
                    }

                    spacing: 42

                    Repeater {
                        model: [
                            { "icon": "◉", "label": "Browse" },
                            { "icon": ">_", "label": "Terminal" },
                            { "icon": "□", "label": "Files" },
                            { "icon": "◇", "label": "Notes" },
                            { "icon": "▦", "label": "Calendar" },
                            { "icon": "✉", "label": "Mail" }
                        ]

                        delegate: Column {
                            width: 62
                            spacing: 7

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter

                                text: modelData.icon
                                color: "#69625B"
                                font.family: "Inter"
                                font.pixelSize: 15
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter

                                text: modelData.label
                                color: "#4F4A45"
                                font.family: "Inter"
                                font.pixelSize: 9
                            }
                        }
                    }
                }
            }

            /*
             * Réglages rapides.
             */
            Rectangle {
                id: settingsPanel

                property bool opened: desktop.viewState === 3
                                      || desktop.viewState === 4

                anchors {
                    right: parent.right
                    rightMargin: 38
                    bottom: parent.bottom
                    bottomMargin: 56
                }

                width: 158
                height: 174
                radius: 9

                color: "#F2FBF9F5"
                border.width: 1
                border.color: "#80D8CCBC"

                opacity: opened ? 1 : 0
                y: opened ? parent.height - height - 56
                          : parent.height - height - 46

                enabled: opened

                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Behavior on y {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutCubic
                    }
                }

                Column {
                    anchors {
                        fill: parent
                        margins: 17
                    }

                    spacing: 11

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - 12
                            text: "Wi-Fi"
                            color: "#302D29"
                            font.family: "Inter"
                            font.pixelSize: 10
                        }

                        Text {
                            text: "●"
                            color: "#655F58"
                            font.pixelSize: 9
                        }
                    }

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - 12
                            text: "Bluetooth"
                            color: "#6D675F"
                            font.family: "Inter"
                            font.pixelSize: 10
                        }

                        Text {
                            text: "●"
                            color: "#8D857C"
                            font.pixelSize: 9
                        }
                    }

                    Row {
                        width: parent.width

                        Text {
                            width: parent.width - 12
                            text: "Do Not Disturb"
                            color: "#6D675F"
                            font.family: "Inter"
                            font.pixelSize: 10
                        }

                        Text {
                            text: "○"
                            color: "#8D857C"
                            font.pixelSize: 9
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: 1
                        color: "#70D8CCBC"
                    }

                    Text {
                        text: "Display"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 2
                        color: "#D8CCBC"

                        Rectangle {
                            width: parent.width * 0.64
                            height: parent.height
                            radius: parent.radius
                            color: "#6D675F"
                        }
                    }

                    Text {
                        text: "Audio"
                        color: "#6D675F"
                        font.family: "Inter"
                        font.pixelSize: 10
                    }

                    Rectangle {
                        width: parent.width
                        height: 3
                        radius: 2
                        color: "#D8CCBC"

                        Rectangle {
                            width: parent.width * 0.43
                            height: parent.height
                            radius: parent.radius
                            color: "#6D675F"
                        }
                    }
                }
            }
        }
    }
}
