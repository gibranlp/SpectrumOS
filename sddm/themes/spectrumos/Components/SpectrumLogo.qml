import QtQuick 2.11

Item {
    id: logoContainer
    width: 300
    height: 300
    
    property string color0: "#45475a"
    property string color1: "#f38ba8"
    property string color2: "#a6e3a1"
    property string color3: "#f9e2af"
    property string color4: "#89b4fa"
    property string color5: "#f5c2e7"
    property string color6: "#94e2d5"
    property string color7: "#bac2de"
    
    // Multiple SVG layers for the flame effect
    Repeater {
        model: [
            {color: color0, x: -28, y: 0},
            {color: color1, x: -24, y: 0},
            {color: color2, x: -20, y: 0},
            {color: color3, x: -16, y: 0},
            {color: color4, x: -12, y: 0},
            {color: color5, x: -8, y: 0},
            {color: color6, x: -4, y: 0},
            {color: color7, x: 0, y: 0}
        ]
        
        Image {
            width: 250
            height: 250
            x: modelData.x
            y: modelData.y
            source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><path d='M31.994-.006c-2.85 6.985-4.568 11.554-7.74 18.332 1.945 2.062 4.332 4.462 8.2 7.174-4.168-1.715-7-3.437-9.136-5.224-4.06 8.47-10.42 20.538-23.327 43.73C10.145 58.15 18 54.54 25.338 53.16c-.315-1.354-.494-2.818-.48-4.345l.012-.325c.16-6.5 3.542-11.498 7.547-11.158s7.118 5.886 6.957 12.386a18.36 18.36 0 0 1-.409 3.491c7.25 1.418 15.03 5.02 25.037 10.797l-5.42-10.026c-2.65-2.053-5.413-4.726-11.05-7.62 3.875 1.007 6.65 2.168 8.8 3.467-17.1-31.84-18.486-36.07-24.35-49.833z' fill='" + modelData.color + "' fill-rule='evenodd'/></svg>"
            sourceSize: Qt.size(256, 256)  // Change from 64, 64 to much higher res!
            smooth: true
            antialiasing: true
            mipmap: true  // Add this for better quality
        }
    }
}