import Foundation

struct RobotProject: Codable, Equatable {
    var schemaVersion: Int
    var name: String
    var runtime: RuntimeFlavor
    var board: BoardDefinition
    var demo: DemoDefinition
    var files: [ProjectFile]
    var diagram: RobotDiagram
    var physical: RobotPhysicalDesign

    init(
        schemaVersion: Int,
        name: String,
        runtime: RuntimeFlavor,
        board: BoardDefinition,
        demo: DemoDefinition,
        files: [ProjectFile],
        diagram: RobotDiagram,
        physical: RobotPhysicalDesign? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.name = name
        self.runtime = runtime
        self.board = board
        self.demo = demo
        self.files = files
        self.diagram = diagram
        self.physical = physical ?? .starter(for: diagram.parts)
        prepareForWorkspace()
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case name
        case runtime
        case board
        case demo
        case files
        case diagram
        case physical
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        name = try container.decode(String.self, forKey: .name)
        runtime = try container.decode(RuntimeFlavor.self, forKey: .runtime)
        board = try container.decode(BoardDefinition.self, forKey: .board)
        demo = try container.decode(DemoDefinition.self, forKey: .demo)
        files = try container.decodeIfPresent([ProjectFile].self, forKey: .files) ?? []
        diagram = try container.decodeIfPresent(RobotDiagram.self, forKey: .diagram) ?? RobotDiagram(parts: [], wires: [])
        physical = try container.decodeIfPresent(RobotPhysicalDesign.self, forKey: .physical) ?? .starter(for: diagram.parts)
        prepareForWorkspace()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(name, forKey: .name)
        try container.encode(runtime, forKey: .runtime)
        try container.encode(board, forKey: .board)
        try container.encode(demo, forKey: .demo)
        try container.encode(files, forKey: .files)
        try container.encode(diagram, forKey: .diagram)
        try container.encode(physical, forKey: .physical)
    }

