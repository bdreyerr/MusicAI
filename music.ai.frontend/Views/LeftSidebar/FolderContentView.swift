import SwiftUI
import Foundation
import UniformTypeIdentifiers
// Import our drag and drop manager
// no module import needed for AudioDragDropViewModel since it's part of our project

/// View for displaying the contents of a selected folder
struct FolderContentView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var viewModel: SidebarViewModel
    @StateObject private var dragDropViewModel = SampleDragDropViewModel.shared
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
                
                // Navigation bar for folders that support it
                if viewModel.supportsNavigation {
                    HStack(spacing: 8) {
                        // Back button
                        if !viewModel.folderNavigationHistory.isEmpty {
                            Button(action: {
                                viewModel.navigateBack()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(.plain)
                            
                            // Root folder button
                            Button(action: {
                                viewModel.navigateToRoot()
                            }) {
                                Image(systemName: "house")
                                    .font(.system(size: 12))
                                    .foregroundColor(themeManager.primaryTextColor)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Current path
                        Text(viewModel.currentFolderPath)
                            .font(.system(size: 12))
                            .foregroundColor(themeManager.secondaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
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
                    // Error message with settings link if folder doesn't exist
                    VStack(spacing: 12) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 24))
                            .foregroundColor(themeManager.secondaryTextColor)
                        
                        if errorMessage.contains("does not exist") {
                            Text("Samples folder not found")
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                            
                            SettingsLink {
                                Text("Configure in Settings")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                        } else {
                            Text(errorMessage)
                                .font(.system(size: 12))
                                .foregroundColor(themeManager.secondaryTextColor)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
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
                                        FolderItemRowView(item: item, isFolder: true, dragDropViewModel: dragDropViewModel) {
                                            viewModel.navigateToSubfolder(item)
                                        }
                                    } else {
                                        FolderItemRowView(item: item, isFolder: false, dragDropViewModel: dragDropViewModel)
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
    let dragDropViewModel: SampleDragDropViewModel
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
                    
                    // Store this path in the AudioDragDropViewModel for easier access during drop
                    dragDropViewModel.cacheDragPath(fileName: item.name, path: path)
                    
                    // Create a file URL
                    let fileURL = URL(fileURLWithPath: path)
                    
                    // For audio files, we'll create a custom NSItemProvider
                    // that properly handles security-scoped access
                    let provider = NSItemProvider()
                    
                    // Set the suggested name for better identification
                    provider.suggestedName = item.name
                    
                    // Create and register our custom drag data object
                    let dragData = AudioFileDragData(item: item)
                    
                    // Register the drag data as the primary representation
                    provider.registerObject(dragData, visibility: .all)
                    
                    // Register the file path as plain text for fallback
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, 
                                                      visibility: .all) { completion in
                        if let data = path.data(using: .utf8) {
                            print("🔍 REGISTERED file path as text: \(path)")
                            completion(data, nil)
                        } else {
                            completion(Data(), NSError(domain: "com.music.ai", code: 1, userInfo: nil))
                        }
                        return nil
                    }
                    
                    // Register the file URL as URL data
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier,
                                                       visibility: .all) { completion in
                        if let urlData = fileURL.dataRepresentation {
                            print("🔍 REGISTERED file URL data: \(fileURL.path)")
                            completion(urlData, nil)
                        } else {
                            completion(Data(), NSError(domain: "com.music.ai", code: 2, userInfo: nil))
                        }
                        return nil
                    }
                    
                    // For audio file formats, register specific type identifiers
                    let fileExtension = fileURL.pathExtension.lowercased()
                    
                    // For WAV files
                    if fileExtension == "wav" {
                        // Register the classic waveform audio type
                        provider.registerDataRepresentation(forTypeIdentifier: "com.microsoft.waveform-audio",
                                                          visibility: .all) { completion in
                            if FileManager.default.fileExists(atPath: path) {
                                do {
                                    let fileData = try Data(contentsOf: fileURL)
                                    print("🔍 REGISTERED WAV data: \(fileData.count) bytes")
                                    completion(fileData, nil)
                                } catch {
                                    print("⚠️ ERROR reading WAV file: \(error.localizedDescription)")
                                    completion(Data(), error)
                                }
                            } else {
                                completion(Data(), NSError(domain: "com.music.ai", code: 3, userInfo: nil))
                            }
                            return nil
                        }
                    }
                    
                    // For MP3 files
                    if fileExtension == "mp3" {
                        provider.registerDataRepresentation(forTypeIdentifier: "public.mp3",
                                                          visibility: .all) { completion in
                            if FileManager.default.fileExists(atPath: path) {
                                do {
                                    let fileData = try Data(contentsOf: fileURL)
                                    print("🔍 REGISTERED MP3 data: \(fileData.count) bytes")
                                    completion(fileData, nil)
                                } catch {
                                    print("⚠️ ERROR reading MP3 file: \(error.localizedDescription)")
                                    completion(Data(), error)
                                }
                            } else {
                                completion(Data(), NSError(domain: "com.music.ai", code: 4, userInfo: nil))
                            }
                            return nil
                        }
                    }
                    
                    // Register raw data as a last resort
                    provider.registerDataRepresentation(forTypeIdentifier: UTType.data.identifier,
                                                      visibility: .all) { completion in
                        // Create a small data package with the filename and path
                        let infoDict = ["name": item.name, "path": path]
                        if let jsonData = try? JSONSerialization.data(withJSONObject: infoDict) {
                            print("🔍 REGISTERED file info as data: \(jsonData.count) bytes")
                            completion(jsonData, nil)
                        } else {
                            completion(Data(), NSError(domain: "com.music.ai", code: 5, userInfo: nil))
                        }
                        return nil
                    }
                    
                    print("🔍 DRAG PROVIDER: Created provider with type identifiers: \(provider.registeredTypeIdentifiers)")
                    
                    // Reset dragging state after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isDragging = false
                        // Notify the view model that the drag has ended
                        dragDropViewModel.registerDragEnded(successful: true)
                    }
                    
                    return provider
                } else {
                    // If we don't have a path, create a simpler provider with just the name
                    let dragData = AudioFileDragData(item: item)
                    let provider = NSItemProvider(object: dragData)
                    
                    // Reset dragging state after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isDragging = false
                        // Notify the view model that the drag has ended
                        dragDropViewModel.registerDragEnded(successful: false)
                    }
                    
                    return provider
                }
            }
        }
    }
} 
