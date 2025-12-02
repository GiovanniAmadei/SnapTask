import Foundation
import UIKit

enum AttachmentService {
    private static var attachmentsRoot: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Attachments", isDirectory: true)
    }
    
    private static func taskFolder(for taskId: UUID) -> URL {
        attachmentsRoot.appendingPathComponent(taskId.uuidString, isDirectory: true)
    }
    
    private static func journalFolder(for entryId: UUID) -> URL {
        attachmentsRoot.appendingPathComponent("Journal", isDirectory: true)
            .appendingPathComponent(entryId.uuidString, isDirectory: true)
    }
    
    // MARK: - Task Photos
    
    static func savePhoto(for taskId: UUID, imageData: Data) -> (photoPath: String, thumbnailPath: String)? {
        guard let original = UIImage(data: imageData) else { return nil }
        
        // Downscale to max dimension 1600 px
        let maxDim: CGFloat = 1600
        let scaled = downscale(image: original, maxDimension: maxDim)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        
        // Thumbnail ~200 px
        let thumb = downscale(image: scaled, maxDimension: 200)
        guard let thumbJpeg = thumb.jpegData(compressionQuality: 0.8) else { return nil }
        
        // Ensure folders
        let folder = taskFolder(for: taskId)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        let photoURL = folder.appendingPathComponent("photo.jpg")
        let thumbURL = folder.appendingPathComponent("thumb.jpg")
        
        do {
            try jpeg.write(to: photoURL, options: .atomic)
            try thumbJpeg.write(to: thumbURL, options: .atomic)
            return (photoURL.path, thumbURL.path)
        } catch {
            return nil
        }
    }
    
    static func addPhoto(for taskId: UUID, imageData: Data) -> TaskPhoto? {
        guard let original = UIImage(data: imageData) else { return nil }
        let scaled = downscale(image: original, maxDimension: 1600)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        
        let thumb = downscale(image: scaled, maxDimension: 200)
        guard let thumbJpeg = thumb.jpegData(compressionQuality: 0.8) else { return nil }
        
        let folder = taskFolder(for: taskId)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        let uid = UUID().uuidString
        let photoURL = folder.appendingPathComponent("photo_\(uid).jpg")
        let thumbURL = folder.appendingPathComponent("thumb_\(uid).jpg")
        
        do {
            try jpeg.write(to: photoURL, options: .atomic)
            try thumbJpeg.write(to: thumbURL, options: .atomic)
            return TaskPhoto(photoPath: photoURL.path, thumbnailPath: thumbURL.path, createdAt: Date())
        } catch {
            return nil
        }
    }
    
    static func deletePhoto(for taskId: UUID, photo: TaskPhoto) {
        if FileManager.default.fileExists(atPath: photo.photoPath) {
            try? FileManager.default.removeItem(atPath: photo.photoPath)
        }
        if FileManager.default.fileExists(atPath: photo.thumbnailPath) {
            try? FileManager.default.removeItem(atPath: photo.thumbnailPath)
        }
        
        // Optionally remove empty folder
        let folder = taskFolder(for: taskId)
        if let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path), items.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }
    
    static func deletePhoto(for taskId: UUID) {
        let folder = taskFolder(for: taskId)
        try? FileManager.default.removeItem(at: folder)
    }
    
    // MARK: - Journal Photos
    
    static func addJournalPhoto(for entryId: UUID, imageData: Data, id: UUID, createdAt: Date) -> JournalPhoto? {
        guard let original = UIImage(data: imageData) else { return nil }
        let scaled = downscale(image: original, maxDimension: 1600)
        guard let jpeg = scaled.jpegData(compressionQuality: 0.85) else { return nil }
        
        let thumb = downscale(image: scaled, maxDimension: 200)
        guard let thumbJpeg = thumb.jpegData(compressionQuality: 0.8) else { return nil }
        
        let folder = journalFolder(for: entryId)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        
        let photoURL = folder.appendingPathComponent("photo_\(id.uuidString).jpg")
        let thumbURL = folder.appendingPathComponent("thumb_\(id.uuidString).jpg")
        
        do {
            try jpeg.write(to: photoURL, options: .atomic)
            try thumbJpeg.write(to: thumbURL, options: .atomic)
            return JournalPhoto(id: id, photoPath: photoURL.path, thumbnailPath: thumbURL.path, createdAt: createdAt)
        } catch {
            return nil
        }
    }
    
    static func deleteJournalPhoto(for entryId: UUID, photo: JournalPhoto) {
        if FileManager.default.fileExists(atPath: photo.photoPath) {
            try? FileManager.default.removeItem(atPath: photo.photoPath)
        }
        if FileManager.default.fileExists(atPath: photo.thumbnailPath) {
            try? FileManager.default.removeItem(atPath: photo.thumbnailPath)
        }
        
        // Optionally remove empty folder
        let folder = journalFolder(for: entryId)
        if let items = try? FileManager.default.contentsOfDirectory(atPath: folder.path), items.isEmpty {
            try? FileManager.default.removeItem(at: folder)
        }
    }
    
    // MARK: - Common
    
    static func loadImage(from path: String) -> UIImage? {
        // First try the exact path
        if let image = UIImage(contentsOfFile: path) {
            return image
        }
        
        // If path doesn't work, try to reconstruct it
        // This handles cases where the app's sandbox path changed (reinstall, update, etc.)
        let filename = (path as NSString).lastPathComponent
        let parentFolder = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        
        // Try to find the file in the current Documents/Attachments directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let possiblePaths = [
            // Try Attachments/parentFolder/filename
            docs.appendingPathComponent("Attachments").appendingPathComponent(parentFolder).appendingPathComponent(filename).path,
            // Try just Attachments/filename
            docs.appendingPathComponent("Attachments").appendingPathComponent(filename).path,
            // Try VoiceMemos/parentFolder/filename (for voice memos)
            docs.appendingPathComponent("VoiceMemos").appendingPathComponent(parentFolder).appendingPathComponent(filename).path
        ]
        
        for possiblePath in possiblePaths {
            if let image = UIImage(contentsOfFile: possiblePath) {
                return image
            }
        }
        
        return nil
    }
    
    /// Resolves a potentially stale file path to a valid current path
    static func resolveFilePath(_ path: String) -> String? {
        // First check if the path exists as-is
        if FileManager.default.fileExists(atPath: path) {
            return path
        }
        
        // Try to reconstruct the path
        let filename = (path as NSString).lastPathComponent
        let parentFolder = ((path as NSString).deletingLastPathComponent as NSString).lastPathComponent
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Build list of possible paths to check
        var possiblePaths: [String] = []
        
        // Try Attachments folder (where voice memos are stored)
        possiblePaths.append(docs.appendingPathComponent("Attachments").appendingPathComponent(parentFolder).appendingPathComponent(filename).path)
        possiblePaths.append(docs.appendingPathComponent("Attachments").appendingPathComponent(filename).path)
        
        // Try VoiceMemos folder (legacy location)
        possiblePaths.append(docs.appendingPathComponent("VoiceMemos").appendingPathComponent(parentFolder).appendingPathComponent(filename).path)
        possiblePaths.append(docs.appendingPathComponent("VoiceMemos").appendingPathComponent(filename).path)
        
        // Try searching in all Attachments subfolders
        let attachmentsFolder = docs.appendingPathComponent("Attachments")
        if let subfolders = try? FileManager.default.contentsOfDirectory(atPath: attachmentsFolder.path) {
            for subfolder in subfolders {
                let potentialPath = attachmentsFolder.appendingPathComponent(subfolder).appendingPathComponent(filename).path
                possiblePaths.append(potentialPath)
            }
        }
        
        for possiblePath in possiblePaths {
            if FileManager.default.fileExists(atPath: possiblePath) {
                return possiblePath
            }
        }
        
        return nil
    }
    
    private static func downscale(image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxCurrent = max(size.width, size.height)
        guard maxCurrent > maxDimension else { return image }
        let scale = maxDimension / maxCurrent
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}