    static let starter = RobotProject(
        schemaVersion: 1,
        name: "RobotKit",
        runtime: .javaScriptCore,
        board: .arduinoUno,
        demo: DemoDefinition(
            id: "uno-blink",
            name: "Uno Blink",
            binary: "blink.hex",
            source: "sketch.ino",
            observedPins: ["D13"]
        ),
        files: [
            ProjectFile(name: "project.json", path: "project.json", kind: .manifest),
            ProjectFile(name: "diagram.robotkit.json", path: "diagram.robotkit.json", kind: .diagram),
            ProjectFile(name: "physical.robotkit.json", path: "physical.robotkit.json", kind: .physical),
            ProjectFile(name: "sketch.ino", path: "sketch.ino", kind: .source),
            ProjectFile(name: "blink.hex", path: "blink.hex", kind: .firmware)
        ],
        diagram: RobotDiagram(
            parts: [
                PartDefinition(
                    id: "board",
                    kind: .board,
                    label: "Arduino Uno",
                    pins: BoardDefinition.arduinoUno.canvasPins,
                    position: .init(x: 180, y: 220),
                    attributes: ["footprint": "uno"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "r1",
                    kind: .resistor,
                    label: "220 ohm",
                    pins: ["1", "2"],
                    position: .init(x: 420, y: 160),
                    attributes: ["value": "220"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "led1",
                    kind: .led,
                    label: "Status LED",
                    pins: ["A", "K"],
                    position: .init(x: 620, y: 180),
                    attributes: ["color": "amber"],
                    pinBindings: ["A": "D13", "K": "GND"]
                )
            ],
            wires: [
                WireDefinition(
                    id: "wire-d13-r1",
                    from: .init(partID: "board", pin: "D13"),
                    to: .init(partID: "r1", pin: "1"),
                    color: "green",
                    midX: nil
                ),
                WireDefinition(
                    id: "wire-r1-led",
                    from: .init(partID: "r1", pin: "2"),
                    to: .init(partID: "led1", pin: "A"),
                    color: "green",
                    midX: nil
                ),
                WireDefinition(
                    id: "wire-led-gnd",
                    from: .init(partID: "led1", pin: "K"),
                    to: .init(partID: "board", pin: "GND"),
                    color: "black",
                    midX: nil
                )
            ]
        ),
        physical: .starter(
            for: [
                PartDefinition(
                    id: "board",
                    kind: .board,
                    label: "Arduino Uno",
                    pins: BoardDefinition.arduinoUno.canvasPins,
                    position: .init(x: 180, y: 220),
                    attributes: ["footprint": "uno"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "r1",
                    kind: .resistor,
                    label: "220 ohm",
                    pins: ["1", "2"],
                    position: .init(x: 420, y: 160),
                    attributes: ["value": "220"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "led1",
                    kind: .led,
                    label: "Status LED",
                    pins: ["A", "K"],
                    position: .init(x: 620, y: 180),
                    attributes: ["color": "amber"],
                    pinBindings: ["A": "D13", "K": "GND"]
                )
            ]
        )
    )

    var parts: [PartDefinition] {
        diagram.parts
    }

    static func untitled(named name: String = "Untitled Project") -> RobotProject {
        var project = RobotProject.starter
        project.name = name
        project.demo = DemoDefinition(
            id: "uno-custom",
            name: "Uno Sketch",
            binary: "blink.hex",
            source: "sketch.ino",
            observedPins: ["D13"]
        )
        project.diagram.parts = [
            PartDefinition(
                id: "board",
                kind: .board,
                label: "Arduino Uno",
                pins: BoardDefinition.arduinoUno.canvasPins,
                position: .init(x: 200, y: 280),
                attributes: ["footprint": "uno"],
                pinBindings: [:]
            )
        ]
        project.diagram.wires = []
        project.physical = .starter(for: project.diagram.parts)
        project.prepareForWorkspace()
        return project
    }

    mutating func prepareForWorkspace() {
        physical.synchronize(with: diagram.parts)
        files = Self.normalizedFiles(from: files, includeEnclosureArtifact: physical.generatedArtifacts.enclosureSCAD.isEmpty == false)
    }

    var generatedTextArtifacts: [String: String] {
        var artifacts: [String: String] = [:]
        if physical.generatedArtifacts.enclosureSCAD.isEmpty == false {
            artifacts["enclosure.scad"] = physical.generatedArtifacts.enclosureSCAD
        }
        return artifacts
    }

    private static func normalizedFiles(from files: [ProjectFile], includeEnclosureArtifact: Bool) -> [ProjectFile] {
        var byPath = Dictionary(uniqueKeysWithValues: files.map { ($0.path, $0) })
        byPath["project.json"] = ProjectFile(name: "project.json", path: "project.json", kind: .manifest)
        byPath["diagram.robotkit.json"] = ProjectFile(name: "diagram.robotkit.json", path: "diagram.robotkit.json", kind: .diagram)
        byPath["physical.robotkit.json"] = ProjectFile(name: "physical.robotkit.json", path: "physical.robotkit.json", kind: .physical)

        if includeEnclosureArtifact {
            byPath["enclosure.scad"] = ProjectFile(name: "enclosure.scad", path: "enclosure.scad", kind: .cad)
        } else {
            byPath.removeValue(forKey: "enclosure.scad")
        }

        let projectData = byPath.values.filter { $0.kind == .manifest || $0.kind == .diagram || $0.kind == .physical }
            .sorted { $0.path < $1.path }
        let sources = byPath.values.filter { $0.kind == .source }
            .sorted { $0.path < $1.path }
        let cadArtifacts = byPath.values.filter { $0.kind == .cad }
            .sorted { $0.path < $1.path }
        let firmware = byPath.values.filter { $0.kind == .firmware }
            .sorted { $0.path < $1.path }

        return projectData + sources + cadArtifacts + firmware
    }
}

enum RuntimeFlavor: String, Codable, Equatable {
    case javaScriptCore
    case nativeCore

    var displayName: String {
        switch self {
        case .javaScriptCore:
            return "JavaScriptCore"
        case .nativeCore:
            return "Native Core"
        }
    }
}

struct BoardDefinition: Codable, Equatable {
    let id: String
    let displayName: String
    let clockDescription: String

    static let arduinoUno = BoardDefinition(
        id: "arduino-uno",
        displayName: "Arduino Uno",
        clockDescription: "16 MHz AVR"
    )

    var canvasPins: [String] {
        switch id {
        case "arduino-uno":
            return [
                "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11", "D12", "D13",
                "A0", "A1", "A2", "A3", "A4", "A5",
                "5V", "GND"
            ]
        default:
            return ["D13", "GND", "5V"]
        }
    }
}

struct DemoDefinition: Codable, Equatable {
    let id: String
    let name: String
    let binary: String
    let source: String
    let observedPins: [String]
}

struct ProjectFile: Identifiable, Codable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let kind: ProjectFileKind
}

enum ProjectFileKind: String, Codable, Equatable {
    case manifest
    case diagram
    case physical
    case source
    case cad
    case firmware

    var displayName: String {
        switch self {
        case .manifest:
            return "Manifest"
        case .diagram:
            return "Diagram"
        case .physical:
            return "Physical"
        case .source:
            return "Source"
        case .cad:
            return "CAD"
        case .firmware:
            return "Firmware"
        }
    }
}

struct RobotDiagram: Codable, Equatable {
    var parts: [PartDefinition]
    var wires: [WireDefinition]
}

struct RobotPhysicalDesign: Codable, Equatable {
    var canvas: PhysicalCanvas
    var enclosure: PhysicalEnclosure
    var placements: [PhysicalPartPlacement]
    var generatedArtifacts: PhysicalGeneratedArtifacts

    static func starter(for parts: [PartDefinition]) -> RobotPhysicalDesign {
        let placements = suggestedPlacements(for: parts)
        return RobotPhysicalDesign(
            canvas: .default,
            enclosure: PhysicalEnclosure.suggested(for: placements),
            placements: placements,
            generatedArtifacts: .empty
        )
    }

    mutating func synchronize(with parts: [PartDefinition]) {
        let existing = Dictionary(uniqueKeysWithValues: placements.map { ($0.partID, $0) })
        placements = parts.enumerated().map { index, part in
            if var placement = existing[part.id] {
                placement.footprint = PhysicalFootprint.resolved(for: part)
                return placement
            }
            return Self.suggestedPlacement(for: part, index: index, compact: false, exposeConnectors: false)
        }
        enclosure = enclosure.updatingToFit(placements)

        if generatedArtifacts.enclosureSCAD.isEmpty == false {
            generatedArtifacts.enclosureSCAD = Self.makeEnclosureSCAD(enclosure: enclosure, placements: placements)
        }
    }

    mutating func autoLayout(for parts: [PartDefinition], compact: Bool = false, exposeConnectors: Bool = false) {
        placements = Self.suggestedPlacements(for: parts, compact: compact, exposeConnectors: exposeConnectors)
        enclosure = PhysicalEnclosure.suggested(for: placements, compact: compact)
        if generatedArtifacts.enclosureSCAD.isEmpty == false {
            generatedArtifacts.enclosureSCAD = Self.makeEnclosureSCAD(enclosure: enclosure, placements: placements)
        }
    }

    mutating func generateEnclosure() {
        enclosure = PhysicalEnclosure.suggested(for: placements)
        generatedArtifacts.enclosureSCAD = Self.makeEnclosureSCAD(enclosure: enclosure, placements: placements)
    }

    func placement(for partID: String) -> PhysicalPartPlacement? {
        placements.first(where: { $0.partID == partID })
    }

    static func suggestedPlacements(
        for parts: [PartDefinition],
        compact: Bool = false,
        exposeConnectors: Bool = false
    ) -> [PhysicalPartPlacement] {
        parts.enumerated().map { index, part in
            suggestedPlacement(for: part, index: index, compact: compact, exposeConnectors: exposeConnectors)
        }
    }

    private static func suggestedPlacement(
        for part: PartDefinition,
        index: Int,
        compact: Bool,
        exposeConnectors: Bool
    ) -> PhysicalPartPlacement {
        let boardCenter = CanvasPoint(x: 340, y: 260)
        if part.kind == .board {
            return PhysicalPartPlacement(
                partID: part.id,
                position: boardCenter,
                rotationDegrees: 0,
                face: .internal,
                mount: .standoff,
                standoffHeight: 8,
                footprint: .resolved(for: part)
            )
        }

        let peripheralIndex = max(0, index - 1)
        let columns = compact ? 2 : 3
        let spacingX = compact ? 140.0 : 180.0
        let spacingY = compact ? 110.0 : 140.0
        let row = peripheralIndex / columns
        let column = peripheralIndex % columns
        let originX = compact ? 540.0 : 520.0
        let originY = compact ? 180.0 : 160.0

        return PhysicalPartPlacement(
            partID: part.id,
            position: CanvasPoint(
                x: originX + (Double(column) * spacingX),
                y: originY + (Double(row) * spacingY)
            ),
            rotationDegrees: defaultRotation(for: part.kind),
            face: defaultFace(for: part.kind, exposeConnectors: exposeConnectors),
            mount: defaultMount(for: part.kind),
            standoffHeight: defaultMount(for: part.kind) == .standoff ? 6 : 0,
            footprint: .resolved(for: part)
        )
    }

    private static func defaultFace(for kind: PartKind, exposeConnectors: Bool) -> PhysicalFace {
        if exposeConnectors {
            switch kind {
            case .led, .speaker, .microphone, .soilSensor, .lightSensor, .climateSensor, .digitalSensorModule,
                 .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule,
                 .lineSensor, .oledDisplay:
                return .front
            case .motor:
                return .side
            default:
                break
            }
        }

        switch kind {
        case .board, .resistor, .shiftRegister, .relay, .motorDriver, .servo, .potentiometer:
            return .internal
        case .motor:
            return .side
        case .speaker, .microphone, .oledDisplay:
            return .top
        case .lineSensor:
            return .bottom
        default:
            return .front
        }
    }

    private static func defaultMount(for kind: PartKind) -> PhysicalMountKind {
        switch kind {
        case .board, .motorDriver, .relay, .oledDisplay:
            return .standoff
        case .motor, .servo:
            return .bracket
        case .led, .speaker, .microphone, .soilSensor, .lightSensor, .climateSensor, .lineSensor,
             .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule,
             .visionSensorModule, .distanceSensorModule:
            return .panel
        default:
            return .adhesive
        }
    }

    private static func defaultRotation(for kind: PartKind) -> Double {
        switch kind {
        case .speaker, .microphone, .motor:
            return 90
        default:
            return 0
        }
    }

    private static func makeEnclosureSCAD(
        enclosure: PhysicalEnclosure,
        placements: [PhysicalPartPlacement]
    ) -> String {
        let lines = placements.map { placement in
            let face = placement.face.rawValue
            return "  // \(placement.partID) \(face) mount \(placement.mount.rawValue)"
        }.joined(separator: "\n")

        return """
        // RobotKit generated enclosure
        // Units: millimeters

        wall = \(format(enclosure.wallThickness));
        width = \(format(enclosure.width));
        height = \(format(enclosure.height));
        depth = \(format(enclosure.depth));

        difference() {
          cube([width, height, depth], center = true);
          translate([0, 0, wall])
            cube([width - wall * 2, height - wall * 2, depth], center = true);
        }

        \(lines)
        """
    }

    private static func format(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

struct PhysicalCanvas: Codable, Equatable {
    var width: Double
    var height: Double
    var grid: Double

    static let `default` = PhysicalCanvas(width: 1080, height: 720, grid: 20)
}

struct PhysicalEnclosure: Codable, Equatable {
    var center: CanvasPoint
    var width: Double
    var height: Double
    var depth: Double
    var wallThickness: Double
    var lidStyle: PhysicalLidStyle

    static func suggested(for placements: [PhysicalPartPlacement], compact: Bool = false) -> PhysicalEnclosure {
        guard placements.isEmpty == false else {
            return PhysicalEnclosure(
                center: CanvasPoint(x: 340, y: 260),
                width: 220,
                height: 160,
                depth: 60,
                wallThickness: 3,
                lidStyle: .snapFit
            )
        }

        let minX = placements.map { $0.position.x - ($0.footprint.width / 2) }.min() ?? 0
        let maxX = placements.map { $0.position.x + ($0.footprint.width / 2) }.max() ?? 0
        let minY = placements.map { $0.position.y - ($0.footprint.height / 2) }.min() ?? 0
        let maxY = placements.map { $0.position.y + ($0.footprint.height / 2) }.max() ?? 0
        let maxDepth = placements.map(\.footprint.depth).max() ?? 24
        let margin = compact ? 52.0 : 72.0

        return PhysicalEnclosure(
            center: CanvasPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2),
            width: max(220, (maxX - minX) + margin * 2),
            height: max(160, (maxY - minY) + margin * 2),
            depth: max(56, maxDepth + 26),
            wallThickness: compact ? 2.4 : 3.0,
            lidStyle: compact ? .screwDown : .snapFit
        )
    }

    func updatingToFit(_ placements: [PhysicalPartPlacement]) -> PhysicalEnclosure {
        let suggested = Self.suggested(for: placements)
        return PhysicalEnclosure(
            center: suggested.center,
            width: suggested.width,
            height: suggested.height,
            depth: max(depth, suggested.depth),
            wallThickness: wallThickness,
            lidStyle: lidStyle
        )
    }
}

struct PhysicalPartPlacement: Identifiable, Codable, Equatable {
    var id: String { partID }
    var partID: String
    var position: CanvasPoint
    var rotationDegrees: Double
    var face: PhysicalFace
    var mount: PhysicalMountKind
    var standoffHeight: Double
    var footprint: PhysicalFootprint
}

struct PhysicalFootprint: Codable, Equatable {
    static let widthAttributeKey = "physical.widthMm"
    static let heightAttributeKey = "physical.heightMm"
    static let depthAttributeKey = "physical.depthMm"

    var width: Double
    var height: Double
    var depth: Double

    static func resolved(for part: PartDefinition) -> PhysicalFootprint {
        let fallback = defaultFootprint(for: part.kind)
        return PhysicalFootprint(
            width: part.attributes[widthAttributeKey].flatMap(Double.init) ?? fallback.width,
            height: part.attributes[heightAttributeKey].flatMap(Double.init) ?? fallback.height,
            depth: part.attributes[depthAttributeKey].flatMap(Double.init) ?? fallback.depth
        )
    }

    static func usesExplicitDimensions(for part: PartDefinition) -> Bool {
        part.attributes[widthAttributeKey] != nil
            || part.attributes[heightAttributeKey] != nil
            || part.attributes[depthAttributeKey] != nil
    }

    static func defaultFootprint(for kind: PartKind) -> PhysicalFootprint {
        switch kind {
        case .board:
            return PhysicalFootprint(width: 100, height: 68, depth: 18)
        case .led:
            return PhysicalFootprint(width: 18, height: 18, depth: 14)
        case .resistor:
            return PhysicalFootprint(width: 28, height: 10, depth: 10)
        case .button:
            return PhysicalFootprint(width: 18, height: 18, depth: 18)
        case .buzzer, .speaker, .microphone:
            return PhysicalFootprint(width: 42, height: 42, depth: 22)
        case .sevenSegment:
            return PhysicalFootprint(width: 30, height: 52, depth: 12)
        case .potentiometer:
            return PhysicalFootprint(width: 28, height: 28, depth: 24)
        case .shiftRegister:
            return PhysicalFootprint(width: 40, height: 18, depth: 12)
        case .soilSensor, .lightSensor, .climateSensor:
            return PhysicalFootprint(width: 58, height: 24, depth: 16)
        case .relay:
            return PhysicalFootprint(width: 52, height: 32, depth: 24)
        case .oledDisplay:
            return PhysicalFootprint(width: 54, height: 28, depth: 14)
        case .rgbLamp:
            return PhysicalFootprint(width: 68, height: 68, depth: 22)
        case .lineSensor:
            return PhysicalFootprint(width: 44, height: 18, depth: 12)
        case .motorDriver:
            return PhysicalFootprint(width: 48, height: 34, depth: 16)
        case .motor:
            return PhysicalFootprint(width: 64, height: 28, depth: 28)
        case .servo:
            return PhysicalFootprint(width: 40, height: 20, depth: 38)
        case .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule,
             .visionSensorModule, .distanceSensorModule:
            return PhysicalFootprint(width: 46, height: 24, depth: 16)
        }
    }
}

struct PhysicalGeneratedArtifacts: Codable, Equatable {
    var enclosureSCAD: String

    static let empty = PhysicalGeneratedArtifacts(enclosureSCAD: "")
}

enum PhysicalFace: String, Codable, Equatable, CaseIterable, Identifiable {
    case `internal`
    case front
    case back
    case top
    case bottom
    case side

    var id: String { rawValue }
}

enum PhysicalMountKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case standoff
    case panel
    case bracket
    case adhesive

    var id: String { rawValue }
}

enum PhysicalLidStyle: String, Codable, Equatable, CaseIterable, Identifiable {
    case snapFit
    case screwDown
    case openFrame

    var id: String { rawValue }
}

struct PartDefinition: Identifiable, Codable, Equatable {
    let id: String
    let kind: PartKind
    var label: String
    let pins: [String]
    var position: CanvasPoint
    var attributes: [String: String]
    var pinBindings: [String: String]
}

enum PartKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case board
    case led
    case resistor
    case button
    case buzzer
    case sevenSegment
    case potentiometer
    case shiftRegister
    case soilSensor
    case lightSensor
    case climateSensor
    case relay
    case oledDisplay
    case microphone
    case speaker
    case rgbLamp
    case lineSensor
    case motorDriver
    case motor
    case servo
    case digitalSensorModule
    case analogSensorModule
    case i2cSensorModule
    case uartSensorModule
    case visionSensorModule
    case distanceSensorModule

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .board:
            return "Board"
        case .led:
            return "LED"
        case .resistor:
            return "Resistor"
        case .button:
            return "Pushbutton"
        case .buzzer:
            return "Buzzer"
        case .sevenSegment:
            return "7-Segment"
        case .potentiometer:
            return "Potentiometer"
        case .shiftRegister:
            return "Shift Register"
        case .soilSensor:
            return "Soil Sensor"
        case .lightSensor:
            return "Light Sensor"
        case .climateSensor:
            return "Climate Sensor"
        case .relay:
            return "Relay"
        case .oledDisplay:
            return "OLED"
        case .microphone:
            return "Microphone"
        case .speaker:
            return "Speaker"
        case .rgbLamp:
            return "RGB Lamp"
        case .lineSensor:
            return "Line Sensor"
        case .motorDriver:
            return "Motor Driver"
        case .motor:
            return "DC Motor"
        case .servo:
            return "Servo"
        case .digitalSensorModule:
            return "Digital Sensor"
        case .analogSensorModule:
            return "Analog Sensor"
        case .i2cSensorModule:
            return "I2C Module"
        case .uartSensorModule:
            return "UART Module"
        case .visionSensorModule:
            return "Vision Module"
        case .distanceSensorModule:
            return "Distance Sensor"
        }
    }

