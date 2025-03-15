import SwiftUI

/// View that displays the current selection on a track
struct TimelineSelectionView: View {
    @ObservedObject var state: TimelineState
    let track: Track
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // Computed properties for the selection visualization
    private var hasSelection: Bool {
        return state.hasSelection(trackId: track.id)
    }
    
    private var selectionRange: (start: Double, end: Double) {
        return state.normalizedSelectionRange
    }
    
    private var startX: CGFloat {
        return CGFloat(selectionRange.start * state.effectivePixelsPerBeat)
    }
    
    private var endX: CGFloat {
        return CGFloat(selectionRange.end * state.effectivePixelsPerBeat)
    }
    
    private var width: CGFloat {
        return endX - startX
    }
    
    // Check if this selection is likely a preview for a MIDI clip drag
    private var isMidiClipDragPreview: Bool {
        guard hasSelection && track.type == .midi else { return false }
        
        // Check if the selection matches the size of any MIDI clip
        return track.midiClips.contains { clip in
            abs((selectionRange.end - selectionRange.start) - clip.duration) < 0.001
        }
    }
    
    var body: some View {
        if hasSelection {
            ZStack {
                // Selection rectangle
                Rectangle()
                    .fill(track.effectiveColor.opacity(isMidiClipDragPreview ? 0.2 : 0.3))
                    .frame(width: max(1, width), height: track.height)
                
                // Add a dashed border if this is likely a MIDI clip drag preview
                if isMidiClipDragPreview {
                    Rectangle()
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                        .foregroundColor(track.effectiveColor.opacity(0.8))
                        .frame(width: max(1, width), height: track.height)
                }
            }
            .position(x: startX + width/2, y: track.height/2)
            .allowsHitTesting(false) // Don't interfere with other gestures
        }
    }
    
    // Format the duration of the selection
    private func formattedDuration() -> String {
        let duration = selectionRange.end - selectionRange.start
        let bars = Int(duration) / projectViewModel.timeSignatureBeats
        let beats = duration.truncatingRemainder(dividingBy: Double(projectViewModel.timeSignatureBeats))
        
        if bars > 0 {
            return "\(bars)b \(String(format: "%.2f", beats))bt"
        } else {
            return "\(String(format: "%.2f", beats))bt"
        }
    }
}

#Preview {
    TimelineSelectionView(
        state: {
            let state = TimelineState()
            state.startSelection(at: 4.0, trackId: Track.samples[0].id)
            state.updateSelection(to: 8.0)
            return state
        }(),
        track: Track.samples[0],
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 400, height: 70)
} 