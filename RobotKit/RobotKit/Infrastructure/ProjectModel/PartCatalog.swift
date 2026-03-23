import Foundation

enum PartVendor: String, Codable, CaseIterable {
    case robotKit
    case dfrobot
    case custom

    var displayName: String {
        switch self {
        case .robotKit:
            return "RobotKit"
        case .dfrobot:
            return "DFRobot"
        case .custom:
            return "Custom"
        }
    }
}

enum ElectricalSignalType: String, Codable, CaseIterable {
    case power
    case ground
    case digital
    case analog
    case pwm
    case i2c
    case uart
    case motor
    case switchedPower

    var displayName: String {
        rawValue.uppercased()
    }
}

enum PortDirection: String, Codable, CaseIterable {
    case input
    case output
    case bidirectional
}

enum FunctionalRole: String, Codable, CaseIterable {
    case firmware
    case sensorWorldInput
    case sensorReading
    case controlSignal
    case actuatorPower
    case motion
    case switchedPower
    case displayState
    case audio
    case reasoningHint
}

enum FunctionalDirection: String, Codable, CaseIterable {
    case input
    case output
}

struct ElectricalPortDefinition: Codable, Equatable, Identifiable {
    var id: String { "\(name)-\(direction.rawValue)" }
    let name: String
    let direction: PortDirection
    let signals: [ElectricalSignalType]
    let description: String
}

struct FunctionalInterfaceDefinition: Codable, Equatable, Identifiable {
    var id: String { "\(name)-\(role.rawValue)-\(direction.rawValue)" }
    let name: String
    let role: FunctionalRole
    let direction: FunctionalDirection
    let description: String
}

struct SimulationParameterDefinition: Codable, Equatable, Identifiable {
    var id: String { key }
    let key: String
    let title: String
    let defaultValue: String
    let description: String
}

struct CompatibilityConstraintDefinition: Codable, Equatable, Identifiable {
    var id: String { "\(title)-\(description)" }
    let title: String
    let description: String
}

struct PartCatalogEntry: Identifiable, Codable, Equatable {
    let id: String
    let vendor: PartVendor
    let sku: String?
    let displayName: String
    let summary: String
    let kind: PartKind
    let groupTitle: String
    let wikiURL: String?
    let defaultLabel: String
    let defaultPins: [String]
    let defaultAttributes: [String: String]
    let electricalInterfaces: [ElectricalPortDefinition]
    let functionalInterfaces: [FunctionalInterfaceDefinition]
    let simulationParameters: [SimulationParameterDefinition]
    let compatibility: [CompatibilityConstraintDefinition]

    var isCustom: Bool {
        vendor == .custom
    }

    func instantiate(id partID: String, at position: CanvasPoint) -> PartDefinition {
        var attributes = defaultAttributes
        attributes["catalog"] = id

        return PartDefinition(
            id: partID,
            kind: kind,
            label: defaultLabel,
            pins: defaultPins,
            position: position,
            attributes: attributes,
            pinBindings: [:]
        )
    }
}

struct PartCatalogDocument: Codable {
    let entries: [PartCatalogEntry]
}

enum PartCatalog {
    private static var cachedEntries: [PartCatalogEntry]?

    static var entries: [PartCatalogEntry] {
        if let cachedEntries {
            return cachedEntries
        }

        let loaded = PartLibraryService.loadPartCatalogEntries()
        cachedEntries = loaded
        return loaded
    }

    static func reload() {
        cachedEntries = PartLibraryService.loadPartCatalogEntries()
    }

    static func entry(id: String?) -> PartCatalogEntry? {
        guard let id else { return nil }
        return entries.first(where: { $0.id == id })
    }

    static func entry(for part: PartDefinition) -> PartCatalogEntry? {
        if let explicit = entry(id: part.attributes["catalog"]) {
            return explicit
        }

        return defaultEntry(for: part.kind)
    }

    static func defaultEntry(for kind: PartKind) -> PartCatalogEntry? {
        entries.first(where: { $0.kind == kind && $0.vendor == .robotKit })
            ?? entries.first(where: { $0.kind == kind })
    }

    static func availableEntries(for board: BoardDefinition) -> [PartCatalogEntry] {
        entries.filter { entry in
            entry.kind != .board || board.id == "arduino-uno"
        }
    }

    static func compatibilityMessages(for entry: PartCatalogEntry, board: BoardDefinition) -> [String] {
        entry.compatibility.map {
            "\($0.title): \($0.description.replacingOccurrences(of: "{board}", with: board.displayName))"
        }
    }
}
