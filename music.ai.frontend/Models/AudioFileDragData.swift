import Foundation
import UniformTypeIdentifiers

/// Class for representing audio file data during drag and drop operations
class AudioFileDragData: NSObject, NSItemProviderWriting, NSItemProviderReading, Codable {
    static var writableTypeIdentifiersForItemProvider: [String] {
        return [
            "com.music.ai.audiofile",
            UTType.fileURL.identifier,
            UTType.data.identifier,
            UTType.content.identifier,
            UTType.item.identifier,
            UTType.plainText.identifier,
            "com.microsoft.waveform-audio",
            "public.mp3",
            "public.audio"
        ]
    }
    
    static var readableTypeIdentifiersForItemProvider: [String] {
        return [
            "com.music.ai.audiofile",
            UTType.fileURL.identifier,
            UTType.data.identifier,
            UTType.content.identifier,
            UTType.item.identifier,
            UTType.plainText.identifier,
            "com.microsoft.waveform-audio",
            "public.mp3",
            "public.audio"
        ]
    }
    
    let name: String
    let path: String?
    let fileExtension: String?
    let icon: String
    
    // We use the shared instance since this object can be serialized and deserialized
    // and we can't include a direct reference to the view model
    private var viewModel: AudioDragDropViewModel {
        return AudioDragDropViewModel.shared
    }
    
    init(item: FolderItem) {
        self.name = item.name
        self.path = item.metadata?["path"]
        self.fileExtension = item.metadata?["extension"]
        self.icon = item.icon
        super.init()
        print("📦 CREATED: AudioFileDragData for \(name), path: \(path ?? "nil")")
        
        // Create a security-scoped bookmark for this file if we have a path
        if let filePath = path {
            let fileURL = URL(fileURLWithPath: filePath)
            viewModel.createSecurityScopedBookmark(for: filePath)
        }
    }
    
    // Required initializer for NSItemProviderReading
    required init(name: String, path: String?, fileExtension: String?, icon: String) {
        self.name = name
        self.path = path
        self.fileExtension = fileExtension
        self.icon = icon
        super.init()
        print("📦 INITIALIZED: AudioFileDragData with name: \(name), path: \(path ?? "nil")")
        
        // Create a security-scoped bookmark for this file if we have a path
        if let filePath = path {
            viewModel.createSecurityScopedBookmark(for: filePath)
        }
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        print("📦 LOADING DATA: For type identifier: \(typeIdentifier)")
        
        // If we have a path, make sure we have security access to it
        if let path = self.path {
            let hasAccess = viewModel.startAccessingFile(at: path)
            print("📦 SECURITY ACCESS: \(hasAccess ? "Granted" : "Denied") for \(path)")
            
            // Ensure we stop accessing the file when we're done
            defer {
                if hasAccess {
                    viewModel.stopAccessingFile(at: path)
                    print("📦 SECURITY ACCESS: Released for \(path)")
                }
            }
            
            // Handle file URL type identifier
            if typeIdentifier == UTType.fileURL.identifier {
                let fileURL = URL(fileURLWithPath: path)
                if let urlData = fileURL.dataRepresentation {
                    print("📦 ENCODING: Created URL data for file path: \(path)")
                    completionHandler(urlData, nil)
                    return nil
                } else {
                    let error = NSError(domain: "AudioFileDragData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create URL data"])
                    print("📦 ENCODING ERROR: Failed to create URL data for path: \(path)")
                    completionHandler(nil, error)
                    return nil
                }
            }
            
            // Handle specific audio file types
            let fileURL = URL(fileURLWithPath: path)
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if (typeIdentifier == "com.microsoft.waveform-audio" && fileExtension == "wav") ||
               (typeIdentifier == "public.mp3" && fileExtension == "mp3") ||
               (typeIdentifier == "public.audio") {
                
                do {
                    // Check if the file exists and is accessible
                    if FileManager.default.fileExists(atPath: path) {
                        // For audio files, return the actual file data
                        let fileData = try Data(contentsOf: fileURL)
                        print("📦 ENCODING: Created audio file data with size: \(fileData.count) bytes")
                        completionHandler(fileData, nil)
                    } else {
                        let error = NSError(domain: "AudioFileDragData", code: 2, userInfo: [NSLocalizedDescriptionKey: "File not found"])
                        print("📦 ENCODING ERROR: File not found at path: \(path)")
                        completionHandler(nil, error)
                    }
                } catch {
                    print("📦 ENCODING ERROR: Failed to read file data: \(error.localizedDescription)")
                    completionHandler(nil, error)
                }
                return nil
            }
            
            // Handle plain text - just return the path as string data
            if typeIdentifier == UTType.plainText.identifier {
                if let textData = path.data(using: .utf8) {
                    completionHandler(textData, nil)
                    return nil
                }
            }
        }
        
