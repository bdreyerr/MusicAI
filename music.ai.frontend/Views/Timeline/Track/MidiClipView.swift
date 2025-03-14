import SwiftUI
import AppKit

/// View for displaying a MIDI clip on a track
struct MidiClipView: View {
    let clip: MidiClip
    let track: Track
    @ObservedObject var state: TimelineState
    @ObservedObject var projectViewModel: ProjectViewModel
    @EnvironmentObject var themeManager: ThemeManager
    
    // State for hover and selection
    @State private var isHovering: Bool = false
    @State private var isDragging: Bool = false
    @State private var showRenameDialog: Bool = false
    @State private var newClipName: String = ""
    
    // Computed property to check if this clip is selected
    private var isSelected: Bool {
        guard state.selectionActive, 
              state.selectionTrackId == track.id else { 
            return false 
        }
        
        // Check if the selection range matches this clip's range
        let (selStart, selEnd) = state.normalizedSelectionRange
        return abs(selStart - clip.startBeat) < 0.001 && 
               abs(selEnd - clip.endBeat) < 0.001
    }
    
    var body: some View {
        // Calculate position and size based on timeline state
        let startX = CGFloat(clip.startBeat * state.effectivePixelsPerBeat)
        let width = CGFloat(clip.duration * state.effectivePixelsPerBeat)
        
        // Debug the clip position
        let _ = print("MidiClipView for \(clip.name): startBeat=\(clip.startBeat), endBeat=\(clip.endBeat), startX=\(startX), width=\(width)")
        
        // Use a ZStack to position the clip correctly
        ZStack(alignment: .topLeading) {
            // Empty view to take up the entire track width
            Color.clear
                .frame(width: width, height: track.height - 4)
                .allowsHitTesting(false) // Don't block clicks
            
            // Clip background with content
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(clip.color ?? track.effectiveColor)
                    .opacity(isSelected ? 0.9 : (isHovering ? 0.8 : 0.6))
                
                // Selection border
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.white, lineWidth: isSelected ? 2 : 0)
                    .opacity(isSelected ? 0.8 : 0)
                
                // Clip name
                Text(clip.name)
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(6)
                    .lineLimit(1)
                
                // Notes visualization (placeholder for now)
                if clip.notes.isEmpty {
                    Text("Empty clip")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.top, 24)
                        .padding(.leading, 6)
                }
            }
            .frame(width: width, height: track.height - 4)
            .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            .onTapGesture {
                print("Tap detected directly on MidiClipView")
                selectThisClip()
            }
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.pointingHand.set()
                    print("Hovering over clip: \(clip.name) at position \(clip.startBeat)-\(clip.endBeat)")
                } else if !isDragging {
                    NSCursor.arrow.set()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        // Check if this is a right-click (secondary click)
                        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
                            // First select the clip
                            print("Right-click detected on MidiClipView")
                            selectThisClip()
                        }
                    }
            )
            .contextMenu {
                Button("Rename Clip") {
                    newClipName = clip.name
                    showRenameDialog = true
                }
                
                Button("Delete Clip") {
                    projectViewModel.removeMidiClip(trackId: track.id, clipId: clip.id)
                }
                
                Divider()
                
                Button("Edit Notes") {
                    print("Edit notes functionality will be implemented later")
                }
            }
        }
        .position(x: startX + width/2, y: (track.height - 4)/2)
        .alert("Rename Clip", isPresented: $showRenameDialog) {
            TextField("Clip Name", text: $newClipName)
            
            Button("Cancel", role: .cancel) {
                showRenameDialog = false
            }
            
            Button("Rename") {
                renameClip(to: newClipName)
                showRenameDialog = false
            }
        } message: {
            Text("Enter a new name for this clip")
        }
    }
    
    // Function to select this clip
    private func selectThisClip() {
        // Select the track
        projectViewModel.selectTrack(id: track.id)
        
        // Create a selection that matches the clip's duration
        state.startSelection(at: clip.startBeat, trackId: track.id)
        state.updateSelection(to: clip.endBeat)
        
        // Move playhead to the start of the clip
        projectViewModel.seekToBeat(clip.startBeat)
        
        // Print debug info
        print("Clip selected: \(clip.name) from \(clip.startBeat) to \(clip.endBeat)")
    }
    
    // Rename the clip
    private func renameClip(to newName: String) {
        guard !newName.isEmpty else { return }
        
        // Use the ProjectViewModel method to rename the clip
        _ = projectViewModel.renameMidiClip(trackId: track.id, clipId: clip.id, newName: newName)
    }
}

#Preview {
    MidiClipView(
        clip: MidiClip(name: "Test Clip", startBeat: 4, duration: 4),
        track: Track.samples.first(where: { $0.type == .midi })!,
        state: TimelineState(),
        projectViewModel: ProjectViewModel()
    )
    .environmentObject(ThemeManager())
    .frame(width: 400, height: 70)
} 