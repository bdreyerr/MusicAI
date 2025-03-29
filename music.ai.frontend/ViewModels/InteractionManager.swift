import SwiftUI
import Combine

/// Manages interaction state and priorities for the timeline
/// This helps resolve conflicts between different gestures and event handlers
class InteractionManager: ObservableObject {
    // Interaction state
    @Published var isSelecting: Bool = false // Active selection in progress
    @Published var isDraggingClip: Bool = false // Currently dragging a clip
    @Published var isResizingClip: Bool = false // Currently resizing a clip
    @Published var isHandlingRightClick: Bool = false // Currently processing a right-click
    @Published var isHandlingDrop: Bool = false // Currently handling a drop
    
    // Interaction locks
    private var selectionLock = false
    private var clipDragLock = false
    private var clipResizeLock = false
    private var rightClickLock = false
    private var dropLock = false
    
    // Debug settings
    private let loggingEnabled = false // Set to true to enable detailed logging
    
    // Debug info for tracing interactions
    @Published var lastInteractionDescription: String = ""
    
    // Timestamps to handle rapid successions of events
    private var lastInteractionTime: Date = Date()
    
    // Reset cancellable
    private var resetCancellable: AnyCancellable?
    
    // Init
    init() {
        log("InteractionManager initialized")
        resetCancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                // If more than 0.5 seconds has passed since the last interaction,
                // ensure we're not locking any interactions
                guard let self = self else { return }
                let now = Date()
                if now.timeIntervalSince(self.lastInteractionTime) > 0.5 {
                    self.resetLocks()
                }
            }
    }
    
    // MARK: - Public Methods
    
    /// Start a selection interaction
    func startSelection() -> Bool {
        log("⚪️ REQUEST: Start selection")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        guard !selectionLock && !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock else {
            log("❌ DENIED: Cannot start selection - another interaction is active")
            log("❌ Locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
            return false
        }
        
        isSelecting = true
        selectionLock = true
        lastInteractionTime = Date()
        lastInteractionDescription = "Selection started"
        log("✅ GRANTED: Selection started")
        return true
    }
    
    /// End a selection interaction
    func endSelection() {
        isSelecting = false
        selectionLock = false
        lastInteractionTime = Date()
        lastInteractionDescription = "Selection ended"
        log("🏁 Selection ended")
    }
    
    /// Start a clip drag interaction
    func startClipDrag() -> Bool {
        log("⚪️ REQUEST: Start clip drag")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        guard !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock else {
            log("❌ DENIED: Cannot start clip drag - another interaction is active")
            log("❌ Locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
            return false
        }
        
        // Selection lock doesn't prevent clip dragging
        // since selection can be active while dragging
        
        isDraggingClip = true
        clipDragLock = true
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip drag started"
        log("✅ GRANTED: Clip drag started")
        return true
    }
    
    /// End a clip drag interaction
    func endClipDrag() {
        isDraggingClip = false
        clipDragLock = false
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip drag ended"
        log("🏁 Clip drag ended")
    }
    
    /// Start a clip resize interaction
    func startClipResize() -> Bool {
        log("⚪️ REQUEST: Start clip resize")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        guard !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock else {
            log("❌ DENIED: Cannot start clip resize - another interaction is active")
            log("❌ Locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
            return false
        }
        
        // Selection lock doesn't prevent clip resizing
        // since selection can be active while resizing
        
        isResizingClip = true
        clipResizeLock = true
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip resize started"
        log("✅ GRANTED: Clip resize started")
        return true
    }
    
    /// End a clip resize interaction
    func endClipResize() {
        isResizingClip = false
        clipResizeLock = false
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip resize ended"
        log("🏁 Clip resize ended")
    }
    
    /// Start a right-click interaction
    func startRightClick() -> Bool {
        log("⚪️ REQUEST: Start right-click")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        // Right click has highest priority and can interrupt other interactions
        rightClickLock = true
        isHandlingRightClick = true
        lastInteractionTime = Date()
        lastInteractionDescription = "Right-click started"
        log("✅ GRANTED: Right-click started (high priority)")
        return true
    }
    
    /// End a right-click interaction
    func endRightClick() {
        isHandlingRightClick = false
        rightClickLock = false
        lastInteractionTime = Date()
        lastInteractionDescription = "Right-click ended"
        log("🏁 Right-click ended")
    }
    
    /// Start a drop interaction
    func startDrop() -> Bool {
        log("⚪️ REQUEST: Start drop")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        guard !selectionLock && !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock else {
            log("❌ DENIED: Cannot start drop - another interaction is active")
            log("❌ Locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
            return false
        }
        
        isHandlingDrop = true
        dropLock = true
        lastInteractionTime = Date()
        lastInteractionDescription = "Drop started"
        log("✅ GRANTED: Drop started")
        return true
    }
    
    /// End a drop interaction
    func endDrop() {
        isHandlingDrop = false
        dropLock = false
        lastInteractionTime = Date()
        lastInteractionDescription = "Drop ended"
        log("🏁 Drop ended")
    }
    
    /// Check if we can start a new selection
    func canStartSelection() -> Bool {
        let result = !selectionLock && !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock
        log("🔍 canStartSelection check: \(result)")
        if !result {
            log("🔍 Blocked by locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
        }
        return result
    }
    
    /// Check if we can start a new clip drag
    func canStartClipDrag() -> Bool {
        let result = !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock
        log("🔍 canStartClipDrag check: \(result)")
        if !result {
            log("🔍 Blocked by locks - clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
        }
        return result
    }
    
    /// Check if we can start a new clip resize
    func canStartClipResize() -> Bool {
        let result = !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock
        log("🔍 canStartClipResize check: \(result)")
        if !result {
            log("🔍 Blocked by locks - clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
        }
        return result
    }
    
    /// Check if we can start a new clip selection
    func canStartClipSelection() -> Bool {
        let result = !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock
        log("🔍 canStartClipSelection check: \(result)")
        if !result {
            log("🔍 Blocked by locks - clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
        }
        return result
    }
    
    /// Start a clip selection interaction
    func startClipSelection() -> Bool {
        log("⚪️ REQUEST: Start clip selection")
        let currentState = "Current state - selection: \(isSelecting), clipDrag: \(isDraggingClip), clipResize: \(isResizingClip), rightClick: \(isHandlingRightClick), drop: \(isHandlingDrop)"
        log("⚪️ \(currentState)")
        
        guard !clipDragLock && !clipResizeLock && !rightClickLock && !dropLock else {
            log("❌ DENIED: Cannot start clip selection - another interaction is active")
            log("❌ Locks - selection: \(selectionLock), clipDrag: \(clipDragLock), clipResize: \(clipResizeLock), rightClick: \(rightClickLock), drop: \(dropLock)")
            return false
        }
        
        // We allow selection to happen alongside other selection
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip selection started"
        log("✅ GRANTED: Clip selection started")
        return true
    }
    
    /// End a clip selection interaction
    func endClipSelection() {
        lastInteractionTime = Date()
        lastInteractionDescription = "Clip selection ended"
        log("🏁 Clip selection ended")
    }
    
    /// Check if we can process a right-click
    func canProcessRightClick() -> Bool {
        // Right click has highest priority and can interrupt other interactions
        log("🔍 canProcessRightClick check: true (always allowed)")
        return true
    }
    
    /// Reset all interaction states and locks
    func resetAll() {
        isSelecting = false
        isDraggingClip = false
        isResizingClip = false
        isHandlingRightClick = false
        isHandlingDrop = false
        resetLocks()
        lastInteractionDescription = "All interactions reset"
        log("🔄 All interactions and locks reset")
    }
    
    // MARK: - Private Methods
    
    private func resetLocks() {
        let hadActiveLocks = selectionLock || clipDragLock || clipResizeLock || rightClickLock || dropLock
        selectionLock = false
        clipDragLock = false
        clipResizeLock = false
        rightClickLock = false
        dropLock = false
        
        if hadActiveLocks {
            log("🔓 All locks cleared")
        }
    }
    
    // Private log method that prints to console if logging is enabled
    private func log(_ message: String) {
        if loggingEnabled {
            print("📊 INTERACTION: \(message)")
        }
    }
    
    // Clean up when the view model is deallocated
    deinit {
        resetCancellable?.cancel()
        log("InteractionManager deallocated")
    }
} 