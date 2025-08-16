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
    
    static func loadImage(from path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
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