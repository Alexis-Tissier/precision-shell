import Quickshell.Services.Mpris
import QtQuick

Item {
    id: root

    property real unit: 1
    property color graphite: "#302D29"
    property color softInk: "#6D675F"
    property color mutedInk: "#948B82"
    property color hoverSurface: "#30D8CCBC"

    readonly property var player: {
        const players = Mpris.players.values
        let fallback = null

        for (let index = 0; index < players.length; index++) {
            const candidate = players[index]

            if (candidate === null || candidate === undefined)
                continue

            if (candidate.isPlaying)
                return candidate

            if (fallback === null
                    && ((candidate.trackTitle || "").length > 0
                        || candidate.playbackState !== MprisPlaybackState.Stopped)) {
                fallback = candidate
            }
        }

        return fallback
    }

    visible: player !== null
    height: visible ? unit * 35 : 0

    Rectangle {
        anchors.fill: parent
        radius: root.unit * 5
        color: mediaMouse.containsMouse ? root.hoverSurface : "transparent"
    }

    Item {
        id: metadataArea

        anchors {
            left: parent.left
            right: controls.left
            rightMargin: root.unit * 7
            top: parent.top
            bottom: parent.bottom
        }

        Column {
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
            }

            spacing: root.unit * 1.5

            Text {
                width: parent.width
                text: root.player !== null
                    ? (root.player.trackTitle
                        || root.player.identity
                        || "Media")
                    : ""
                color: root.graphite
                font.family: "Inter"
                font.pixelSize: root.unit * 8.1
                font.weight: Font.Medium
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            Text {
                width: parent.width
                text: root.player !== null
                    ? (root.player.trackArtist
                        || root.player.identity
                        || "Lecture multimédia")
                    : ""
                color: root.mutedInk
                font.family: "Inter"
                font.pixelSize: root.unit * 6.9
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        MouseArea {
            id: mediaMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.player !== null && root.player.canRaise
                ? Qt.PointingHandCursor
                : Qt.ArrowCursor
            enabled: root.player !== null
            onClicked: {
                if (root.player.canRaise)
                    root.player.raise()
            }
        }
    }

    Row {
        id: controls

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        spacing: root.unit * 2

        Item {
            width: root.unit * 16
            height: root.unit * 22
            opacity: root.player !== null && root.player.canGoPrevious ? 1 : 0.28

            Text {
                anchors.centerIn: parent
                text: "‹"
                color: root.softInk
                font.family: "Inter"
                font.pixelSize: root.unit * 17
                font.weight: Font.Light
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player !== null && root.player.canGoPrevious
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.player.previous()
            }
        }

        Item {
            width: root.unit * 18
            height: root.unit * 22
            opacity: root.player !== null && root.player.canTogglePlaying ? 1 : 0.28

            Rectangle {
                anchors.centerIn: parent
                width: root.unit * 18
                height: root.unit * 18
                radius: width / 2
                color: playMouse.containsMouse ? root.hoverSurface : "transparent"
                border.width: root.unit * 0.7
                border.color: "#80AFA69D"
            }

            Text {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset:
                    root.player !== null && !root.player.isPlaying
                        ? root.unit * 0.7
                        : 0
                text: root.player !== null && root.player.isPlaying ? "Ⅱ" : "▶"
                color: root.graphite
                font.family: "Inter"
                font.pixelSize: root.unit * 8.5
                font.weight: Font.Medium
            }

            MouseArea {
                id: playMouse
                anchors.fill: parent
                enabled: root.player !== null && root.player.canTogglePlaying
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.player.togglePlaying()
            }
        }

        Item {
            width: root.unit * 16
            height: root.unit * 22
            opacity: root.player !== null && root.player.canGoNext ? 1 : 0.28

            Text {
                anchors.centerIn: parent
                text: "›"
                color: root.softInk
                font.family: "Inter"
                font.pixelSize: root.unit * 17
                font.weight: Font.Light
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.player !== null && root.player.canGoNext
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.player.next()
            }
        }
    }
}
