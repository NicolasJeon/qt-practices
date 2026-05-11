import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    width: ListView.view.width
    height: 48
    radius: 4
    color: index % 2 === 0 ? "#222831" : "#252b34"


    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8

        Rectangle {
            Layout.preferredWidth: 52
            Layout.preferredHeight: 24
            Layout.alignment: Qt.AlignVCenter
            radius: 3
            color: level === "WARN" ? "#d94848" : "#2f6f9e"

            Text {
                anchors.centerIn: parent
                text: level
                color: "white"
                font.pixelSize: 11
                font.bold: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 2

            Text {
                Layout.fillWidth: true
                text: message
                color: "white"
                elide: Text.ElideRight
                font.pixelSize: 13
            }

            Text {
                Layout.fillWidth: true
                text: time
                color: "#8b949e"
                font.pixelSize: 11
            }
        }
    }
}