    var defaultLabel: String {
        switch self {
        case .board:
            return "Arduino Uno"
        case .led:
            return "LED"
        case .resistor:
            return "220 ohm"
        case .button:
            return "Button"
        case .buzzer:
            return "Piezo Buzzer"
        case .sevenSegment:
            return "7-Segment Display"
        case .potentiometer:
            return "10k Pot"
        case .shiftRegister:
            return "74HC595"
        case .soilSensor:
            return "Soil Probe"
        case .lightSensor:
            return "LDR Sensor"
        case .climateSensor:
            return "DHT Sensor"
        case .relay:
            return "Relay Module"
        case .oledDisplay:
            return "OLED Display"
        case .microphone:
            return "Microphone"
        case .speaker:
            return "Speaker"
        case .rgbLamp:
            return "RGB Lamp"
        case .lineSensor:
            return "Line Sensor"
        case .motorDriver:
            return "Motor Driver"
        case .motor:
            return "DC Motor"
        case .servo:
            return "Servo"
        case .digitalSensorModule:
            return "Digital Sensor Module"
        case .analogSensorModule:
            return "Analog Sensor Module"
        case .i2cSensorModule:
            return "I2C Module"
        case .uartSensorModule:
            return "UART Module"
        case .visionSensorModule:
            return "Vision Sensor"
        case .distanceSensorModule:
            return "Distance Sensor"
        }
    }

