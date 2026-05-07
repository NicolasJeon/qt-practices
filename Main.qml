import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Label {
                text: "Equipment Video Monitor"
                color: "white"
                font.pixelSize: 28
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                Rectangle {
                    id: videoArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
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
                    Layout.preferredWidth: 220
                    Layout.fillHeight: true
                    radius: 6
                    color: "#2b3038"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12

                        Text {
                            text: "Device Status"
                            color: "white"
                            font.pixelSize: 20
                        }

                        Rectangle {
                            width: parent.width
                            height: 44
                            radius: 4
                            color: window.statusColor

                            Text {
                                anchors.centerIn: parent
                                text: window.statusText
                                color: "white"
                                font.pixelSize: 18
                            }
                        }

                        Text {
                            text: "Line A"
                            color: "#c9d1d9"
                            font.pixelSize: 16
                        }

                        Text {
                            text: "Raspberry Pi 4"
                            color: "#c9d1d9"
                            font.pixelSize: 16
                        }
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 12

                Rectangle {
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
                    width: 140
                    height: 40
                    text: "Set Normal"
                    onClicked: window.warning = false
                }
            }
        }
    }
}
