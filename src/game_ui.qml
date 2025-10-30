// make completely with AI - for now

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    width: 400
    height: 620
    minimumWidth: 380
    minimumHeight: 600
    visible: true
    title: "Wordle (Julia + QML)"
    color: colors.bg // from our color map

    // --- Color Constants ---
    QtObject {
        id: colors
        property color bg: "#121213"
        property color border: "#3a3a3c"
        property color keyDefault: "#818384"
    }

    // --- Notification Timer ---
    Timer {
        id: notificationTimer
        interval: 3000
        // clear the Julia observable (notif) instead of directly changing the text element
        onTriggered: client.notif = ""
    }

    // --- Main Layout ---
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 15

        // 1. Title
        Text {
            text: "WORDLE"
            color: "white"
            font.pixelSize: 28
            font.weight: Font.Bold
            Layout.alignment: Qt.AlignHCenter
        }

        // 2. Notification Bar
        Rectangle {
            id: notificationContainer
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            radius: 5
            color: "white"
            opacity: notificationText.text ? 1 : 0

            Text {
                id: notificationText
                text: client.notif
                color: "#121213"
                font.pixelSize: 14
                font.weight: Font.Bold
                anchors.fill: parent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.margins: 10

                onTextChanged: {
                    if (text) {
                        notificationContainer.opacity = 1
                        notificationTimer.start()
                    } else {
                        notificationContainer.opacity = 0
                    }
                }
            }
        }

        // 3. Game Grid
        GridView {
            id: gridView
            // 'grid_model' is provided by our Julia 'WordleClient'
            model: client.grid_model

            cellWidth: 65
            cellHeight: 65
            Layout.alignment: Qt.AlignHCenter

            // 'delegate' is the template for each item in the model
            delegate: Rectangle {
                width: 60
                height: 60
                // Use the snake_case field names coming from Julia
                color: model.tile_colour
                border.color: model.tile_colour
                border.width: 2
                radius: 4

                Text {
                    // 'model.letter' comes from the Julia Dict
                    text: model.letter
                    anchors.centerIn: parent
                    color: "white"
                    font.pixelSize: 28
                    font.weight: Font.Bold
                }
            }
        }

        // 4. Keyboard
        ColumnLayout {
            id: keyboardLayout
            spacing: 8
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignBottom

            Repeater {
                // We use the 3 keyboard rows
                model: [
                    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["Enter", "z", "x", "c", "v", "b", "n", "m", "Backspace"]
                ]

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6

                    Repeater {
                        // Repeats for each key in the row
                        model: modelData

                        Button {
                            text: modelData.toUpperCase()
                            // call the top-level handle_key provided when loading QML
                            onClicked: handle_key(modelData)

                            property bool isLarge: modelData.length > 1
                            Layout.preferredHeight: 58
                            Layout.preferredWidth: isLarge ? 70 : 40

                            font.pixelSize: 14
                            font.weight: Font.Bold

                            // Dynamically find the key's color from the key_model (plain array)
                            property var keyData: {
                                for (var i = 0; i < client.key_model.length; i++) {
                                    var item = client.key_model[i]
                                    if (item && item.key === modelData)
                                        return item
                                }
                                return null
                            }

                            background: Rectangle {
                                // Bind the color to our model's 'key_colour' (snake_case)
                                color: keyData ? keyData["key_colour"] : colors.keyDefault
                                radius: 4
                            }
                        }
                    }
                }
            }
        }
    }
}

