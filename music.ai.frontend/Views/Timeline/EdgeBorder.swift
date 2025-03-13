import SwiftUI

/// Extension to add a border to specific edges of a view
extension View {
    func border(_ color: Color, width: CGFloat, edges: [Edge]) -> some View {
        overlay(
            EdgeBorder(width: width, edges: edges)
                .foregroundColor(color)
        )
    }
}

/// Helper shape for drawing borders on specific edges
struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var line = Path()
            
            switch edge {
            case .top:
                line.move(to: CGPoint(x: rect.minX, y: rect.minY))
                line.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            case .leading:
                line.move(to: CGPoint(x: rect.minX, y: rect.minY))
                line.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            case .bottom:
                line.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                line.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            case .trailing:
                line.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                line.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
            
            path.addPath(line.strokedPath(StrokeStyle(lineWidth: width)))
        }
        return path
    }
} 