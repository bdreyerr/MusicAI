import SwiftUI

/// View that displays the current selection on a track
struct TimelineSelectionView: View {
    @ObservedObject var state: TimelineStateViewModel
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
    
    // Check if this selection is likely a preview for a clip drag
    private var isClipDragPreview: Bool {
        guard hasSelection else { return false }
        
        if track.type == .midi {
            // Check if the selection matches the size of any MIDI clip
            return track.midiClips.contains { clip in
                abs((selectionRange.end - selectionRange.start) - clip.duration) < 0.001
            }
        } else if track.type == .audio {
            // Check if the selection matches the size of any audio clip
            return track.audioClips.contains { clip in
                abs((selectionRange.end - selectionRange.start) - clip.duration) < 0.001
            }
        }
        
        return false
    }
    
    var body: some View {
        if hasSelection {
            ZStack {
                // Selection rectangle
                Rectangle()
                    .fill(track.effectiveColor.opacity(isClipDragPreview ? 0.2 : 0.3))
                    .frame(width: max(1, width), height: track.height)
                
                // Add a dashed border if this is likely a clip drag preview
                if isClipDragPreview {
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
            let state = TimelineStateViewModel()
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