        // For all other type identifiers or if we don't have a path, encode the object as JSON
        do {
            let data = try JSONEncoder().encode(self)
            print("📦 ENCODING: Successfully encoded AudioFileDragData for \(name) with size \(data.count) bytes")
            completionHandler(data, nil)
        } catch {
            print("📦 ENCODING ERROR: Failed to encode AudioFileDragData: \(error.localizedDescription)")
            completionHandler(nil, error)
        }
        return nil
    }
    
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        print("📦 DECODING: Attempting to decode AudioFileDragData with type \(typeIdentifier), data size: \(data.count) bytes")
        
        // Get access to the view model
        let viewModel = AudioDragDropViewModel.shared
        
        // Handle file URL type identifier
        if typeIdentifier == UTType.fileURL.identifier {
            if let url = URL(dataRepresentation: data) {
                print("📦 DECODING: Successfully decoded file URL: \(url.path)")
                
                // Create an AudioFileDragData from the URL
                let fileName = url.lastPathComponent
                let filePath = url.path
                let fileExtension = url.pathExtension
                
                // Create a security-scoped bookmark for this URL
                viewModel.createSecurityScopedBookmark(for: filePath)
                
                return Self(name: fileName, path: filePath, fileExtension: fileExtension, icon: "music.note")
            } else {
                print("📦 DECODING ERROR: Failed to decode file URL from data")
                throw NSError(domain: "AudioFileDragData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode URL from data"])
            }
        }
        
        // Handle plain text - might contain a file path
        if typeIdentifier == UTType.plainText.identifier {
            if let pathString = String(data: data, encoding: .utf8) {
                print("📦 DECODING: Found text data: \(pathString)")
                
                // Check if this is a valid file path
                if FileManager.default.fileExists(atPath: pathString) {
                    let url = URL(fileURLWithPath: pathString)
                    let fileName = url.lastPathComponent
                    let fileExtension = url.pathExtension
                    
                    // Create a security-scoped bookmark for this path
                    viewModel.createSecurityScopedBookmark(for: pathString)
                    
                    return Self(name: fileName, path: pathString, fileExtension: fileExtension, icon: "music.note")
                }
            }
        }
        
        // For audio formats, try to extract path info from AudioDragDropViewModel cache
        if typeIdentifier == "com.microsoft.waveform-audio" || 
           typeIdentifier == "public.mp3" || 
           typeIdentifier == "public.audio" {
            
            // Try to find the most recent drag path
            if let path = viewModel.mostRecentDragPath {
                let url = URL(fileURLWithPath: path)
                let fileName = url.lastPathComponent
                let fileExtension = url.pathExtension
                
                return Self(name: fileName, path: path, fileExtension: fileExtension, icon: "music.note")
            }
        }
        
        // For all other type identifiers, decode as JSON
        do {
            let decoder = JSONDecoder()
            let result = try decoder.decode(Self.self, from: data)
            print("📦 DECODING SUCCESS: Decoded AudioFileDragData for \(result.name), path: \(result.path ?? "nil")")
            return result
        } catch {
            print("📦 DECODING ERROR: \(error.localizedDescription)")
            
            // Try to print the data as a string for debugging
            if let dataString = String(data: data, encoding: .utf8) {
                print("📦 DATA CONTENT (first 100 chars): \(String(dataString.prefix(100)))")
            }
            
            // If all else fails, try to extract from AudioDragDropViewModel
            if let path = viewModel.mostRecentDragPath {
                print("📦 DECODING FALLBACK: Using cached drag path: \(path)")
                let url = URL(fileURLWithPath: path)
                return Self(name: url.lastPathComponent, 
                           path: path, 
                           fileExtension: url.pathExtension, 
                           icon: "music.note")
            }
            
            throw error
        }
    }
}

// Extension to URL for data representation
extension URL {
    var dataRepresentation: Data? {
        // Try to create bookmark data first
        do {
            let bookmarkData = try self.bookmarkData(options: .minimalBookmark, 
                                                  includingResourceValuesForKeys: nil, 
                                                  relativeTo: nil)
            print("📦 URL: Created bookmark data for \(self.path)")
            return bookmarkData
        } catch {
            // Fallback to basic URL archiving
            print("📦 URL: Failed to create bookmark, falling back to basic URL data")
            return self.absoluteString.data(using: .utf8)
        }
    }
    
    init?(dataRepresentation data: Data) {
        // Try to resolve from bookmark data first
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data, 
                            options: .withoutUI, 
                            relativeTo: nil, 
                            bookmarkDataIsStale: &isStale)
            self = url
            return
        } catch {
            // Try as a string URL
            if let urlString = String(data: data, encoding: .utf8), 
               let url = URL(string: urlString) {
                self = url
                return
            }
            
            // If all else fails, check if the data might be a path
            if let pathString = String(data: data, encoding: .utf8),
               FileManager.default.fileExists(atPath: pathString) {
                self = URL(fileURLWithPath: pathString)
                return
            }
            
            return nil
        }
    }
} 