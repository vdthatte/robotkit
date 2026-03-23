import Combine
import Foundation

@MainActor
final class SimulatorViewModel: ObservableObject {
    private struct SignalWindow {
        private let limit: Int
        private(set) var samples: [Int] = []
        private(set) var transitions = 0
        private(set) var lastValue: Int?

        init(limit: Int = 24) {
            self.limit = limit
        }

        mutating func append(_ value: Int) {
            if let lastValue, lastValue != value {
                transitions += 1
            }
            self.lastValue = value
            samples.append(value)
            if samples.count > limit {
                samples.removeFirst(samples.count - limit)
            }
            let maxTransitions = max(limit - 1, 0)
            if transitions > maxTransitions {
                transitions = maxTransitions
            }
        }

        func dutyCycle(window: Int? = nil) -> Double {
            let recent = recentSamples(window: window)
            guard recent.isEmpty == false else { return 0 }
            return Double(recent.reduce(0, +)) / Double(recent.count)
        }

        func edgeActivity(window: Int? = nil) -> Double {
            let recent = recentSamples(window: window)
            guard recent.count > 1 else { return 0 }
            var edges = 0
            for index in 1..<recent.count where recent[index] != recent[index - 1] {
                edges += 1
            }
            return Double(edges) / Double(recent.count - 1)
        }

        private func recentSamples(window: Int?) -> [Int] {
            guard let window else { return samples }
            return Array(samples.suffix(window))
        }
    }

    enum Status: Equatable {
        case idle
        case bootstrapping
        case ready
        case loading
        case running
        case paused
        case stopped
        case failed(String)

        var summary: String {
            switch self {
            case .idle:
                return "Idle"
            case .bootstrapping:
                return "Bootstrapping JavaScript runtime"
            case .ready:
                return "Ready"
            case .loading:
                return "Loading demo"
            case .running:
                return "Running"
            case .paused:
                return "Paused"
            case .stopped:
                return "Stopped"
            case .failed(let message):
                return "Error: \(message)"
            }
        }
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var logs: [String] = [
        "[host] RobotKit reset to a clean slate",
        "[host] Native macOS shell initialized"
    ]
    @Published private(set) var serialLines: [String] = []
    @Published private(set) var buildDiagnostics: [String] = []
    @Published private(set) var pinStates: [String: Int] = [:]
    @Published private(set) var frameCount = 0
    @Published private(set) var totalCycles = 0
    @Published private(set) var loadedDemoName = ""
    @Published private(set) var firmwareStatus = "Bundled firmware"
    @Published private(set) var toolchainStatus = FirmwareBuildService.toolchainStatus()
    @Published private(set) var workspaceSummary = "Current workspace"
    @Published var environment = SimulationEnvironmentState()
    @Published private(set) var worldSnapshot = SimulationWorldSnapshot()

    private let runtime = JavaScriptRuntimeHost()
    private var timer: Timer?
    private var currentProject: RobotProject?
    private var currentWorkspaceURL: URL?
    private var activeInputOverrides: [String: Int] = [:]
    private var currentActiveButtons: Set<String> = []
    private var roverOffset: Double = 0
    private var roverHeading: Double = 0
    private var signalWindows: [String: SignalWindow] = [:]
    private var motorVelocity: [String: Double] = [:]
    private var servoAngles: [String: Double] = [:]
    private var speakerLevel: Double = 0
    private var frameStepInFlight = false

    init() {
        runtime.onLog = { [weak self] message in
            Task { @MainActor in
                self?.appendLog(message)
            }
        }

        runtime.onPinChanged = { [weak self] event in
            Task { @MainActor in
                self?.pinStates[event.pin] = event.value
                self?.totalCycles = max(self?.totalCycles ?? 0, event.cycles)
            }
        }

        runtime.onSerialWrite = { [weak self] event in
            Task { @MainActor in
                self?.serialLines.append("[\(event.baudRate) baud] \(event.text)")
            }
        }
    }

    var engineName: String {
        runtime.engineName
    }

    var isBootstrapped: Bool {
        runtime.isBootstrapped
    }

    var isRunning: Bool {
        if case .running = status {
            return true
        }
        return false
    }

    func refreshToolchainStatus() {
        toolchainStatus = FirmwareBuildService.toolchainStatus()
    }

