import QtQuick

Rectangle {
    id: root
    implicitWidth: 220
    implicitHeight: 180
    radius: 6
    color: root.backgroundColor

    property string title: "Device Status"
    property string statusText: "NORMAL"
    property string lineName: "Line A"
    property string deviceName: "Raspberry Pi 4"
    property color statusColor: "#2f9e44"
    property color backgroundColor: "#2b3038"
    property color textColor: "white"
    property color secondaryTextColor: "#c9d1d9"

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        Text {
            text: root.title
            color: root.textColor
            font.pixelSize: 20
        }

        Rectangle {
            width: parent.width
            height: 44
            radius: 4
            color: root.statusColor
            scale: root.statusText === "WARNING" ? 1.04 : 1.0

            Behavior on color {
                ColorAnimation { duration: 220 }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.statusText
                color: root.textColor
                font.pixelSize: 18
            }
        }

        Text {
            text: root.lineName
            color: root.secondaryTextColor
            font.pixelSize: 16
        }

        Text {
            text: root.deviceName
            color: root.secondaryTextColor
            font.pixelSize: 16
        }
    }
}
