import Foundation
import Testing
@testable import RobotKit

struct RobotKitTests {
    @Test
    func starterProjectUsesJavaScriptCoreRuntime() {
        let starter = ProjectBundleLoader.loadStarterProject()
        #expect(starter.runtime == .javaScriptCore)
        #expect(starter.board.id == "arduino-uno")
        #expect(starter.parts.count == 3)
        #expect(starter.diagram.wires.count == 3)
    }

    @Test
    @MainActor
    func projectStoreMovesPartAndPersists() throws {
        let store = ProjectStore()
        store.movePart(id: "led1", to: CanvasPoint(x: 720, y: 264))

        #expect(store.project.parts.first(where: { $0.id == "led1" })?.position == CanvasPoint(x: 720, y: 264))
        #expect(store.lastSavedURL != nil)
        #expect(store.lastSaveError == nil)
    }

    @Test
    @MainActor
    func projectStoreCanCreateNewProjectAndAddPart() {
        let store = ProjectStore()
        store.newProject(named: "Workbench")
        store.addPart(kind: .button)

        #expect(store.project.name == "Workbench")
        #expect(store.project.diagram.wires.isEmpty)
        #expect(store.project.parts.contains(where: { $0.kind == .board }))
        #expect(store.project.parts.contains(where: { $0.kind == .button }))
    }

