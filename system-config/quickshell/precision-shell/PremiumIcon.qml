import QtQuick

Item {
    id: root

    property alias source: icon.source
    property int size: 18
    property real iconOpacity: 1.0

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size

    Image {
        id: icon
        anchors.fill: parent
        sourceSize.width: root.size * 2
        sourceSize.height: root.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        opacity: root.iconOpacity
    }
}
