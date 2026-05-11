import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    implicitWidth: 260
    implicitHeight: 260
    radius: 6
    color: "#2b3038"

    property alias model: logView.model

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "Event Log"
            color: "white"
            font.pixelSize: 20
        }

        ListView {
            id: logView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            delegate: EventLogDelegate {}
        }
    }
}
