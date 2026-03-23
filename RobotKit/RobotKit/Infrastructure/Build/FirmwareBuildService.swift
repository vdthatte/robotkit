import Foundation

enum FirmwareSource: Equatable {
    case compiled
    case existingArtifact
}

struct PreparedFirmware: Equatable {
    let hex: String
    let source: FirmwareSource
    let detail: String
    let diagnostics: [String]
}

struct ToolchainStatus: Equatable {
    let arduinoCLIPath: String?
    let canCompileUno: Bool
    let statusMessage: String
}

enum FirmwareBuildService {
    static func toolchainStatus() -> ToolchainStatus {
        if let arduinoCLIPath = ToolLocator.executablePath(named: "arduino-cli") {
            return ToolchainStatus(
                arduinoCLIPath: arduinoCLIPath,
                canCompileUno: true,
                statusMessage: "arduino-cli available"
            )
        }

        return ToolchainStatus(
            arduinoCLIPath: nil,
            canCompileUno: false,
            statusMessage: "arduino-cli not installed; using bundled firmware"
        )
    }

    static func prepareFirmware(for project: RobotProject, workspaceURL: URL? = nil) throws -> PreparedFirmware {
        let toolchain = toolchainStatus()
        var buildFailure: String?

        if let arduinoCLIPath = toolchain.arduinoCLIPath {
            do {
                return try compileWithArduinoCLI(project: project, arduinoCLIPath: arduinoCLIPath, workspaceURL: workspaceURL)
            } catch {
                buildFailure = error.localizedDescription
            }
        }

        let artifactHex = try ProjectArtifactLoader.loadTextFile(named: project.demo.binary, workspaceURL: workspaceURL)
        let detail: String
        if let buildFailure {
            detail = "Build failed; using existing firmware artifact (\(buildFailure))"
        } else if workspaceURL != nil {
            detail = "Using saved firmware artifact"
        } else {
            detail = toolchain.statusMessage
        }

        return PreparedFirmware(
            hex: artifactHex,
            source: .existingArtifact,
            detail: detail,
            diagnostics: buildFailure.map { [$0] } ?? []
        )
    }

    private static func compileWithArduinoCLI(
        project: RobotProject,
        arduinoCLIPath: String,
        workspaceURL: URL?
    ) throws -> PreparedFirmware {
        let sketchFilename = project.demo.source
        let sketchBaseName = (sketchFilename as NSString).deletingPathExtension
        let buildWorkspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("robotkit-build-\(UUID().uuidString)", isDirectory: true)
        let sketchURL = buildWorkspaceURL.appendingPathComponent(sketchBaseName, isDirectory: true)
        let outputURL = buildWorkspaceURL.appendingPathComponent("out", isDirectory: true)

        try FileManager.default.createDirectory(at: sketchURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

        for file in project.files where file.kind == .source {
            let source = try ProjectArtifactLoader.loadTextFile(named: file.path, workspaceURL: workspaceURL)
            let fileURL = sketchURL.appendingPathComponent(file.name)
            try source.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        let result = try ShellCommand.run(
            launchPath: arduinoCLIPath,
            arguments: [
                "compile",
                "--fqbn", "arduino:avr:uno",
                sketchURL.path,
                "--output-dir", outputURL.path
            ]
        )

        guard result.exitCode == 0 else {
            throw ShellCommandError.failed(result.standardError.isEmpty ? result.standardOutput : result.standardError)
        }

        let contents = try FileManager.default.contentsOfDirectory(at: outputURL, includingPropertiesForKeys: nil)
        let hexURL = preferredHexURL(in: contents)
        guard let hexURL else {
            throw ShellCommandError.failed("arduino-cli compile succeeded but produced no .hex artifact")
        }

        let hex = try String(contentsOf: hexURL, encoding: .utf8)
        if let workspaceURL {
            try hex.write(
                to: workspaceURL.appendingPathComponent(project.demo.binary),
                atomically: true,
                encoding: .utf8
            )
        }

        return PreparedFirmware(
            hex: hex,
            source: .compiled,
            detail: "Compiled locally with arduino-cli",
            diagnostics: combinedDiagnostics(from: result)
        )
    }

    private static func combinedDiagnostics(from result: ShellCommandResult) -> [String] {
        let output = [result.standardOutput, result.standardError]
            .joined(separator: "\n")
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        return Array(output.prefix(24))
    }

    private static func preferredHexURL(in contents: [URL]) -> URL? {
        let hexFiles = contents.filter { $0.pathExtension == "hex" }
        return hexFiles.first(where: { !$0.lastPathComponent.contains("with_bootloader") }) ?? hexFiles.first
    }
}

private enum ToolLocator {
    static func executablePath(named name: String) -> String? {
        let environmentPaths = (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        let searchDirectories = environmentPaths + [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin"
        ]

        for directory in searchDirectories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(name).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

private struct ShellCommandResult {
    let exitCode: Int32
    let standardOutput: String
    let standardError: String
}

private enum ShellCommandError: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

private enum ShellCommand {
    static func run(launchPath: String, arguments: [String]) throws -> ShellCommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let standardOutput = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let standardError = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        return ShellCommandResult(
            exitCode: process.terminationStatus,
            standardOutput: standardOutput,
            standardError: standardError
        )
    }
}