    func bootstrapIfNeeded() async {
        guard !runtime.isBootstrapped else { return }
        status = .bootstrapping
        appendLog("[runtime] Loading JavaScriptCore bridge")
        refreshToolchainStatus()

        do {
            let bootInfo = try runtime.bootstrap()
            status = .ready
            appendLog("[runtime] Runtime bootstrapped via \(bootInfo.transport)")
            appendLog("[runtime] Engines: \(bootInfo.engineNames.joined(separator: ", "))")
        } catch {
            status = .failed(error.localizedDescription)
            appendLog("[runtime] Bootstrap failed: \(error.localizedDescription)")
        }
    }

    func start(project: RobotProject? = nil, workspaceURL: URL? = nil) {
        if let project {
            currentProject = project
        }
        if let workspaceURL {
            currentWorkspaceURL = workspaceURL
        }

        guard runtime.isBootstrapped else { return }
        guard let activeProject = currentProject else {
            status = .failed("No project loaded")
            return
        }

        stopTimer()
        status = .loading
        frameCount = 0
        totalCycles = 0
        pinStates = [:]
        serialLines = []
        buildDiagnostics = []
        activeInputOverrides = [:]
        currentActiveButtons = []
        worldSnapshot = SimulationWorldSnapshot()
        roverOffset = 0
        roverHeading = 0
        signalWindows = [:]
        motorVelocity = [:]
        servoAngles = [:]
        speakerLevel = 0
        frameStepInFlight = false
        refreshToolchainStatus()
        workspaceSummary = workspaceURL?.lastPathComponent ?? "Current workspace"

        do {
            let preparedFirmware = try FirmwareBuildService.prepareFirmware(for: activeProject, workspaceURL: workspaceURL)
            let loadInfo = try runtime.loadProject(activeProject, firmwareHex: preparedFirmware.hex)
            try synchronizeInputs(project: activeProject, activeButtons: [])
            firmwareStatus = preparedFirmware.detail
            buildDiagnostics = preparedFirmware.diagnostics
            loadedDemoName = activeProject.demo.name
            appendLog("[runtime] Loaded \(loadInfo.demoID) for \(loadInfo.boardID) (\(loadInfo.programBytes) bytes)")
            appendLog("[runtime] Firmware source: \(preparedFirmware.detail)")
            for line in preparedFirmware.diagnostics.prefix(12) {
                appendLog("[build] \(line)")
            }
            recordSignalSample()
            refreshWorldSnapshot()
            status = .running
            appendLog("[runtime] Simulation loop started")
            startTimer()
        } catch {
            status = .failed(error.localizedDescription)
            appendLog("[runtime] Demo load failed: \(error.localizedDescription)")
        }
    }

    func stop() {
        stopTimer()
        frameStepInFlight = false
        status = .stopped
        appendLog("[runtime] Simulation loop stopped")
    }

    func pause() {
        guard isRunning else { return }
        stopTimer()
        frameStepInFlight = false
        status = .paused
        appendLog("[runtime] Simulation loop paused")
    }

    func resume() {
        guard runtime.isBootstrapped, currentProject != nil else { return }
        guard isRunning == false else { return }
        startTimer()
        status = .running
        appendLog("[runtime] Simulation loop resumed")
    }

    func reset() {
        guard let currentProject else { return }
        appendLog("[runtime] Resetting loaded program")
        start(project: currentProject, workspaceURL: currentWorkspaceURL)
    }

    func step() {
        guard runtime.isBootstrapped else { return }
        if currentProject == nil {
            return
        }
        if case .idle = status {
            return
        }
        stopTimer()
        guard frameStepInFlight == false else { return }
        frameStepInFlight = true
        runtime.stepFrameAsync { [weak self] result in
            guard let self else { return }
            self.frameStepInFlight = false
            switch result {
            case .success(let frame):
                self.frameCount = frame.frame
                self.totalCycles = frame.cycles
                self.recordSignalSample()
                self.refreshWorldSnapshot()
                do {
                    if let currentProject = self.currentProject {
                        try self.synchronizeInputs(project: currentProject, activeButtons: self.currentActiveButtons)
                    }
                    self.status = .paused
                } catch {
                    self.status = .failed(error.localizedDescription)
                    self.appendLog("[runtime] Input sync failed: \(error.localizedDescription)")
                }
            case .failure(let error):
                self.status = .failed(error.localizedDescription)
                self.appendLog("[runtime] Frame step failed: \(error.localizedDescription)")
            }
        }
    }

