import Foundation

enum ProjectPersistenceError: LocalizedError {
    case appSupportUnavailable

    var errorDescription: String? {
        switch self {
        case .appSupportUnavailable:
            return "Application Support directory is unavailable"
        }
    }
}

enum ProjectPersistenceService {
    static func save(
        _ project: RobotProject,
        destinationURL: URL? = nil,
        sourceWorkspaceURL: URL? = nil,
        artifactOverrides: [String: String] = [:]
    ) throws -> URL {
        let bundleURL = if let destinationURL {
            destinationURL
        } else {
            try workspaceBundleURL()
        }
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let projectData = try encoder.encode(project)
        let diagramData = try encoder.encode(project.diagram)
        let physicalData = try encoder.encode(project.physical)

        try projectData.write(to: bundleURL.appendingPathComponent("project.json"), options: .atomic)
        try diagramData.write(to: bundleURL.appendingPathComponent("diagram.robotkit.json"), options: .atomic)
        try physicalData.write(to: bundleURL.appendingPathComponent("physical.robotkit.json"), options: .atomic)

        for sourceFile in project.files where sourceFile.kind == .source || sourceFile.kind == .cad {
            try copyArtifactIfPresent(
                named: sourceFile.path,
                to: bundleURL,
                sourceWorkspaceURL: sourceWorkspaceURL,
                artifactOverrides: artifactOverrides
            )
        }
        try copyArtifactIfPresent(
            named: project.demo.binary,
            to: bundleURL,
            sourceWorkspaceURL: sourceWorkspaceURL,
            artifactOverrides: artifactOverrides
        )

        return bundleURL
    }

    static func workspaceBundleURL() throws -> URL {
        try ProjectLibraryService.libraryRootURL()
            .appendingPathComponent("CurrentProject", isDirectory: true)
            .appendingPathExtension("robotkit")
    }

    private static func copyArtifactIfPresent(
        named name: String,
        to bundleURL: URL,
        sourceWorkspaceURL: URL?,
        artifactOverrides: [String: String]
    ) throws {
        if let override = artifactOverrides[name] {
            try override.write(to: bundleURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
            return
        }

        let source = try? ProjectArtifactLoader.loadTextFile(named: name, workspaceURL: sourceWorkspaceURL)
        guard let source else { return }
        try source.write(to: bundleURL.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
}
