import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: window
    width: 900
    height: 540
    visible: true
    title: "Equipment Monitor"

    property string cameraName: "Camera 01"
    property bool warning: false
    property color statusColor: warning ? "#d94848" : "#2f9e44"
    property string statusText: warning ? "WARNING" : "NORMAL"

    Rectangle {
        anchors.fill: parent
        color: "#20242a"

        Label {
            id: titleText
            x: 24
            y: 20
            text: "Equipment Video Monitor"
            color: "white"
            font.pixelSize: 28
        }

        Rectangle {
            id: videoArea
            x: 24
            y: 76
            width: parent.width - 48
            height: parent.height - 160
            color: "#111418"
            border.color: window.statusColor

            Text {
                anchors.centerIn: parent
                text: window.cameraName
                color: "#c9d1d9"
                font.pixelSize: 32
            }
        }

        Rectangle {
            x: 24
            y: parent.height - 64
            width: 180
            height: 40
            radius: 4
            color: window.statusColor

            Text {
                anchors.centerIn: parent
                text: window.statusText
                color: "white"
                font.pixelSize: 18
            }
        }

        Rectangle {
            x: 220
            y: parent.height - 64
            width: 160
            height: 40
            radius: 4
            color: toggleArea.pressed ? "#49515d" : "#2f6f9e"

            Text {
                anchors.centerIn: parent
                text: "Toggle Alert"
                color: "white"
                font.pixelSize: 16
            }

            MouseArea {
                id: toggleArea
                anchors.fill: parent
                onClicked: window.warning = !window.warning
            }
        }

        Button {
            x: 396
            y: parent.height - 64
            width: 140
            height: 40
            text: "Set Normal"
            onClicked: window.warning = false
        }
    }
}
