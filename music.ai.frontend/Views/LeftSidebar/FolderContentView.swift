import SwiftUI
import Foundation

/// View for displaying the contents of a selected folder
struct FolderContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    @State private var searchText: String = ""
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 0) {
                // Search bar
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(themeManager.secondaryTextColor)
                    
                    TextField("Search", text: $searchText)
                        .font(.system(size: 12))
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(themeManager.primaryTextColor)
                        .focused($isSearchFieldFocused)
                        .onSubmit {
                            // Will be used later for search functionality
                            isSearchFieldFocused = false
                        }
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(themeManager.tertiaryBackgroundColor.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSearchFieldFocused ? themeManager.borderColor : Color.clear, lineWidth: 1)
                        )
                )
                .cornerRadius(6)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Folder navigation bar (only shown for user folders with navigation history)
                if let _ = viewModel.selectedUserFolder, viewModel.canNavigateBack {
                    HStack(spacing: 8) {
                        Button(action: {
                            viewModel.navigateBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            viewModel.navigateToRoot()
                        }) {
                            Image(systemName: "house")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Text(viewModel.currentFolderPath)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.primaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(themeManager.tertiaryBackgroundColor.opacity(0.3))
                }
                
                // Content area
                if viewModel.isLoadingContents {
                    // Loading indicator
                    VStack {
                        ProgressView()
                            .scaleEffect(0.7)
                            .padding(.bottom, 4)
                        Text("Loading folder contents...")
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.secondaryBackgroundColor)
                } else if let errorMessage = viewModel.folderLoadError {
                    // Error message
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                        
                        Button("Refresh") {
                            viewModel.refreshCurrentFolder()
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.tertiaryBackgroundColor)
                        .cornerRadius(4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(themeManager.secondaryBackgroundColor)
                } else {
                    // Custom scrollable list of items without separators
                    ScrollView {
                        VStack(spacing: 0) {
                            if viewModel.selectedFolderItems.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 24))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                    Text("No audio files found")
                                        .font(.system(size: 12))
                                        .foregroundColor(themeManager.secondaryTextColor)
                                }
                                .frame(maxWidth: .infinity, minHeight: 100, maxHeight: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(viewModel.selectedFolderItems) { item in
                                    if item.metadata?["type"] == "folder" {
                                        FolderItemRowView(item: item, isFolder: true) {
                                            viewModel.navigateToSubfolder(item)
                                        }
                                    } else {
                                        FolderItemRowView(item: item, isFolder: false)
                                    }
                                }
                            }
                        }
                        .onTapGesture {
                            // Defocus search field when tapping on the content area
                            if isSearchFieldFocused {
                                isSearchFieldFocused = false
                            }
                        }
                    }
                    .background(themeManager.secondaryBackgroundColor)
                }
            }
            .frame(width: geometry.size.width)
            .background(themeManager.secondaryBackgroundColor)
            .border(themeManager.secondaryBorderColor, width: 0.5)
            .onAppear {
                // Explicitly ensure the search field is not focused when the view appears
                DispatchQueue.main.async {
                    isSearchFieldFocused = false
                }
            }
        }
    }
}

/// A single row in the folder content list with hover effects
struct FolderItemRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let item: FolderItem
    let isFolder: Bool
    var onFolderTap: (() -> Void)? = nil
    
    @State private var isHovering = false
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: item.icon)
                .font(.system(size: 12))
                .foregroundColor(themeManager.secondaryTextColor)
                .frame(width: 16)
            
            Text(item.name)
                .font(.system(size: 12))
                .foregroundColor(themeManager.primaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
            
            Spacer(minLength: 4)
            
            if isFolder {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(themeManager.secondaryTextColor)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .background(
            isHovering || isDragging ?
            (themeManager.currentTheme == .dark ? Color(white: 0.3) : Color(white: 0.9)) :
            themeManager.secondaryBackgroundColor
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .onTapGesture {
            if isFolder, let onTap = onFolderTap {
                onTap()
            }
            // For regular files, we'll handle playback later
        }
        // Make audio files draggable
        .if(!isFolder) { view in
            view.onDrag {
                // Set the dragging state
                isDragging = true
                
                // Debug logs
                print("🔍 DRAG START: Starting drag for item: \(item.name)")
                if let path = item.metadata?["path"] {
                    print("🔍 DRAG PATH: \(path)")
                }
                
                // Create the drag data
                let dragData = AudioFileDragData(item: item)
                
                // Create an NSItemProvider with the audio file data
                let provider = NSItemProvider(object: dragData)
                
                // Register the provider for additional UTIs to ensure compatibility
                for typeIdentifier in ["public.data", "public.content", "public.item"] {
                    provider.registerDataRepresentation(forTypeIdentifier: typeIdentifier,
                                                      visibility: .all) { completion in
                        do {
                            let data = try JSONEncoder().encode(dragData)
                            print("🔍 REGISTERED \(typeIdentifier) representation with size: \(data.count) bytes")
                            completion(data, nil)
                            return nil
                        } catch {
                            print("🔍 ERROR registering \(typeIdentifier): \(error)")
                            completion(nil, error)
                            return nil
                        }
                    }
                }
                
                // If we have a file path, also register it as a file URL
                if let filePath = item.metadata?["path"] {
                    let fileURL = URL(fileURLWithPath: filePath)
                    provider.registerFileRepresentation(forTypeIdentifier: "public.file-url",
                                                      fileOptions: [],
                                                      visibility: .all) { progressHandler in
                        print("🔍 REGISTERED file URL representation for: \(fileURL.path)")
                        progressHandler(fileURL, true, nil)
                        return Progress.discreteProgress(totalUnitCount: 1)
                    }
                }
                
                print("🔍 DRAG PROVIDER: Created provider with type identifiers: \(provider.registeredTypeIdentifiers)")
                
                // Reset dragging state after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isDragging = false
                }
                
                return provider
            }
        }
    }
} 
