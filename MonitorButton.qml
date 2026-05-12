import QtQuick

Rectangle {
    id: root
    implicitWidth: 160
    implicitHeight: 40
    radius: 4
    color: mouseArea.pressed ? root.pressedColor : root.normalColor

    property string label: "Button"
    property color normalColor: "#2f6f9e"
    property color pressedColor: "#49515d"
    property color textColor: "white"

    signal clicked()

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.textColor
        font.pixelSize: 16
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
