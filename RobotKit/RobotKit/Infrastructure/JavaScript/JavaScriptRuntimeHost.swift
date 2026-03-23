import Foundation
import JavaScriptCore

enum JavaScriptRuntimeError: LocalizedError {
    case contextUnavailable
    case bootstrapFailed
    case runtimeBundleMissing
    case functionUnavailable(String)
    case invocationFailed(String)

    var errorDescription: String? {
        switch self {
        case .contextUnavailable:
            return "JavaScriptCore context was not created"
        case .bootstrapFailed:
            return "Bootstrap script did not return success"
        case .runtimeBundleMissing:
            return "The bundled JavaScript runtime is missing"
        case .functionUnavailable(let name):
            return "Missing JavaScript runtime function '\(name)'"
        case .invocationFailed(let message):
            return message
        }
    }
}

@objc protocol RobotKitHostExports: JSExport {
    func log(_ message: String)
    func pinChanged(_ payload: String)
    func serialWrite(_ payload: String)
}

final class JavaScriptRuntimeHost {
    var onLog: ((String) -> Void)?
    var onPinChanged: ((RuntimePinEvent) -> Void)?
    var onSerialWrite: ((RuntimeSerialEvent) -> Void)?

    private let queue = DispatchQueue(label: "graam.robotkit.javascript-runtime")
    private var context: JSContext?
    private let runtimeScriptURL: URL?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private(set) var isBootstrapped = false
    private(set) var lastBootInfo: RuntimeBootInfo?

    let engineName = "JavaScriptCore + avr8js"

    init(runtimeScriptURL: URL? = JavaScriptRuntimeHost.defaultRuntimeScriptURL()) {
        self.runtimeScriptURL = runtimeScriptURL
    }

    func bootstrap() throws -> RuntimeBootInfo {
        try queue.sync {
            let context = JSContext()
            context?.exceptionHandler = { _, exception in
                if let exception {
                    NSLog("RobotKit JS exception: %@", exception.toString())
                }
            }

            guard let context else {
                throw JavaScriptRuntimeError.contextUnavailable
            }

            let bridge = HostBridge(
                onLog: { [weak self] message in
                    self?.onLog?(message)
                },
                onPinChanged: { [weak self] payload in
                    guard
                        let self,
                        let data = payload.data(using: .utf8),
                        let event = try? self.decoder.decode(RuntimePinEvent.self, from: data)
                    else {
                        return
                    }
                    self.onPinChanged?(event)
                },
                onSerialWrite: { [weak self] payload in
                    guard
                        let self,
                        let data = payload.data(using: .utf8),
                        let event = try? self.decoder.decode(RuntimeSerialEvent.self, from: data)
                    else {
                        return
                    }
                    self.onSerialWrite?(event)
                }
            )

            context.setObject(bridge, forKeyedSubscript: "robotKitHost" as NSString)

            guard
                let runtimeScriptURL,
                let runtimeScript = try? String(contentsOf: runtimeScriptURL, encoding: .utf8)
            else {
                throw JavaScriptRuntimeError.runtimeBundleMissing
            }

            self.context = context
            context.evaluateScript(runtimeScript)
            do {
                let result = try self.invoke(function: "boot")

                guard result["ok"] as? Bool == true else {
                    throw JavaScriptRuntimeError.bootstrapFailed
                }

                let bootInfo = RuntimeBootInfo(
                    engineNames: result["engines"] as? [String] ?? [],
                    runtimeName: result["runtime"] as? String ?? "Unknown",
                    transport: result["transport"] as? String ?? "Unknown"
                )

                self.isBootstrapped = true
                self.lastBootInfo = bootInfo
                return bootInfo
            } catch {
                self.context = nil
                self.isBootstrapped = false
                self.lastBootInfo = nil
                throw error
            }
        }
    }

    func loadProject(_ project: RobotProject, firmwareHex: String) throws -> RuntimeLoadInfo {
        try queue.sync {
            let payload = RuntimeProjectLoadRequest(project: project)
            let jsonData = try encoder.encode(payload)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw JavaScriptRuntimeError.invocationFailed("Failed to encode project payload")
            }

            let result = try invoke(function: "loadProject", arguments: [jsonString, firmwareHex])
            return RuntimeLoadInfo(
                boardID: result["board"] as? String ?? "unknown",
                programBytes: result["programBytes"] as? Int ?? 0,
                demoID: result["demo"] as? String ?? project.demo.id
            )
        }
    }

    func stepFrame() throws -> RuntimeFrameInfo {
        let result = try invoke(function: "stepFrame")
        return RuntimeFrameInfo(
            frame: result["frame"] as? Int ?? 0,
            cycles: result["cycles"] as? Int ?? 0
        )
    }

    func stepFrameAsync(_ completion: @escaping (Result<RuntimeFrameInfo, Error>) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            let result = Result { try self.stepFrame() }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    func reset() throws {
        try queue.sync {
            _ = try invoke(function: "reset")
        }
    }

    func setInputPin(_ pin: String, value: Int?) throws {
        try queue.sync {
            _ = try invoke(function: "setInputPin", arguments: [pin, value as Any])
        }
    }

    private func invoke(function name: String, arguments: [Any] = []) throws -> [String: Any] {
        guard let runtime = context?.objectForKeyedSubscript("robotkit") else {
            throw JavaScriptRuntimeError.functionUnavailable(name)
        }

        guard let function = runtime.objectForKeyedSubscript(name), !function.isUndefined else {
            throw JavaScriptRuntimeError.functionUnavailable(name)
        }

        let result = function.call(withArguments: arguments)
        if let exception = context?.exception {
            throw JavaScriptRuntimeError.invocationFailed(exception.toString())
        }

        guard let payload = result?.toObject() as? [String: Any] else {
            throw JavaScriptRuntimeError.invocationFailed("JavaScript function '\(name)' did not return a dictionary")
        }

        if payload["ok"] as? Bool == false {
            let message = payload["error"] as? String ?? "JavaScript runtime call failed"
            throw JavaScriptRuntimeError.invocationFailed(message)
        }

        return payload
    }

    private static func defaultRuntimeScriptURL() -> URL? {
        let candidateBundles = [
            Bundle.main,
            Bundle(for: HostBridge.self)
        ]

        for bundle in candidateBundles {
            if let url = bundle.url(
                forResource: "robotkit-runtime.bundle",
                withExtension: "js",
                subdirectory: "JavaScript"
            ) {
                return url
            }

            if let url = bundle.url(
                forResource: "robotkit-runtime.bundle",
                withExtension: "js"
            ) {
                return url
            }
        }

        let fallback = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("RobotKit/Resources/JavaScript/robotkit-runtime.bundle.js")

        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }
}

private final class HostBridge: NSObject, RobotKitHostExports {
    private let onLogHandler: (String) -> Void
    private let onPinChangedHandler: (String) -> Void
    private let onSerialWriteHandler: (String) -> Void

    init(
        onLog: @escaping (String) -> Void,
        onPinChanged: @escaping (String) -> Void,
        onSerialWrite: @escaping (String) -> Void
    ) {
        self.onLogHandler = onLog
        self.onPinChangedHandler = onPinChanged
        self.onSerialWriteHandler = onSerialWrite
    }

    func log(_ message: String) {
        onLogHandler(message)
    }

    func pinChanged(_ payload: String) {
        onPinChangedHandler(payload)
    }

    func serialWrite(_ payload: String) {
        onSerialWriteHandler(payload)
    }
}