    @Test
    @MainActor
    func projectStoreCanCreatePinToPinWire() {
        let store = ProjectStore()
        store.newProject(named: "Wired")
        store.addPart(kind: .led)
        guard let led = store.project.parts.first(where: { $0.kind == .led }) else {
            Issue.record("LED part was not created")
            return
        }

        store.createWire(from: .init(partID: "board", pin: "D13"), to: .init(partID: led.id, pin: "A"))

        #expect(store.project.diagram.wires.contains(where: {
            $0.from == PinReference(partID: "board", pin: "D13")
                && $0.to == PinReference(partID: led.id, pin: "A")
        }))
    }

    @Test
    @MainActor
    func projectStoreCanDeleteSelectedWire() throws {
        let store = ProjectStore()
        store.newProject(named: "Delete Wire")
        store.addPart(kind: .led)
        guard let led = store.project.parts.first(where: { $0.kind == .led }) else {
            Issue.record("LED part was not created")
            return
        }

        store.createWire(from: .init(partID: "board", pin: "D13"), to: .init(partID: led.id, pin: "A"))
        let wireID = try #require(store.project.diagram.wires.first?.id)
        store.selectWire(id: wireID)
        store.deleteSelection()

        #expect(store.project.diagram.wires.isEmpty)
    }

    @Test
    @MainActor
    func projectStorePersistsEditedSourceCode() throws {
        let store = ProjectStore()
        let editedSource = """
        void setup() {
          pinMode(13, OUTPUT);
        }

        void loop() {
          digitalWrite(13, HIGH);
          delay(100);
          digitalWrite(13, LOW);
          delay(100);
        }
        """

        store.updateSourceCode(editedSource)
        store.persist()

        let savedSource = try String(
            contentsOf: try #require(store.lastSavedURL).appendingPathComponent(store.project.demo.source),
            encoding: .utf8
        )

        #expect(savedSource == editedSource)
    }

    @Test
    @MainActor
    func projectStoreCanAddSecondarySourceFile() throws {
        let store = ProjectStore()
        store.addSourceFile()
        let addedFile = try #require(store.project.files.first(where: { $0.path != "sketch.ino" && $0.kind == .source }))
        store.selectFile(path: addedFile.path)
        store.updateSourceCode("#pragma once\nint answer();\n")
        store.persist()

        let savedSource = try String(
            contentsOf: try #require(store.lastSavedURL).appendingPathComponent(addedFile.path),
            encoding: .utf8
        )

        #expect(savedSource.contains("answer"))
    }

    @Test
    @MainActor
    func projectStoreCanLoadLineFollowerTemplate() {
        let store = ProjectStore()
        store.loadTemplate(.lineFollower)

        #expect(store.project.name == "Line Follower")
        #expect(store.project.parts.contains(where: { $0.kind == .lineSensor }))
        #expect(store.project.parts.contains(where: { $0.kind == .motorDriver }))
        #expect(store.sourceFiles["sketch.ino"]?.contains("LEFT_SENSOR") == true)
    }

    @Test
    func partCatalogContainsDFRobotMotorDriverMetadata() throws {
        let entry = try #require(PartCatalog.entry(id: "dfrobot.gravity.tb6612"))
        #expect(entry.vendor == .dfrobot)
        #expect(entry.kind == .motorDriver)
        #expect(entry.electricalInterfaces.contains(where: { $0.signals.contains(.motor) }))
        #expect(entry.functionalInterfaces.contains(where: { $0.role == .actuatorPower }))
        #expect(entry.compatibility.isEmpty == false)
    }

    @Test
    @MainActor
    func projectStoreCanPlaceCatalogBackedDFRobotPart() throws {
        let store = ProjectStore()
        store.newProject(named: "DFRobot")
        let entry = try #require(PartCatalog.entry(id: "dfrobot.gravity.ultrasonic"))
        store.addPart(catalogEntry: entry, at: CanvasPoint(x: 480, y: 220))

        let placed = try #require(store.project.parts.first(where: { $0.attributes["catalog"] == entry.id }))
        #expect(placed.kind == .distanceSensorModule)
        #expect(placed.pins == ["TRIG", "ECHO", "VCC", "GND"])
    }

    @Test
    @MainActor
    func projectStoreCanSaveAndReloadProjectBundle() throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("robotkit-project-\(UUID().uuidString).robotkit", isDirectory: true)
        let store = ProjectStore()
        store.newProject(named: "Round Trip")
        store.addPart(kind: .button)
        store.updateSourceCode("void setup() {}\nvoid loop() {}")
        store.saveAs(to: workspaceURL)

        let reloaded = try ProjectBundleLoader.loadProject(from: workspaceURL)
        let source = try ProjectArtifactLoader.loadTextFile(named: reloaded.demo.source, workspaceURL: workspaceURL)

        #expect(reloaded.name == "Round Trip")
        #expect(reloaded.parts.contains(where: { $0.kind == .button }))
        #expect(source == "void setup() {}\nvoid loop() {}")
    }

    @Test
    func circuitGraphFindsActiveLedThroughResistor() {
        let starter = ProjectBundleLoader.loadStarterProject()
        let led = starter.parts.first(where: { $0.kind == .led })!

        #expect(CircuitGraph.partIsActive(led, in: starter, pinStates: ["D13": 1]))
        #expect(CircuitGraph.partIsActive(led, in: starter, pinStates: ["D13": 0]) == false)
    }

    @Test
    @MainActor
    func circuitGraphComputesPressedButtonInputOverride() {
        let store = ProjectStore()
        store.newProject(named: "Inputs")
        store.addPart(kind: .button)
        guard let button = store.project.parts.first(where: { $0.kind == .button }) else {
            Issue.record("Button part was not created")
            return
        }

        store.createWire(from: .init(partID: "board", pin: "D2"), to: .init(partID: button.id, pin: "1"))
        store.createWire(from: .init(partID: "board", pin: "GND"), to: .init(partID: button.id, pin: "3"))

        let overrides = CircuitGraph.boardInputOverrides(in: store.project, activeButtons: [button.id])
        #expect(overrides["D2"] == 0)
    }

    @Test
    func circuitGraphFindsLitSevenSegment() {
        let project = RobotProject(
            schemaVersion: 1,
            name: "Segments",
            runtime: .javaScriptCore,
            board: .arduinoUno,
            demo: DemoDefinition(id: "test", name: "Test", binary: "blink.hex", source: "sketch.ino", observedPins: ["D2", "D3"]),
            files: [
                ProjectFile(name: "project.json", path: "project.json", kind: .manifest),
                ProjectFile(name: "diagram.robotkit.json", path: "diagram.robotkit.json", kind: .diagram),
                ProjectFile(name: "sketch.ino", path: "sketch.ino", kind: .source),
                ProjectFile(name: "blink.hex", path: "blink.hex", kind: .firmware)
            ],
            diagram: RobotDiagram(
                parts: [
                    PartDefinition(id: "board", kind: .board, label: "Arduino Uno", pins: BoardDefinition.arduinoUno.canvasPins, position: CanvasPoint(x: 100, y: 100), attributes: ["footprint": "uno"], pinBindings: [:]),
                    PartDefinition(id: "seg1", kind: .sevenSegment, label: "7-Segment", pins: PartKind.sevenSegment.defaultPins, position: CanvasPoint(x: 300, y: 100), attributes: PartKind.sevenSegment.defaultAttributes, pinBindings: [:])
                ],
                wires: [
                    WireDefinition(id: "1", from: PinReference(partID: "board", pin: "D2"), to: PinReference(partID: "seg1", pin: "A"), color: "green", midX: nil),
                    WireDefinition(id: "2", from: PinReference(partID: "board", pin: "GND"), to: PinReference(partID: "seg1", pin: "COM"), color: "black", midX: nil)
                ]
            )
        )

        let lit = CircuitGraph.litSegments(for: project.diagram.parts[1], in: project, pinStates: ["D2": 1])
        #expect(lit.contains("A"))
    }

    @Test
    func circuitGraphComputesMotorPowerFromDriverPins() {
        let (project, _) = ProjectTemplateFactory.makeProject(for: .lineFollower)
        let motor = try! #require(project.parts.first(where: { $0.kind == .motor && $0.attributes["side"] == "left" }))
        let power = CircuitGraph.motorPower(for: motor, in: project, pinStates: ["D5": 1, "D6": 1, "D7": 0, "D8": 1])
        #expect(power == 1)
    }

    @Test
    func circuitGraphComputesPlantSensorOverrides() {
        let (project, _) = ProjectTemplateFactory.makeProject(for: .plantMonitoring)
        let overrides = CircuitGraph.boardInputOverrides(
            in: project,
            activeButtons: [],
            environment: SimulationEnvironmentState(soilMoisture: 0.2, ambientLight: 0.2, temperatureC: 24, humidity: 0.82, voiceTriggerLevel: 0, handTarget: 0.5, baseLineOffset: 0, assistantPrompt: ""),
            roverOffset: 0
        )
        #expect(overrides["D2"] == 1)
        #expect(overrides["D3"] == 1)
        #expect(overrides["D4"] == 1)
    }

    @Test
    func circuitGraphLeavesClimateSensorLowWhenEnvironmentIsStable() {
        let (project, _) = ProjectTemplateFactory.makeProject(for: .plantMonitoring)
        let overrides = CircuitGraph.boardInputOverrides(
            in: project,
            activeButtons: [],
            environment: SimulationEnvironmentState(soilMoisture: 0.65, ambientLight: 0.7, temperatureC: 23, humidity: 0.45, voiceTriggerLevel: 0, handTarget: 0.5, baseLineOffset: 0, assistantPrompt: ""),
            roverOffset: 0
        )
        #expect(overrides["D4"] == 0)
    }

    @Test
    func projectArtifactLoaderPrefersWorkspaceBundle() throws {
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("robotkit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: true)
        try "workspace hex".write(
            to: workspaceURL.appendingPathComponent("blink.hex"),
            atomically: true,
            encoding: .utf8
        )

        let loaded = try ProjectArtifactLoader.loadTextFile(named: "blink.hex", workspaceURL: workspaceURL)

        #expect(loaded == "workspace hex")
    }

    @Test
    func javaScriptRuntimeBootsAndStepsBlinkDemo() throws {
        let starter = ProjectBundleLoader.loadStarterProject()
        let firmwareHex = try ProjectArtifactLoader.loadTextFile(named: starter.demo.binary)
        let runtime = JavaScriptRuntimeHost()
        var events: [RuntimePinEvent] = []

        runtime.onPinChanged = { events.append($0) }
        runtime.onLog = { _ in }

        let boot = try runtime.bootstrap()
        #expect(boot.engineNames.contains("avr8js"))

        let load = try runtime.loadProject(starter, firmwareHex: firmwareHex)
        #expect(load.boardID == "arduino-uno")
        #expect(load.programBytes > 0)

        for _ in 0..<20 {
            _ = try runtime.stepFrame()
        }

        #expect(events.contains(where: { $0.pin == "D13" && $0.value == 1 }))
        #expect(events.contains(where: { $0.pin == "D13" && $0.value == 0 }))
    }

    @Test
    func javaScriptRuntimeEmitsAlternatingSerialForBlinkDemo() throws {
        let starter = ProjectBundleLoader.loadStarterProject()
        let firmwareHex = try ProjectArtifactLoader.loadTextFile(named: starter.demo.binary)
        let runtime = JavaScriptRuntimeHost()
        var serialEvents: [RuntimeSerialEvent] = []

        runtime.onSerialWrite = { serialEvents.append($0) }
        runtime.onLog = { _ in }

        _ = try runtime.bootstrap()
        _ = try runtime.loadProject(starter, firmwareHex: firmwareHex)

        for _ in 0..<80 {
            _ = try runtime.stepFrame()
        }

        #expect(serialEvents.contains(where: { $0.text.contains("RobotKit D13 HIGH") }))
        #expect(serialEvents.contains(where: { $0.text.contains("RobotKit D13 LOW") }))
    }

    @Test
    @MainActor
    func simulatorViewModelEmitsAlternatingSerialForBlinkDemo() async throws {
        let starter = ProjectBundleLoader.loadStarterProject()
        let simulator = SimulatorViewModel()

        await simulator.bootstrapIfNeeded()
        simulator.start(project: starter, workspaceURL: nil)

        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if simulator.serialLines.contains(where: { $0.contains("RobotKit D13 HIGH") }) &&
                simulator.serialLines.contains(where: { $0.contains("RobotKit D13 LOW") }) {
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        simulator.stop()

        #expect(simulator.serialLines.contains(where: { $0.contains("RobotKit D13 HIGH") }))
        #expect(simulator.serialLines.contains(where: { $0.contains("RobotKit D13 LOW") }))
    }

    @Test
    func locallyCompiledFirmwareEmitsAlternatingSerialForBlinkDemo() throws {
        let starter = ProjectBundleLoader.loadStarterProject()
        let workspaceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("robotkit-local-compile-\(UUID().uuidString).robotkit", isDirectory: true)

        try ProjectPersistenceService.save(starter, destinationURL: workspaceURL)
        let firmware = try FirmwareBuildService.prepareFirmware(for: starter, workspaceURL: workspaceURL)
        let runtime = JavaScriptRuntimeHost()
        var serialEvents: [RuntimeSerialEvent] = []

        runtime.onSerialWrite = { serialEvents.append($0) }
        runtime.onLog = { _ in }

        _ = try runtime.bootstrap()
        _ = try runtime.loadProject(starter, firmwareHex: firmware.hex)

        for _ in 0..<80 {
            _ = try runtime.stepFrame()
        }

        #expect(firmware.source == .compiled || firmware.source == .existingArtifact)
        #expect(serialEvents.contains(where: { $0.text.contains("RobotKit D13 HIGH") }))
        #expect(serialEvents.contains(where: { $0.text.contains("RobotKit D13 LOW") }))
    }

    @Test
    func customPartDraftCreatesCatalogBackedEntry() {
        var draft = CustomPartDraft()
        draft.displayName = "Capacitive Water Probe"
        draft.kind = .analogSensorModule
        draft.defaultPinsText = "AOUT,DOUT,VCC,GND"
        draft.defaultAttributesText = "family=water-probe\nthreshold=0.42"
        let entry = draft.makeEntry()

        #expect(entry.vendor == .custom)
        #expect(entry.id == "custom.capacitive-water-probe")
        #expect(entry.defaultAttributes["threshold"] == "0.42")
        #expect(entry.defaultAttributes["catalog"] == "custom.capacitive-water-probe")
    }
}
