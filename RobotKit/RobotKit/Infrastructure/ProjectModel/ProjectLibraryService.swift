import Foundation

enum ProjectLibraryService {
    static func libraryRootURL() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ProjectPersistenceError.appSupportUnavailable
        }

        let rootURL = appSupportURL
            .appendingPathComponent("RobotKit", isDirectory: true)
            .appendingPathComponent("Projects", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    static func bundleURL(for projectIdentifier: String) throws -> URL {
        try libraryRootURL()
            .appendingPathComponent(projectIdentifier, isDirectory: true)
            .appendingPathExtension("robotkit")
    }

    static func existingBundleURLs() throws -> [URL] {
        let rootURL = try libraryRootURL()
        return try FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension == "robotkit" }
        .sorted { lhs, rhs in
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    static func suggestedUntitledName(existingNames: [String]) -> String {
        let base = "Untitled Project"
        guard existingNames.contains(base) else { return base }

        var index = 2
        while existingNames.contains("\(base) \(index)") {
            index += 1
        }
        return "\(base) \(index)"
    }
}