    var paletteDescription: String {
        switch self {
        case .board:
            return "Main MCU board and pin source"
        case .led:
            return "Indicator output component"
        case .resistor:
            return "Inline passive component"
        case .button:
            return "Momentary digital input"
        case .buzzer:
            return "Simple tone output"
        case .sevenSegment:
            return "Common-cathode segment display"
        case .potentiometer:
            return "Three-pin analog divider"
        case .shiftRegister:
            return "Serial-in, parallel-out logic IC"
        case .soilSensor:
            return "Digital plant moisture indicator"
        case .lightSensor:
            return "Ambient light threshold sensor"
        case .climateSensor:
            return "Temperature and humidity threshold sensor"
        case .relay:
            return "Switches pumps and lamps"
        case .oledDisplay:
            return "Compact I2C status display"
        case .microphone:
            return "Voice/activity trigger sensor"
        case .speaker:
            return "Audio output sink"
        case .rgbLamp:
            return "Three-channel lamp output"
        case .lineSensor:
            return "Reflectance sensor for rover tracking"
        case .motorDriver:
            return "Dual H-bridge driver"
        case .motor:
            return "Wheel or pump motor"
        case .servo:
            return "PWM position servo"
        case .digitalSensorModule:
            return "Generic digital sensor breakout"
        case .analogSensorModule:
            return "Generic analog sensor breakout"
        case .i2cSensorModule:
            return "Generic I2C sensor or peripheral"
        case .uartSensorModule:
            return "Generic UART-connected module"
        case .visionSensorModule:
            return "Camera or AI vision coprocessor module"
        case .distanceSensorModule:
            return "Distance and ranging sensor module"
        }
    }

