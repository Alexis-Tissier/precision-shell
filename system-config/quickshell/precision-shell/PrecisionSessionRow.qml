import Quickshell
import QtQuick

Item {
    id: root

    property real unit: 1
    property color graphite: "#302D29"
    property color softInk: "#6D675F"
    property color mutedInk: "#948B82"
    property color hoverSurface: "#30D8CCBC"
    property string helperPath: ""

    property bool menuOpen: false
    property string pendingAction: ""
    property string pendingLabel: ""

    readonly property bool confirming: pendingAction.length > 0

    height: unit * 28
    z: menuOpen || confirming ? 80 : 1

    function closeMenu() {
        menuOpen = false
        pendingAction = ""
        pendingLabel = ""
        autoClose.stop()
    }

    function runAction(action) {
        if (helperPath.length === 0)
            return

        Quickshell.execDetached({
            command: [helperPath, action]
        })

        closeMenu()
    }

    function requestAction(action, label, requiresConfirmation) {
        if (requiresConfirmation) {
            pendingAction = action
            pendingLabel = label
            autoClose.restart()
        } else {
            runAction(action)
        }
    }

    Timer {
        id: autoClose
        interval: 10000
        repeat: false
        onTriggered: root.closeMenu()
    }

    Rectangle {
        id: trigger

        anchors.fill: parent
        radius: root.unit * 5
        color: triggerMouse.containsMouse || root.menuOpen
            ? root.hoverSurface
            : "transparent"

        Text {
            anchors {
                left: parent.left
                leftMargin: root.unit * 4
                verticalCenter: parent.verticalCenter
            }

            text: "Session"
            color: root.softInk
            font.family: "Inter"
            font.pixelSize: root.unit * 7.4
            font.weight: Font.Medium
        }

        Text {
            anchors {
                right: parent.right
                rightMargin: root.unit * 4
                verticalCenter: parent.verticalCenter
            }

            text: root.menuOpen ? "Fermer" : "Ouvrir"
            color: root.mutedInk
            font.family: "Inter"
            font.pixelSize: root.unit * 6.4
        }

        MouseArea {
            id: triggerMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (root.menuOpen || root.confirming) {
                    root.closeMenu()
                } else {
                    root.menuOpen = true
                    autoClose.restart()
                }
            }
        }
    }

    Rectangle {
        id: menuCard

        visible: root.menuOpen || root.confirming

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.top
            bottomMargin: root.unit * 5
        }

        height: root.confirming
            ? root.unit * 70
            : root.unit * 122

        radius: root.unit * 7
        color: "#FFFBF8F3"
        border.width: Math.max(1, root.unit * 0.65)
        border.color: "#70CFC4B6"
        z: 100

        Behavior on height {
            NumberAnimation {
                duration: 140
                easing.type: Easing.OutCubic
            }
        }

        Column {
            anchors {
                fill: parent
                margins: root.unit * 5
            }

            visible: !root.confirming
            spacing: root.unit * 1

            Repeater {
                model: [
                    {
                        "label": "Verrouiller",
                        "action": "lock",
                        "confirm": false
                    },
                    {
                        "label": "Mettre en veille",
                        "action": "suspend",
                        "confirm": false
                    },
                    {
                        "label": "Fermer la session",
                        "action": "logout",
                        "confirm": true
                    },
                    {
                        "label": "Redémarrer",
                        "action": "reboot",
                        "confirm": true
                    },
                    {
                        "label": "Éteindre",
                        "action": "poweroff",
                        "confirm": true
                    }
                ]

                delegate: Item {
                    required property var modelData

                    width: parent.width
                    height: root.unit * 21

                    Rectangle {
                        anchors.fill: parent
                        radius: root.unit * 4
                        color: menuMouse.containsMouse
                            ? root.hoverSurface
                            : "transparent"
                    }

                    Text {
                        anchors {
                            left: parent.left
                            leftMargin: root.unit * 5
                            verticalCenter: parent.verticalCenter
                        }

                        text: modelData.label
                        color: menuMouse.containsMouse
                            ? root.graphite
                            : root.softInk
                        font.family: "Inter"
                        font.pixelSize: root.unit * 7
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: menuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.requestAction(
                            modelData.action,
                            modelData.label,
                            modelData.confirm
                        )
                    }
                }
            }
        }

        Column {
            anchors {
                fill: parent
                margins: root.unit * 8
            }

            visible: root.confirming
            spacing: root.unit * 7

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.pendingLabel + " ?"
                color: root.graphite
                font.family: "Inter"
                font.pixelSize: root.unit * 7.6
                font.weight: Font.Medium
            }

            Row {
                width: parent.width
                height: root.unit * 23
                spacing: root.unit * 4

                Item {
                    width: (parent.width - root.unit * 4) / 2
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: root.unit * 4
                        color: cancelMouse.containsMouse
                            ? root.hoverSurface
                            : "transparent"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Annuler"
                        color: root.softInk
                        font.family: "Inter"
                        font.pixelSize: root.unit * 6.6
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: {
                            root.pendingAction = ""
                            root.pendingLabel = ""
                            root.menuOpen = true
                            autoClose.restart()
                        }
                    }
                }

                Item {
                    width: (parent.width - root.unit * 4) / 2
                    height: parent.height

                    Rectangle {
                        anchors.fill: parent
                        radius: root.unit * 4
                        color: confirmMouse.containsMouse
                            ? "#45B49A86"
                            : "#24B49A86"
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Confirmer"
                        color: root.graphite
                        font.family: "Inter"
                        font.pixelSize: root.unit * 6.6
                        font.weight: Font.Medium
                    }

                    MouseArea {
                        id: confirmMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.runAction(root.pendingAction)
                    }
                }
            }
        }
    }
}
