import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQml
import QtQml.Models

ApplicationWindow {
    id: window
    width: 1024
    height: 600
    visible: true
    title: "Equipment Monitor"

    ListModel {
        id: cameraModel

        ListElement { camera: "Camera 01"; location: "Line A"; cameraState: MonitorEnums.CameraState.Normal }
        ListElement { camera: "Camera 02"; location: "Line B"; cameraState: MonitorEnums.CameraState.Normal }
        ListElement { camera: "Camera 03"; location: "Line C"; cameraState: MonitorEnums.CameraState.Warning }
    }

    EventLogModel {
        id: eventLogModel
        maxCount: 8
    }

    property int selectedCamera: 0
    property string cameraName: cameraModel.get(selectedCamera).camera
    property string cameraLocation: cameraModel.get(selectedCamera).location
    property bool warning: false
    property string statusText: warning ? "WARNING" : "NORMAL"
    property color statusColor: warning ? colors.statusWarning : colors.statusNormal

    QtObject {
        id: colors
        readonly property color appBackground: "#20242a"
        readonly property color videoBackground: "#111418"
        readonly property color panelBackground: "#2b3038"
        readonly property color textPrimary: "white"
        readonly property color textSecondary: "#c9d1d9"
        readonly property color statusNormal: "#2f9e44"
        readonly property color statusWarning: "#d94848"
        readonly property color buttonNormal: "#2f6f9e"
        readonly property color buttonPressed: "#49515d"
        readonly property color buttonWarning: "#7f3b3b"
    }

    function selectCamera(index) {
        if (selectedCamera === index)
            return

        var camera = cameraModel.get(index).camera
        selectedCamera = index
        warning = cameraModel.get(index).cameraState === MonitorEnums.CameraState.Warning
        addEvent(MonitorEnums.EventLevel.Info, camera + " selected")
    }

    function setWarning(value) {
        if (warning === value)
            return

        warning = value
        cameraModel.setProperty(selectedCamera, "cameraState",
                                value ? MonitorEnums.CameraState.Warning : MonitorEnums.CameraState.Normal)
        addEvent(value ? MonitorEnums.EventLevel.Warn : MonitorEnums.EventLevel.Info,
                 cameraName + (value ? " warning detected" : " returned to normal"))
    }

    function addEvent(level, message) {
        eventLogModel.addEvent(level, message)
    }

    Rectangle {
        anchors.fill: parent
        color: colors.appBackground

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            Label {
                text: "Equipment Video Monitor"
                color: colors.textPrimary
                font.pixelSize: 28
                Layout.fillWidth: true
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 16

                Component {
                    id: component_videoArea

                    Rectangle {
                        id: videoArea
                        color: colors.videoBackground
                        radius: 6
                        border.color: window.statusColor
                        border.width: window.warning ? 4 : 2
                        clip: true

                        property real statusOpacity: 0.06
                        property bool blinkOn: false

                        Timer {
                            interval: 500
                            running: window.warning
                            repeat: true
                            onTriggered: videoArea.blinkOn = !videoArea.blinkOn
                            onRunningChanged: {
                                if (!running)
                                    videoArea.blinkOn = false
                            }
                        }

                        states: [
                            State {
                                name: "warning"
                                when: window.warning
                                PropertyChanges {
                                    videoArea.statusOpacity: 0.22
                                }
                            }
                        ]

                        transitions: [
                            Transition {
                                NumberAnimation {
                                    property: "statusOpacity"
                                    duration: 220
                                    easing.type: Easing.OutCubic
                                }
                            }
                        ]

                        Rectangle {
                            anchors.fill: parent
                            color: window.statusColor
                            opacity: videoArea.statusOpacity

                            Behavior on color {
                                ColorAnimation { duration: 220 }
                            }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            anchors.margins: 18
                            width: 18
                            height: 18
                            radius: 9
                            color: window.statusColor
                            opacity: videoArea.blinkOn ? 1.0 : 0.35

                            Behavior on color {
                                ColorAnimation { duration: 220 }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.InOutQuad
                                }
                            }
                        }

                        Column {
                            anchors.centerIn: parent
                            spacing: 8

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.cameraName
                                color: colors.textSecondary
                                font.pixelSize: 32
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: window.statusText
                                color: window.statusColor
                                font.pixelSize: 18

                                Behavior on color {
                                    ColorAnimation { duration: 220 }
                                }
                            }
                        }
                    }
                }

                Loader {
                    id: loader_videoArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: component_videoArea
                }

                ColumnLayout {
                    Layout.fillWidth: false
                    Layout.minimumWidth: 360
                    Layout.fillHeight: true
                    spacing: 16

                    StatusCard {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 180
                        statusText: window.statusText
                        statusColor: window.statusColor
                        lineName: window.cameraLocation
                        backgroundColor: colors.panelBackground
                        textColor: colors.textPrimary
                        secondaryTextColor: colors.textSecondary
                    }

                    EventLogPanel {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        model: eventLogModel
                    }
                }
            }

            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                spacing: 12

                MonitorButton {
                    label: "Toggle Alert"
                    normalColor: colors.buttonNormal
                    pressedColor: colors.buttonPressed
                    textColor: colors.textPrimary
                    onClicked: window.setWarning(!window.warning)
                }

                Button {
                    width: 140
                    height: 40
                    text: "Set Normal"
                    onClicked: window.setWarning(false)
                }

                Repeater {
                    model: cameraModel

                    delegate: MonitorButton {

                        label: camera
                        normalColor: index === window.selectedCamera ? colors.buttonNormal :
                                     cameraState === MonitorEnums.CameraState.Warning ? colors.buttonWarning : colors.buttonPressed
                        pressedColor: colors.buttonPressed
                        textColor: colors.textPrimary
                        onClicked: window.selectCamera(index)
                    }
                }
            }
        }
    }
}
