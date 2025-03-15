import SwiftUI

struct RightSidebarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var viewModel: AIChatViewModel
    @State private var sidebarWidth: CGFloat = 320
    @State private var isResizing = false
    @State private var isCollapsed = false
    
    // Computed width based on collapse state
    private var effectiveWidth: CGFloat {
        isCollapsed ? 40 : sidebarWidth
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Resizing handle
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
                            if isCollapsed { return }
                            isResizing = true
                            let newWidth = sidebarWidth - value.translation.width
                            // Set reasonable min/max width
                            sidebarWidth = min(max(newWidth, 280), 500)
                        }
                        .onEnded { _ in
                            isResizing = false
                        }
                )
            
            // Main sidebar content
            VStack(spacing: 0) {
                // Header with collapse/expand button
                HStack {
                    Button(action: {
                        withAnimation(.spring()) {
                            isCollapsed.toggle()
                        }
                    }) {
                        Image(systemName: isCollapsed ? "chevron.left" : "chevron.right")
                            .foregroundColor(themeManager.primaryTextColor)
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    if !isCollapsed {
                        Text("AI Assistant")
                            .font(.headline)
                            .foregroundColor(themeManager.primaryTextColor)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.clearChat()
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(themeManager.primaryTextColor)
                                .frame(width: 20, height: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(themeManager.tertiaryBackgroundColor)
                
                if !isCollapsed {
                    // Chat messages area
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 10) {
                                ForEach(viewModel.messages) { message in
                                    ChatBubbleView(message: message)
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
                    
                    // Message input area
                    HStack {
                        TextField("Type a message...", text: $viewModel.currentMessage)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(themeManager.primaryTextColor)
                            .onSubmit {
                                viewModel.sendMessage()
                            }
                        
                        Button(action: {
                            viewModel.sendMessage()
                        }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                        .disabled(viewModel.currentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(10)
                    .background(themeManager.secondaryBackgroundColor)
                }
            }
        }
        .frame(width: effectiveWidth)
        .background(themeManager.secondaryBackgroundColor)
        .border(themeManager.secondaryBorderColor, width: 0.5)
        .animation(.spring(), value: isCollapsed)
    }
}

#Preview {
    RightSidebarView()
        .environmentObject(ThemeManager())
        .environmentObject(AIChatViewModel())
} 