    func rebuildAndStart(project: RobotProject, workspaceURL: URL?) {
        start(project: project, workspaceURL: workspaceURL)
    }

    func pinValue(for pin: String) -> Int {
        pinStates[pin, default: 0]
    }

    func synchronizeInputs(project: RobotProject, activeButtons: Set<String>) throws {
        currentActiveButtons = activeButtons
        let nextOverrides = CircuitGraph.boardInputOverrides(
            in: project,
            activeButtons: activeButtons,
            environment: environment,
            roverOffset: roverOffset
        )
        let allPins = Set(activeInputOverrides.keys).union(nextOverrides.keys)

        for pin in allPins.sorted() {
            if let nextValue = nextOverrides[pin] {
                try runtime.setInputPin(pin, value: nextValue)
            } else {
                try runtime.setInputPin(pin, value: nil)
            }
        }

        activeInputOverrides = nextOverrides
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                self?.advanceOneFrame()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func advanceOneFrame() {
        guard isRunning else { return }
        guard frameStepInFlight == false else { return }
        frameStepInFlight = true
        runtime.stepFrameAsync { [weak self] result in
            guard let self else { return }
            self.frameStepInFlight = false
            switch result {
            case .success(let frame):
                self.frameCount = frame.frame
                self.totalCycles = frame.cycles
                self.recordSignalSample()
                self.refreshWorldSnapshot()
                do {
                    if let currentProject = self.currentProject, self.requiresContinuousInputSync(for: currentProject) {
                        try self.synchronizeInputs(project: currentProject, activeButtons: self.currentActiveButtons)
                    }
                } catch {
                    self.stopTimer()
                    self.status = .failed(error.localizedDescription)
                    self.appendLog("[runtime] Input sync failed: \(error.localizedDescription)")
                }
            case .failure(let error):
                self.stopTimer()
                self.status = .failed(error.localizedDescription)
                self.appendLog("[runtime] Frame step failed: \(error.localizedDescription)")
            }
        }
    }

    private func requiresContinuousInputSync(for project: RobotProject) -> Bool {
        project.parts.contains { $0.kind == .lineSensor }
    }

    private func appendLog(_ line: String) {
        logs.append(line)
    }

    func updateEnvironment(_ mutate: (inout SimulationEnvironmentState) -> Void) {
        mutate(&environment)
        guard let currentProject else { return }
        do {
            try synchronizeInputs(project: currentProject, activeButtons: currentActiveButtons)
            refreshWorldSnapshot()
        } catch {
            appendLog("[world] Environment update failed: \(error.localizedDescription)")
        }
    }

    func triggerAssistantReply() {
        let prompt = environment.assistantPrompt.lowercased()
        let reply: String
        if prompt.contains("water") || prompt.contains("plant") {
            reply = "Check the soil card and pump relay."
        } else if prompt.contains("line") || prompt.contains("rover") {
            reply = "The rover follows the line by balancing left and right sensors."
        } else if prompt.contains("lamp") {
            reply = "The talking lamp is listening for a trigger and color output."
        } else {
            reply = "Desk assistant ready. Ask about plants, lamps, rover, or the hand."
        }
        worldSnapshot.lamp.assistantReply = reply
        serialLines.append("[assistant] \(reply)")
    }

    private func refreshWorldSnapshot() {
        guard let currentProject else { return }
        var snapshot = SimulationWorldSnapshot()
        snapshot.plant.soilPercent = environment.soilMoisture
        snapshot.plant.lightPercent = environment.ambientLight
        snapshot.plant.temperatureC = environment.temperatureC
        snapshot.plant.humidity = environment.humidity

        let soilHigh = currentProject.parts.filter { $0.kind == .soilSensor }.contains {
            sensorState(for: $0, outputPin: "OUT") == 1
        }
        let lightHigh = currentProject.parts.filter { $0.kind == .lightSensor }.contains {
            sensorState(for: $0, outputPin: "OUT") == 1
        }
        let climateHigh = currentProject.parts.filter { $0.kind == .climateSensor }.contains {
            sensorState(for: $0, outputPin: "DATA") == 1
        }
        snapshot.plant.soilAlert = soilHigh
        snapshot.plant.lightAlert = lightHigh
        snapshot.plant.climateAlert = climateHigh
        snapshot.plant.relayActive = currentProject.parts.filter { $0.kind == .relay }.contains {
            CircuitGraph.relayIsActive($0, in: currentProject, pinStates: pinStates)
        }

        if let lampPart = currentProject.parts.first(where: { $0.kind == .rgbLamp }) {
            let redLevel = pinEnergy(for: CircuitGraph.drivingBoardPins(for: lampPart, pin: "R", in: currentProject))
            let greenLevel = pinEnergy(for: CircuitGraph.drivingBoardPins(for: lampPart, pin: "G", in: currentProject))
            let blueLevel = pinEnergy(for: CircuitGraph.drivingBoardPins(for: lampPart, pin: "B", in: currentProject))
            snapshot.lamp.redLevel = redLevel
            snapshot.lamp.greenLevel = greenLevel
            snapshot.lamp.blueLevel = blueLevel
            snapshot.lamp.red = redLevel > 0.15
            snapshot.lamp.green = greenLevel > 0.15
            snapshot.lamp.blue = blueLevel > 0.15
        }
        if let speakerPart = currentProject.parts.first(where: { $0.kind == .speaker || $0.kind == .buzzer }) {
            let inputPin = speakerPart.kind == .speaker ? "SIG" : "+"
            let targetSpeakerLevel = pinEnergy(for: CircuitGraph.drivingBoardPins(for: speakerPart, pin: inputPin, in: currentProject))
            speakerLevel = blend(current: speakerLevel, target: targetSpeakerLevel, factor: 0.35)
            snapshot.lamp.speakerLevel = speakerLevel
            snapshot.lamp.speakerActive = speakerLevel > 0.12
        }
        if worldSnapshot.lamp.assistantReply != "Awaiting prompt" {
            snapshot.lamp.assistantReply = worldSnapshot.lamp.assistantReply
        }

        let leftMotor = currentProject.parts.first(where: { $0.kind == .motor && $0.attributes["side"] == "left" }).map {
            CircuitGraph.motorPower(for: $0, in: currentProject, pinStates: pinStates)
        } ?? 0
        let rightMotor = currentProject.parts.first(where: { $0.kind == .motor && $0.attributes["side"] == "right" }).map {
            CircuitGraph.motorPower(for: $0, in: currentProject, pinStates: pinStates)
        } ?? 0
        motorVelocity["left"] = blend(current: motorVelocity["left", default: 0], target: leftMotor, factor: 0.18)
        motorVelocity["right"] = blend(current: motorVelocity["right", default: 0], target: rightMotor, factor: 0.18)
        let leftVelocity = motorVelocity["left", default: 0]
        let rightVelocity = motorVelocity["right", default: 0]
        roverHeading = blend(current: roverHeading, target: (rightVelocity - leftVelocity) * 30, factor: 0.18)
        roverOffset += roverHeading * 0.0025
        roverOffset = min(max(roverOffset, -1.2), 1.2)
        snapshot.rover.leftMotorPower = leftVelocity
        snapshot.rover.rightMotorPower = rightVelocity
        snapshot.rover.lateralOffset = roverOffset
        snapshot.rover.heading = roverHeading
        snapshot.rover.leftSensorOnLine = sensorOutputState(kind: .lineSensor, side: "left") == 0
        snapshot.rover.rightSensorOnLine = sensorOutputState(kind: .lineSensor, side: "right") == 0

        if let servo = currentProject.parts.first(where: { $0.kind == .servo }) {
            let signalPins = CircuitGraph.drivingBoardPins(for: servo, pin: "SIG", in: currentProject)
            let signalLevel = pinDutyCycle(for: signalPins, window: 10)
            let signalEdges = pinEdgeActivity(for: signalPins, window: 10)
            let targetAngle: Double
            if max(signalLevel, signalEdges) < 0.05 {
                targetAngle = environment.handTarget * 180
            } else {
                targetAngle = signalLevel > 0.5 ? 155 : 20
            }
            let smoothedAngle = blend(current: servoAngles[servo.id, default: 0], target: targetAngle, factor: 0.22)
            servoAngles[servo.id] = smoothedAngle
            snapshot.mechanism.servoAngle = smoothedAngle
            snapshot.mechanism.handClosed = snapshot.mechanism.servoAngle > 45
            snapshot.mechanism.gripCommand = environment.handTarget
        }

        let i2cActivity = pinEnergy(for: ["A4", "A5"])
        snapshot.display.protocolActivity = i2cActivity > 0.08 ? "I2C active" : (serialLines.isEmpty ? "Idle" : "Serial mirrored")
        snapshot.display.oledSummary = latestDisplaySummary(for: snapshot)

        worldSnapshot = snapshot
    }

    private func sensorOutputState(kind: PartKind, side: String? = nil) -> Int {
        guard let currentProject else { return 0 }
        guard let sensor = currentProject.parts.first(where: {
            $0.kind == kind && (side == nil || $0.attributes["side"] == side)
        }) else {
            return 0
        }
        let outputPin = sensor.kind == .climateSensor ? "DATA" : (sensor.kind == .potentiometer ? "2" : "OUT")
        return sensorState(for: sensor, outputPin: outputPin)
    }

    private func sensorState(for sensor: PartDefinition, outputPin: String) -> Int {
        guard let currentProject else { return 0 }
        let boardPins = CircuitGraph.reachablePins(
            from: PinReference(partID: sensor.id, pin: outputPin),
            in: currentProject
        )
        let boardPinNames = boardPins.filter { $0.partID == "board" }.map(\.pin)
        return boardPinNames.contains { activeInputOverrides[$0] == 1 } ? 1 : 0
    }

    private func recordSignalSample() {
        guard let currentProject else { return }
        for pin in currentProject.board.canvasPins {
            let key = pinKey(pin)
            var window = signalWindows[key] ?? SignalWindow()
            window.append(pinStates[pin, default: 0])
            signalWindows[key] = window
        }
    }

    private func pinDutyCycle(for pins: [String], window: Int? = nil) -> Double {
        guard pins.isEmpty == false else { return 0 }
        return pins
            .compactMap { signalWindows[pinKey($0)]?.dutyCycle(window: window) }
            .max() ?? 0
    }

    private func pinEdgeActivity(for pins: [String], window: Int? = nil) -> Double {
        guard pins.isEmpty == false else { return 0 }
        return pins
            .compactMap { signalWindows[pinKey($0)]?.edgeActivity(window: window) }
            .max() ?? 0
    }

    private func pinEnergy(for pins: [String]) -> Double {
        max(pinDutyCycle(for: pins, window: 12), pinEdgeActivity(for: pins, window: 12) * 0.75)
    }

    private func latestDisplaySummary(for snapshot: SimulationWorldSnapshot) -> String {
        if let lastSerial = serialLines.last, lastSerial.isEmpty == false {
            return lastSerial
        }
        if snapshot.plant.relayActive || snapshot.plant.soilAlert || snapshot.plant.lightAlert || snapshot.plant.climateAlert {
            return String(
                format: "soil %.0f%% light %.0f%% temp %.0fC hum %.0f%%",
                snapshot.plant.soilPercent * 100,
                snapshot.plant.lightPercent * 100,
                snapshot.plant.temperatureC,
                snapshot.plant.humidity * 100
            )
        }
        if abs(snapshot.rover.leftMotorPower) > 0.05 || abs(snapshot.rover.rightMotorPower) > 0.05 {
            return String(
                format: "rover L %.2f R %.2f offset %.2f",
                snapshot.rover.leftMotorPower,
                snapshot.rover.rightMotorPower,
                snapshot.rover.lateralOffset
            )
        }
        if snapshot.mechanism.servoAngle > 0 {
            return String(format: "servo %.0f deg", snapshot.mechanism.servoAngle)
        }
        if snapshot.lamp.speakerActive || snapshot.lamp.red || snapshot.lamp.green || snapshot.lamp.blue {
            return snapshot.lamp.assistantReply
        }
        return "No bus activity"
    }

    private func blend(current: Double, target: Double, factor: Double) -> Double {
        current + (target - current) * factor
    }

    private func pinKey(_ pin: String) -> String {
        "board:\(pin)"
    }
}
