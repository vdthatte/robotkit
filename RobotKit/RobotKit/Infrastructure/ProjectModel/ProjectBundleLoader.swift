import Foundation

enum ProjectBundleLoader {
    static func loadStarterProject() -> RobotProject {
        let decoder = JSONDecoder()

        guard
            let projectURL = resourceURL(
                named: "project",
                withExtension: "json",
                subdirectory: "StarterProject"
            ),
            let diagramURL = resourceURL(
                named: "diagram.robotkit",
                withExtension: "json",
                subdirectory: "StarterProject"
            ),
            let projectData = try? Data(contentsOf: projectURL),
            let diagramData = try? Data(contentsOf: diagramURL),
            var project = try? decoder.decode(RobotProject.self, from: projectData),
            let diagram = try? decoder.decode(RobotDiagram.self, from: diagramData)
        else {
            return .starter
        }

        project.diagram = diagram
        if let physicalURL = resourceURL(
            named: "physical.robotkit",
            withExtension: "json",
            subdirectory: "StarterProject"
        ),
        let physicalData = try? Data(contentsOf: physicalURL),
        let physical = try? decoder.decode(RobotPhysicalDesign.self, from: physicalData) {
            project.physical = physical
        }
        project.prepareForWorkspace()
        return project
    }

    static func loadProject(from workspaceURL: URL) throws -> RobotProject {
        let decoder = JSONDecoder()

        guard
            let projectURL = resolvedURL(
                named: "project",
                withExtension: "json",
                subdirectory: "StarterProject",
                workspaceURL: workspaceURL
            ),
            let diagramURL = resolvedURL(
                named: "diagram.robotkit",
                withExtension: "json",
                subdirectory: "StarterProject",
                workspaceURL: workspaceURL
            ),
            let projectData = try? Data(contentsOf: projectURL),
            let diagramData = try? Data(contentsOf: diagramURL),
            var project = try? decoder.decode(RobotProject.self, from: projectData),
            let diagram = try? decoder.decode(RobotDiagram.self, from: diagramData)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        project.diagram = diagram
        let workspacePhysicalURL = workspaceURL.appendingPathComponent("physical.robotkit.json")
        if FileManager.default.fileExists(atPath: workspacePhysicalURL.path),
           let physicalData = try? Data(contentsOf: workspacePhysicalURL),
           let physical = try? decoder.decode(RobotPhysicalDesign.self, from: physicalData) {
            project.physical = physical
        }
        project.prepareForWorkspace()
        return project
    }

    private static func resolvedURL(
        named name: String,
        withExtension extensionName: String,
        subdirectory: String,
        workspaceURL: URL
    ) -> URL? {
        let workspaceCandidate = workspaceURL.appendingPathComponent("\(name).\(extensionName)")
        if FileManager.default.fileExists(atPath: workspaceCandidate.path) {
            return workspaceCandidate
        }

        return resourceURL(named: name, withExtension: extensionName, subdirectory: subdirectory)
    }

    private static func resourceURL(
        named name: String,
        withExtension extensionName: String,
        subdirectory: String
    ) -> URL? {
        let candidateBundles = [
            Bundle.main,
            Bundle(for: BundleLocator.self)
        ]

        for bundle in candidateBundles {
            if let url = bundle.url(forResource: name, withExtension: extensionName, subdirectory: subdirectory) {
                return url
            }

            if let url = bundle.url(forResource: name, withExtension: extensionName) {
                return url
            }
        }

        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("RobotKit/Resources/\(subdirectory)/\(name).\(extensionName)")

        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}

private final class BundleLocator {}
