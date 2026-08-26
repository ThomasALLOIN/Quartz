import Foundation

/// Résout les ressources dans les deux contextes pris en charge par Quartz :
/// l’aperçu SwiftPM et le bundle macOS distribué.
enum QuartzResources {
    private static var isPackagedApplication: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    static var resourceURL: URL? {
        if isPackagedApplication {
            guard let appResources = Bundle.main.resourceURL else { return nil }
            let packageBundleURL = appResources.appendingPathComponent(
                "Quartz_QuartzApp.bundle",
                isDirectory: true
            )
            if let packageBundle = Bundle(url: packageBundleURL) {
                return packageBundle.resourceURL
            }
            return appResources
        }

        return Bundle.module.resourceURL
    }

    static func url(forResource name: String, withExtension fileExtension: String) -> URL? {
        guard let resourceURL else { return nil }
        let candidate = resourceURL
            .appendingPathComponent(name)
            .appendingPathExtension(fileExtension)
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }
}
