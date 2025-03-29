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
    
    // Check if the selection overlaps with any clips
    private func getOverlappingClips() -> [OverlappingClipInfo] {
        var results: [OverlappingClipInfo] = []
        
        if track.type == .midi {
            // Check for overlapping MIDI clips
            for clip in track.midiClips {
                if let overlap = calculateOverlap(selectionStart: selectionRange.start, selectionEnd: selectionRange.end,
                                                clipStart: clip.startBeat, clipEnd: clip.endBeat) {
                    results.append(OverlappingClipInfo(
                        start: overlap.start,
                        end: overlap.end,
                        isFullClip: overlap.isFullClip,
                        color: clip.color ?? track.effectiveColor
                    ))
                }
            }
        } else if track.type == .audio {
            // Check for overlapping audio clips
            for clip in track.audioClips {
                if let overlap = calculateOverlap(selectionStart: selectionRange.start, selectionEnd: selectionRange.end,
                                                  clipStart: clip.startPositionInBeats, clipEnd: clip.endBeat) {
                    results.append(OverlappingClipInfo(
                        start: overlap.start,
                        end: overlap.end,
                        isFullClip: overlap.isFullClip,
                        color: clip.color ?? track.effectiveColor
                    ))
                }
            }
        }
        
        return results
    }
    
    // Calculate the overlap between a selection and a clip
    private func calculateOverlap(selectionStart: Double, selectionEnd: Double, 
                                 clipStart: Double, clipEnd: Double) -> (start: Double, end: Double, isFullClip: Bool)? {
        
        // No overlap case
        if selectionEnd <= clipStart || selectionStart >= clipEnd {
            return nil
        }
        
        // Calculate overlap
        let overlapStart = max(selectionStart, clipStart)
        let overlapEnd = min(selectionEnd, clipEnd)
        
        // Check if this is selecting the entire clip
        let isFullClip = abs(overlapStart - clipStart) < 0.001 && abs(overlapEnd - clipEnd) < 0.001
        
        return (start: overlapStart, end: overlapEnd, isFullClip: isFullClip)
    }
    
    // Helper struct to track overlapping clip information
    private struct OverlappingClipInfo: Identifiable {
        let id = UUID()
        let start: Double
        let end: Double
        let isFullClip: Bool
        let color: Color
        
        var startX: CGFloat = 0
        var endX: CGFloat = 0
        var width: CGFloat = 0
        
        init(start: Double, end: Double, isFullClip: Bool, color: Color) {
            self.start = start
            self.end = end
            self.isFullClip = isFullClip
            self.color = color
        }
    }
    
    var body: some View {
        if hasSelection {
            ZStack(alignment: .topLeading) {
                // Default selection rectangle
                Rectangle()
                    .fill(track.effectiveColor.opacity(0.2))
                    .frame(width: max(1, width), height: track.height)
                    .position(x: startX + width/2, y: track.height/2)
                
                // Get overlapping clips info
                let overlappingClips = getOverlappingClips()
                
                ForEach(overlappingClips) { clipInfo in
                    let clipStartX = CGFloat(clipInfo.start * state.effectivePixelsPerBeat)
                    let clipEndX = CGFloat(clipInfo.end * state.effectivePixelsPerBeat)
                    let clipWidth = clipEndX - clipStartX
                    
                    // For clip sub-selections, use a different visual style
                    if clipInfo.isFullClip {
                        // Full clip selection - highlighted border
                        Rectangle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
                            .foregroundColor(clipInfo.color.opacity(0.9))
                            .frame(width: max(1, clipWidth), height: track.height)
                            .position(x: clipStartX + clipWidth/2, y: track.height/2)
                    } else {
                        // Sub-clip selection - solid fill with border
                        ZStack {
                            // Filled rectangle with higher opacity for sub-selections
                            Rectangle()
                                .fill(clipInfo.color.opacity(0.4))
                                .frame(width: max(1, clipWidth), height: track.height)
                            
                            // Border to make it stand out
                            Rectangle()
                                .strokeBorder(clipInfo.color.opacity(0.8), lineWidth: 1.5)
                                .frame(width: max(1, clipWidth), height: track.height)
                        }
                        .position(x: clipStartX + clipWidth/2, y: track.height/2)
                    }
                }
            }
            .allowsHitTesting(false) // Don't interfere with other gestures
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
