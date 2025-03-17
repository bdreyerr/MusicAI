import SwiftUI

struct RightSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AIChatViewModel
    @ObservedObject var projectViewModel: ProjectViewModel
    @State private var sidebarWidth: CGFloat = 320
    @State private var isResizing = false
    @State private var isCollapsed = false
    @State private var selectedModel: String = "claude-3.7-sonnet"
    @State private var showTrackSelector = false
    @State private var eventMonitor: Any? = nil
    
    // Available LLM models
    private let availableModels = ["claude-3.7-sonnet", "claude-3.5-opus", "gpt-4o"]
    @State private var showModelSelector = false
    
    // Computed width based on collapse state
    private var effectiveWidth: CGFloat {
        isCollapsed ? 40 : sidebarWidth
    }
    
    init(projectViewModel: ProjectViewModel) {
        self.projectViewModel = projectViewModel
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Only show resizing handle when not collapsed
            if !isCollapsed {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 5)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        if hovering && !isResizing {
                            NSCursor.resizeLeftRight.push()
                        } else if !hovering && !isResizing {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                isResizing = true
                                let newWidth = sidebarWidth - value.translation.width
                                // Set reasonable min/max width
                                sidebarWidth = min(max(newWidth, 280), 500)
                            }
                            .onEnded { _ in
                                isResizing = false
                            }
                    )
            }
            
            // Main sidebar content
            VStack(spacing: 0) {
                // Header with title and buttons
                HStack {
                    if isCollapsed {
                        // Expand button when collapsed
                        Button(action: {
                            isCollapsed.toggle()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Text("Chat")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        // New chat button
                        Button(action: {
                            viewModel.clearChat()
                        }) {
                            Image(systemName: "plus")
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // History button
                        Button(action: {
                            // Action to show chat history
                        }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        
                        // Collapse button
                        Button(action: {
                            isCollapsed.toggle()
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.horizontal, isCollapsed ? 0 : 16)
                .padding(.vertical, 12)
                .background(themeManager.backgroundColor)
                
                if !isCollapsed {
                    // Chat messages area - moved to the top
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.messages) { message in
                                    ChatMessageView(message: message)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) { _ in
                            if let lastMessage = viewModel.messages.last {
                                withAnimation {
                                    scrollProxy.scrollTo(lastMessage.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                    .background(themeManager.backgroundColor)
                    .frame(maxHeight: .infinity)
                    
                    // Message input area - moved to the bottom
                    VStack(spacing: 0) {
                        // Tracks row
                        HStack(alignment: .center, spacing: 8) {
                            // @ button for track selection
                            Button(action: {
                                // Set the project view model in the chat view model
                                viewModel.setProjectViewModel(projectViewModel)
                                showTrackSelector.toggle()
                            }) {
                                Text("@")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .frame(width: 24, height: 24)
                                    .background(themeManager.backgroundColor)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            .frame(width: 20, height: 20)
                            .cornerRadius(5)
                            .popover(isPresented: $showTrackSelector) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if projectViewModel.tracks.isEmpty {
                                        Text("No tracks available")
                                            .foregroundColor(themeManager.secondaryTextColor)
                                            .padding(.vertical, 4)
                                            .padding(.horizontal, 8)
                                    } else {
                                        ForEach(projectViewModel.tracks) { track in
                                            Button(action: {
                                                viewModel.attachTrack(track.id)
                                                showTrackSelector = false
                                            }) {
                                                HStack(spacing: 8) {
                                                    // Track icon with proper color
                                                    Image(systemName: track.type.icon)
                                                        .foregroundColor(track.customColor ?? track.type.color)
                                                        .font(.system(size: 12))
                                                    
                                                    Text(track.name)
                                                        .foregroundColor(themeManager.primaryTextColor)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                }
                                                .padding(.vertical, 4)
                                                .padding(.horizontal, 8)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }
                                }
                                .padding(8)
                                .background(themeManager.secondaryBackgroundColor)
                                .frame(width: 200)
                            }

                            // Display attached tracks
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.attachedTrackIds, id: \.self) { trackId in
                                        if let track = viewModel.getTrack(by: trackId) {
                                            HStack(spacing: 4) {
                                                Image(systemName: track.type.icon)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(track.customColor ?? track.type.color)
                                                
                                                Text(track.name)
                                                    .font(.system(size: 10))
                                                    .foregroundColor(themeManager.secondaryTextColor)
                                                
                                                Button(action: {
                                                    viewModel.removeTrack(trackId)
                                                }) {
                                                    Image(systemName: "xmark")
                                                        .font(.system(size: 7))
                                                        .foregroundColor(themeManager.secondaryTextColor)
                                                }
                                                .buttonStyle(BorderlessButtonStyle())
                                            }
                                            .padding(3)
                                            .background(themeManager.backgroundColor)
                                            .cornerRadius(4)
                                        }
                                    }
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        // Text input field with buttons
                        VStack(spacing: 8) {
                            // Text input
                            ZStack(alignment: .topLeading) {
                                if viewModel.currentMessage.isEmpty {
                                    Text("Create, find inspiration, plan...")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(.systemGray))
                                        .padding(.leading, 6)
                                        .padding(.top, 0)
                                        .allowsHitTesting(false) // Make sure text doesn't block TextEditor interaction
                                }
                                
                                TextEditor(text: $viewModel.currentMessage)
                                    .padding(viewModel.currentMessage.isEmpty ? 1 : 4)
                                    .foregroundColor(themeManager.primaryTextColor)
                                    .frame(
                                        minHeight: viewModel.currentMessage.isEmpty ? 12 : 24,
                                        idealHeight: viewModel.currentMessage.isEmpty ? 12 : estimateHeight(for: viewModel.currentMessage),
                                        maxHeight: 100
                                    )
                                    .background(themeManager.secondaryBackgroundColor)
                                    .cornerRadius(8)
                                    .scrollContentBackground(.hidden)
                                    .animation(.spring(response: 0.3), value: viewModel.currentMessage.isEmpty)
                                    .animation(.spring(response: 0.3), value: estimateHeight(for: viewModel.currentMessage))
                                    .onAppear {
                                        // Add keyboard shortcut handling
                                        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                                            if event.keyCode == 36 { // Enter/Return key
                                                if event.modifierFlags.contains(.shift) {
                                                    // Shift+Enter: Add a new line
                                                    return event
                                                } else {
                                                    // Enter: Send message if not empty
                                                    if !viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                        viewModel.sendMessage()
                                                        return nil // Consume the event
                                                    }
                                                }
                                            }
                                            return event
                                        }
                                    }
                                    .onDisappear {
                                        // Remove the event monitor when view disappears
                                        if let monitor = eventMonitor {
                                            NSEvent.removeMonitor(monitor)
                                            eventMonitor = nil
                                        }
                                    }
                            }
                            .background(themeManager.secondaryBackgroundColor)
                            .cornerRadius(8)
                            .frame(
                                height: viewModel.currentMessage.isEmpty ? 20 : min(max(estimateHeight(for: viewModel.currentMessage) + 8, 32), 108)
                            )
                            .animation(.spring(response: 0.3), value: viewModel.currentMessage.isEmpty)
                            .animation(.spring(response: 0.3), value: estimateHeight(for: viewModel.currentMessage))
                            
                            // Bottom controls row
                            HStack(spacing: 8) {
                                // Model selector
                                Button(action: {
                                    showModelSelector.toggle()
                                }) {
                                    HStack(spacing: 4) {
                                        Text(selectedModel)
                                            .font(.system(size: 12))
                                            .foregroundColor(themeManager.primaryTextColor)
                                        
                                        Image(systemName: "chevron.down")
                                            .font(.system(size: 10))
                                            .foregroundColor(themeManager.primaryTextColor)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(themeManager.tertiaryBackgroundColor)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .popover(isPresented: $showModelSelector) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ForEach(availableModels, id: \.self) { model in
                                            Button(action: {
                                                selectedModel = model
                                                showModelSelector = false
                                            }) {
                                                Text(model)
                                                    .foregroundColor(themeManager.primaryTextColor)
                                                    .padding(.vertical, 4)
                                                    .padding(.horizontal, 8)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .background(selectedModel == model ? themeManager.tertiaryBackgroundColor : Color.clear)
                                                    .cornerRadius(4)
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                    }
                                    .padding(8)
                                    .background(themeManager.secondaryBackgroundColor)
                                }
                                
                                Spacer()
                                
                                // Attachment button
                                Button(action: {
                                    // Action to attach file
                                }) {
                                    Image(systemName: "paperclip")
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .frame(width: 20, height: 20)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                
                                // Send button
                                Button(action: {
                                    viewModel.sendMessage()
                                }) {
                                    Image(systemName: "paperplane.fill")
                                        .foregroundColor(themeManager.primaryTextColor)
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                                .disabled(viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, viewModel.currentMessage.isEmpty ? 4 : 8)
                    }
                    .background(themeManager.secondaryBackgroundColor)
                    .cornerRadius(10)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: effectiveWidth)
        .background(themeManager.backgroundColor)
        .border(themeManager.secondaryBorderColor, width: 0.5)
        // Removed animation for collapsing/uncollapsing
    }
    
    private func estimateHeight(for text: String) -> CGFloat {
        let baseHeight: CGFloat = 24
        let lineHeight: CGFloat = 20
        
        if text.isEmpty {
            return 12 // Return a smaller height when empty
        }
        
        // Count newlines
        let newlineCount = text.filter { $0 == "\n" }.count
        
        // Estimate if text would wrap based on average characters per line
        // This is an approximation - actual wrapping depends on font, width, etc.
        let averageCharsPerLine = 30
        let lines = max(1, ceil(Double(text.count) / Double(averageCharsPerLine)))
        
        // Use the greater of explicit newlines or estimated wrapping
        let totalLines = max(Double(newlineCount + 1), lines)
        
        return baseHeight + (totalLines > 1 ? CGFloat(totalLines - 1) * lineHeight : 0)
    }
}

#Preview {
    let projectViewModel = ProjectViewModel()
    let chatViewModel = AIChatViewModel(projectViewModel: projectViewModel)
    
    return RightSidebarView(projectViewModel: projectViewModel)
        .environmentObject(ThemeManager())
        .environmentObject(chatViewModel)
} 
