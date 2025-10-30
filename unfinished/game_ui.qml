import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15
import jlqml // <-- This is required for @qmlfunction

ApplicationWindow {
    id: window
    width: 400
    height: 620
    minimumWidth: 380
    minimumHeight: 600
    visible: true
    title: "Wordle (Julia + QML)"
    // Bind to the colors from your Julia script's COLOUR_MAP
    color: colors.bg 

    // --- Color Constants (from your Julia script) ---
    QtObject {
        id: colors
        property color bg: "#121212"
        property color border: "#323233"
        property color default_key: "#828483"
    }

    // --- Notification Timer ---
    Timer {
        id: notificationTimer
        interval: 3000
        // Clear the notification after 3 seconds
        onTriggered: notificationText.text = "" 
    }

    // Run start_newgame after event loop starts (single-shot)
    Timer {
        id: startupTimer
        interval: 0
        running: true
        repeat: false
        onTriggered: {
            Julia.jl_start_newgame()
        }
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
        Label { 
            id: notificationText
            // This binds directly to 'client.notif' observable
            // Use a safe fallback so we don't assign 'undefined' to QString
            text: client ? (client.notif ? client.notif : "") : ""
            
            color: "#121213" // Dark text on light background
            font.pixelSize: 14
            font.weight: Font.Bold
            padding: 10
            
            opacity: text ? 1 : 0 // Hide when empty
            
            Layout.alignment: Qt.AlignHCenter
            Layout.fillWidth: true
            
            horizontalAlignment: Text.AlignHCenter
            
            // When text changes, show it and start the timer
            onTextChanged: {
                if (text) {
                    opacity = 1
                    notificationTimer.start()
                }
            }

            background: Rectangle { 
                color: "white" // Light background for the notification
                radius: 5
            }
        }

        // 3. Game Grid
        GridView {
            id: gridView
            // Binds to the 'client.grid_model'
            model: client.grid_model 
            
            cellWidth: 65
            cellHeight: 65
            Layout.alignment: Qt.AlignHCenter

            // ensure the GridView is allocated space inside the ColumnLayout
            Layout.preferredHeight: 6 * cellHeight   // 6 rows
            Layout.preferredWidth: 5 * cellWidth     // 5 columns
            Layout.fillWidth: false

            // 'delegate' is the template for each item in the model
            delegate: Rectangle {
                width: 60
                height: 60
                // Binds to 'tile_colour' from your Julia Dict
                color: model.tile_colour 
                border.color: model.tile_colour
                border.width: 2
                radius: 4

                Text {
                    // Binds to 'letter' from your Julia Dict
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

            // This Repeater creates the 3 rows
            Repeater {
                model: [
                    ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
                    ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
                    ["Enter", "z", "x", "c", "v", "b", "n", "m", "Backspace"]
                ]
                
                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 6
                    
                    // This Repeater creates the keys in each row
                    Repeater {
                        model: modelData // modelData is the array for the current row
                        
                        Button {
                            text: modelData.toUpperCase()
                            
                            // --- Calls the @qmlfunction-registered function ---
                            onClicked: Julia.jl_handle_key(modelData) 
                            
                            property bool isLarge: modelData.length > 1
                            Layout.preferredHeight: 58
                            Layout.preferredWidth: isLarge ? 70 : 40
                            
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            
                            // This JS snippet finds the key's data from the Julia model
                            property var keyData: {
                                if (!client || !client.key_model) return null; // Safety check
                                for (var i = 0; i < client.key_model.length; i++) {
                                    if (client.key_model[i].key === modelData)
                                        return client.key_model[i]
                                }
                                return null
                            }
                            
                            background: Rectangle {
                                // Binds to 'key_colour' from your Julia Dict
                                color: keyData ? keyData.key_colour : colors.default_key
                                radius: 4
                            }
                        }
                    }
                }
            }
        }
    }
    
    // As per your script's comments, call start_newgame() once the UI is ready
    Component.onCompleted: {
        // --- Calls the @qmlfunction-registered function ---
    }
}