    var defaultPins: [String] {
        switch self {
        case .board:
            return BoardDefinition.arduinoUno.canvasPins
        case .led:
            return ["A", "K"]
        case .resistor:
            return ["1", "2"]
        case .button:
            return ["1", "2", "3", "4"]
        case .buzzer:
            return ["+", "-"]
        case .sevenSegment:
            return ["A", "B", "C", "D", "E", "F", "G", "DP", "COM"]
        case .potentiometer:
            return ["1", "2", "3"]
        case .shiftRegister:
            return ["VCC", "GND", "DS", "SH_CP", "ST_CP", "OE", "MR", "Q0", "Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7"]
        case .soilSensor, .lightSensor, .microphone, .lineSensor:
            return ["OUT", "VCC", "GND"]
        case .climateSensor:
            return ["DATA", "VCC", "GND"]
        case .relay:
            return ["IN", "VCC", "GND", "NO", "COM"]
        case .oledDisplay:
            return ["SDA", "SCL", "VCC", "GND"]
        case .speaker:
            return ["SIG", "GND"]
        case .rgbLamp:
            return ["R", "G", "B", "GND"]
        case .motorDriver:
            return ["ENA", "IN1", "IN2", "ENB", "IN3", "IN4", "VM", "GND", "L+", "L-", "R+", "R-"]
        case .motor:
            return ["+", "-"]
        case .servo:
            return ["SIG", "VCC", "GND"]
        case .digitalSensorModule:
            return ["SIG", "VCC", "GND"]
        case .analogSensorModule:
            return ["AOUT", "DOUT", "VCC", "GND"]
        case .i2cSensorModule:
            return ["SDA", "SCL", "VCC", "GND"]
        case .uartSensorModule:
            return ["TX", "RX", "VCC", "GND"]
        case .visionSensorModule:
            return ["TX", "RX", "VCC", "GND"]
        case .distanceSensorModule:
            return ["TRIG", "ECHO", "VCC", "GND"]
        }
    }

