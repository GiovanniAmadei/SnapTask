import SwiftUI

struct AppIconOption: Identifiable, Hashable {
    let id: String
    let displayName: String
    let alternateName: String?
    let previewAssetName: String?
    let iconFileBaseNames: [String]
}

@MainActor
final class AppIconManager: ObservableObject {
    static let shared = AppIconManager()
    
    @Published private(set) var currentAlternateIconName: String? = UIApplication.shared.alternateIconName
    
    private var previewImageCache: [String: UIImage] = [:]
    private var pngFileIndex: [String: String] = [:]
    private var didBuildIndex = false
    private let excludedAlternateIconNames: Set<String> = ["AppIconDark"]
    
    var availableIcons: [AppIconOption] {
        var options: [AppIconOption] = []
        let info = Bundle.main.infoDictionary ?? [:]
        let displayName = info["CFBundleDisplayName"] as? String ?? "Default"
        
        options.append(AppIconOption(
            id: "primary",
            displayName: displayName,
            alternateName: nil,
            previewAssetName: "AppIconPreview",
            iconFileBaseNames: []
        ))
        
        guard let iconsDict = info["CFBundleIcons"] as? [String: Any],
              let alternate = iconsDict["CFBundleAlternateIcons"] as? [String: Any] else {
            return options
        }

        for key in alternate.keys.sorted(by: { $0.lowercased() < $1.lowercased() }) {
            if excludedAlternateIconNames.contains(key) { continue }
            var files: [String] = []
            if let item = alternate[key] as? [String: Any],
               let arr = item["CFBundleIconFiles"] as? [String] {
                files = arr
            }
            options.append(AppIconOption(
                id: key,
                displayName: prettify(name: key),
                alternateName: key,
                previewAssetName: "\(key)Preview",
                iconFileBaseNames: files
            ))
        }
        return options
    }
    
    func refresh() {
        currentAlternateIconName = UIApplication.shared.alternateIconName
        objectWillChange.send()
        if let name = currentAlternateIconName, excludedAlternateIconNames.contains(name) {
            setIcon(to: nil, completion: nil)
        }
    }
    
    func setIcon(to alternateName: String?, completion: ((Error?) -> Void)? = nil) {
        guard UIApplication.shared.alternateIconName != alternateName else {
            completion?(nil); return
        }
        UIApplication.shared.setAlternateIconName(alternateName) { [weak self] error in
            if error == nil {
                self?.currentAlternateIconName = alternateName
                self?.objectWillChange.send() // Force UI update
            }
            completion?(error)
        }
    }
    
    private func prettify(name: String) -> String {
        return name
            .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }
    
    // MARK: - Preview Image Resolver
    
    func previewImage(for option: AppIconOption) -> UIImage? {
        let cacheKey = option.alternateName ?? "primary"
        if let cached = previewImageCache[cacheKey] { return cached }

        buildPngFileIndexIfNeeded()

        var resolvedImage: UIImage?
        
        // 1. Try dedicated preview asset first (e.g., "NeonPreview")
        if let assetName = option.previewAssetName, let img = UIImage(named: assetName) {
            resolvedImage = img
        }
        
        // 2. Try finding the actual icon files using the index
        if resolvedImage == nil {
            let searchNames = option.iconFileBaseNames + [option.alternateName].compactMap { $0 }
            for baseName in searchNames {
                if let path = findPathInIndex(forName: baseName) {
                    resolvedImage = UIImage(contentsOfFile: path)
                    break
                }
            }
        }
        
        // 3. For primary icon, use its dedicated preview asset as final fallback
        if resolvedImage == nil && option.alternateName == nil {
             if let img = UIImage(named: "AppIconPreview") {
                 resolvedImage = img
             }
        }

        if let finalImage = resolvedImage {
            previewImageCache[cacheKey] = finalImage
        }
        
        return resolvedImage
    }

    func previewImageForCurrent() -> UIImage? {
        let currentOption = availableIcons.first { $0.alternateName == currentAlternateIconName }
        guard let option = currentOption ?? availableIcons.first else { return nil }
        return previewImage(for: option)
    }

    private func findPathInIndex(forName name: String) -> String? {
        let cleanName = cleanKey(name)
        return pngFileIndex[cleanName]
    }

    private func buildPngFileIndexIfNeeded() {
        guard !didBuildIndex else { return }
        didBuildIndex = true

        guard let resourcePath = Bundle.main.resourcePath,
              let allFiles = try? FileManager.default.subpathsOfDirectory(atPath: resourcePath) else {
            return
        }

        let pngFiles = allFiles.filter { $0.lowercased().hasSuffix(".png") }

        for filePath in pngFiles {
            let filenameWithExt = (filePath as NSString).lastPathComponent
            let filename = (filenameWithExt as NSString).deletingPathExtension

            let key = cleanKey(filename)

            if !key.isEmpty {
                let fullPath = (resourcePath as NSString).appendingPathComponent(filePath)
                pngFileIndex[key] = fullPath
            }
        }
    }

    private func cleanKey(_ s: String) -> String {
        return s
            .lowercased()
            .replacingOccurrences(of: "@2x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "@3x", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"[^a-z0-9]"#, with: "", options: .regularExpression)
    }
}