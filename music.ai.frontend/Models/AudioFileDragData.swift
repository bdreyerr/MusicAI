import Foundation

/// Class for representing audio file data during drag and drop operations
class AudioFileDragData: NSObject, NSItemProviderWriting, NSItemProviderReading, Codable {
    static var writableTypeIdentifiersForItemProvider: [String] {
        return ["com.music.ai.audiofile", "public.data", "public.content", "public.item", "public.file-url"]
    }
    
    static var readableTypeIdentifiersForItemProvider: [String] {
        return ["com.music.ai.audiofile", "public.data", "public.content", "public.item", "public.file-url"]
    }
    
    let name: String
    let path: String?
    let fileExtension: String?
    let icon: String
    
    init(item: FolderItem) {
        self.name = item.name
        self.path = item.metadata?["path"]
        self.fileExtension = item.metadata?["extension"]
        self.icon = item.icon
        super.init()
        print("📦 CREATED: AudioFileDragData for \(name), path: \(path ?? "nil")")
    }
    
    // Required initializer for NSItemProviderReading
    required init(name: String, path: String?, fileExtension: String?, icon: String) {
        self.name = name
        self.path = path
        self.fileExtension = fileExtension
        self.icon = icon
        super.init()
        print("📦 INITIALIZED: AudioFileDragData with name: \(name), path: \(path ?? "nil")")
    }
    
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping (Data?, Error?) -> Void) -> Progress? {
        print("📦 LOADING DATA: For type identifier: \(typeIdentifier)")
        
        // Handle file URL type identifier differently
        if typeIdentifier == "public.file-url", let path = self.path {
            let fileURL = URL(fileURLWithPath: path)
            let urlData = try? NSKeyedArchiver.archivedData(withRootObject: fileURL, requiringSecureCoding: true)
            
            if let urlData = urlData {
                print("📦 ENCODING: Created URL data for file path: \(path)")
                completionHandler(urlData, nil)
            } else {
                let error = NSError(domain: "AudioFileDragData", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create URL data"])
                print("📦 ENCODING ERROR: Failed to create URL data for path: \(path)")
                completionHandler(nil, error)
            }
            return nil
        }
        
        // For all other type identifiers, encode the object as JSON
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
        
        // Handle file URL type identifier differently
        if typeIdentifier == "public.file-url" {
            do {
                if let url = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSURL.self, from: data) as URL? {
                    print("📦 DECODING: Successfully decoded file URL: \(url.path)")
                    
                    // Create an AudioFileDragData from the URL
                    let fileName = url.lastPathComponent
                    let filePath = url.path
                    let fileExtension = url.pathExtension
                    
                    return Self(name: fileName, path: filePath, fileExtension: fileExtension, icon: "music.note")
                } else {
                    throw NSError(domain: "AudioFileDragData", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode URL from data"])
                }
            } catch {
                print("📦 DECODING ERROR: Failed to decode file URL: \(error.localizedDescription)")
                throw error
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
            print("📦 DECODING ERROR DETAILS: \(error)")
            
            // Try to print the data as a string for debugging
            if let dataString = String(data: data, encoding: .utf8) {
                print("📦 DATA CONTENT: \(dataString)")
            }
            
            throw error
        }
    }
} 