import Foundation

enum ProjectArtifactLoader {
    static func loadTextFile(
        named name: String,
        workspaceURL: URL? = nil,
        in subdirectory: String = "StarterProject"
    ) throws -> String {
        if let workspaceURL {
            let workspaceFileURL = workspaceURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: workspaceFileURL.path) {
                return try String(contentsOf: workspaceFileURL, encoding: .utf8)
            }
        }

        guard let url = resourceURL(named: name, subdirectory: subdirectory) else {
            throw CocoaError(.fileNoSuchFile)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    private static func resourceURL(named name: String, subdirectory: String) -> URL? {
        let filename = (name as NSString).deletingPathExtension
        let fileExtension = (name as NSString).pathExtension

        let candidateBundles = [
            Bundle.main,
            Bundle(for: ArtifactBundleLocator.self)
        ]

        for bundle in candidateBundles {
            if let url = bundle.url(forResource: filename, withExtension: fileExtension, subdirectory: subdirectory) {
                return url
            }
        }

        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("RobotKit/Resources/\(subdirectory)/\(name)")

        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}

private final class ArtifactBundleLocator {}
