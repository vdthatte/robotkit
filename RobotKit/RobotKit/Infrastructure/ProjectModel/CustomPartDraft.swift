import Foundation

struct CustomPartDraft {
    var id = ""
    var displayName = ""
    var summary = ""
    var groupTitle = "Custom Parts"
    var kind: PartKind = .digitalSensorModule
    var defaultLabel = ""
    var defaultPinsText = "SIG,VCC,GND"
    var defaultAttributesText = "family=custom\ncatalog="
    var wikiURL = ""
    var sku = ""
    var electricalInterfaces: [CustomElectricalPortDraft] = [
        .init(name: "SIG", direction: .output, signalText: "digital", description: "Primary signal"),
        .init(name: "VCC", direction: .input, signalText: "power", description: "Power input"),
        .init(name: "GND", direction: .input, signalText: "ground", description: "Ground")
    ]
    var functionalInterfaces: [CustomFunctionalInterfaceDraft] = [
        .init(name: "World State", role: .sensorWorldInput, direction: .input, description: "Consumes external state"),
        .init(name: "Reading", role: .sensorReading, direction: .output, description: "Outputs a reading")
    ]
    var simulationParameters: [CustomSimulationParameterDraft] = []
    var compatibilityConstraints: [CustomCompatibilityDraft] = [
        .init(title: "Board Support", description: "Validated for {board}-class controllers")
    ]

    init() {}

    init(entry: PartCatalogEntry) {
        id = entry.id
        displayName = entry.displayName
        summary = entry.summary
        groupTitle = entry.groupTitle
        kind = entry.kind
        defaultLabel = entry.defaultLabel
        defaultPinsText = entry.defaultPins.joined(separator: ",")
        defaultAttributesText = entry.defaultAttributes
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "\n")
        wikiURL = entry.wikiURL ?? ""
        sku = entry.sku ?? ""
        electricalInterfaces = entry.electricalInterfaces.map {
            CustomElectricalPortDraft(
                name: $0.name,
                direction: $0.direction,
                signalText: $0.signals.map(\.rawValue).joined(separator: ","),
                description: $0.description
            )
        }
        functionalInterfaces = entry.functionalInterfaces.map {
            CustomFunctionalInterfaceDraft(
                name: $0.name,
                role: $0.role,
                direction: $0.direction,
                description: $0.description
            )
        }
        simulationParameters = entry.simulationParameters.map {
            CustomSimulationParameterDraft(
                key: $0.key,
                title: $0.title,
                defaultValue: $0.defaultValue,
                description: $0.description
            )
        }
        compatibilityConstraints = entry.compatibility.map {
            CustomCompatibilityDraft(title: $0.title, description: $0.description)
        }
    }

    var resolvedIdentifier: String {
        let trimmed = id.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty == false {
            return Self.sanitizedIdentifier(trimmed)
        }

        return "custom.\(Self.sanitizedIdentifier(displayName))"
    }

    func makeEntry() -> PartCatalogEntry {
        var attributes = parsedAttributes
        attributes["catalog"] = resolvedIdentifier

        return PartCatalogEntry(
            id: resolvedIdentifier,
            vendor: .custom,
            sku: sku.nilIfBlank,
            displayName: displayName.nilIfBlank ?? "Custom Part",
            summary: summary.nilIfBlank ?? kind.paletteDescription,
            kind: kind,
            groupTitle: groupTitle.nilIfBlank ?? "Custom Parts",
            wikiURL: wikiURL.nilIfBlank,
            defaultLabel: defaultLabel.nilIfBlank ?? displayName.nilIfBlank ?? kind.defaultLabel,
            defaultPins: parsedPins.isEmpty ? kind.defaultPins : parsedPins,
            defaultAttributes: attributes,
            electricalInterfaces: electricalInterfaces.compactMap(\.resolvedDefinition),
            functionalInterfaces: functionalInterfaces.compactMap(\.resolvedDefinition),
            simulationParameters: simulationParameters.compactMap(\.resolvedDefinition),
            compatibility: compatibilityConstraints.compactMap(\.resolvedDefinition)
        )
    }

    private var parsedPins: [String] {
        defaultPinsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private var parsedAttributes: [String: String] {
        defaultAttributesText
            .split(whereSeparator: \.isNewline)
            .reduce(into: [String: String]()) { partialResult, line in
                let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { return }
                partialResult[parts[0].trimmingCharacters(in: .whitespacesAndNewlines)] = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            }
    }

    static func sanitizedIdentifier(_ rawValue: String) -> String {
        rawValue
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .components(separatedBy: CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-")).inverted)
            .joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
    }
}

struct CustomElectricalPortDraft: Identifiable {
    let id = UUID()
    var name: String
    var direction: PortDirection
    var signalText: String
    var description: String

    var resolvedDefinition: ElectricalPortDefinition? {
        let signals = signalText
            .split(separator: ",")
            .compactMap { ElectricalSignalType(rawValue: $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) }
        guard name.nilIfBlank != nil, signals.isEmpty == false else { return nil }
        return ElectricalPortDefinition(
            name: name,
            direction: direction,
            signals: signals,
            description: description.nilIfBlank ?? ""
        )
    }
}

struct CustomFunctionalInterfaceDraft: Identifiable {
    let id = UUID()
    var name: String
    var role: FunctionalRole
    var direction: FunctionalDirection
    var description: String

    var resolvedDefinition: FunctionalInterfaceDefinition? {
        guard name.nilIfBlank != nil else { return nil }
        return FunctionalInterfaceDefinition(
            name: name,
            role: role,
            direction: direction,
            description: description.nilIfBlank ?? ""
        )
    }
}

struct CustomSimulationParameterDraft: Identifiable {
    let id = UUID()
    var key: String
    var title: String
    var defaultValue: String
    var description: String

    var resolvedDefinition: SimulationParameterDefinition? {
        guard key.nilIfBlank != nil else { return nil }
        return SimulationParameterDefinition(
            key: key,
            title: title.nilIfBlank ?? key,
            defaultValue: defaultValue,
            description: description.nilIfBlank ?? ""
        )
    }
}

struct CustomCompatibilityDraft: Identifiable {
    let id = UUID()
    var title: String
    var description: String

    var resolvedDefinition: CompatibilityConstraintDefinition? {
        guard title.nilIfBlank != nil, description.nilIfBlank != nil else { return nil }
        return CompatibilityConstraintDefinition(title: title, description: description)
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