    var defaultAttributes: [String: String] {
        switch self {
        case .board:
            return ["footprint": "uno"]
        case .led:
            return ["color": "amber"]
        case .resistor:
            return ["value": "220"]
        case .button:
            return ["style": "momentary"]
        case .buzzer:
            return ["type": "piezo"]
        case .sevenSegment:
            return ["variant": "common-cathode", "color": "red"]
        case .potentiometer:
            return ["value": "10000"]
        case .shiftRegister:
            return ["family": "74HC595"]
        case .soilSensor:
            return ["mode": "dry-alert"]
        case .lightSensor:
            return ["mode": "dark-alert"]
        case .climateSensor:
            return ["threshold": "28", "humidityThreshold": "0.70"]
        case .relay:
            return ["load": "generic"]
        case .oledDisplay:
            return ["address": "0x3C"]
        case .microphone:
            return ["mode": "trigger"]
        case .speaker:
            return ["voice": "default"]
        case .rgbLamp:
            return ["style": "lamp"]
        case .lineSensor:
            return ["side": "left"]
        case .motorDriver:
            return ["family": "tb6612"]
        case .motor:
            return ["side": "left"]
        case .servo:
            return ["channel": "grip"]
        case .digitalSensorModule:
            return ["family": "gravity-digital", "catalog": "dfrobot.gravity.digital.generic"]
        case .analogSensorModule:
            return ["family": "gravity-analog", "catalog": "dfrobot.gravity.analog.generic"]
        case .i2cSensorModule:
            return ["family": "gravity-i2c", "catalog": "dfrobot.gravity.i2c.generic", "address": "0x00"]
        case .uartSensorModule:
            return ["family": "gravity-uart", "catalog": "dfrobot.gravity.uart.generic", "baud": "9600"]
        case .visionSensorModule:
            return ["family": "gravity-vision", "catalog": "dfrobot.gravity.vision.generic", "protocol": "uart"]
        case .distanceSensorModule:
            return ["family": "gravity-distance", "catalog": "dfrobot.gravity.ultrasonic", "rangeM": "4.0"]
        }
    }
}

struct WireDefinition: Identifiable, Codable, Equatable {
    let id: String
    let from: PinReference
    let to: PinReference
    var color: String
    var midX: Double?
}

struct PinReference: Codable, Equatable, Hashable {
    let partID: String
    let pin: String

    enum CodingKeys: String, CodingKey {
        case partID = "partId"
        case pin
    }
}

struct CanvasPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
}
