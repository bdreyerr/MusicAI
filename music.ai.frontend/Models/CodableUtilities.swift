import Foundation
import SwiftUI

/// Helper struct to encode and decode Color
struct CodableColor: Codable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double
    
    init(color: Color) {
        let components = color.components
        self.red = components.red
        self.green = components.green
        self.blue = components.blue
        self.opacity = components.opacity
    }
    
    var color: Color {
        return Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

// Extension to get color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        // Convert SwiftUI Color to NSColor
        let nsColor = NSColor(self)
        
        // Get components using NSColor directly, avoiding CGColor
        // NSColor uses calibrated RGB by default
        let r = nsColor.redComponent
        let g = nsColor.greenComponent
        let b = nsColor.blueComponent
        let o = nsColor.alphaComponent
        
        return (Double(r), Double(g), Double(b), Double(o))
    }
} 
