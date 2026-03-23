import Combine
import Foundation

@MainActor
final class ProjectStore: ObservableObject {
    @Published var project = ProjectBundleLoader.loadStarterProject()
    @Published var selectedPartID: String? = "board"
    @Published var selectedWireID: String?
    @Published var selectedFilePath = "sketch.ino"
    @Published var isCodeEditorVisible = true
    @Published var isConsoleVisible = true
    @Published var sourceFiles: [String: String] = [:]
    @Published var partSearchQuery = ""
    @Published var isPartPalettePresented = false
    @Published var pendingPlacementCatalogID: String?
    @Published var pendingPlacementKind: PartKind?
    @Published var placementPreviewPoint: CanvasPoint?
    @Published var activeButtonIDs: Set<String> = []
    @Published var canvasZoom = 1.0
    @Published var canvasOffset = CanvasPoint(x: 0, y: 0)
    @Published private(set) var workspaceURL: URL?
    @Published private(set) var lastSavedURL: URL?
    @Published private(set) var lastSaveError: String?

    var selectedPart: PartDefinition? {
        guard let selectedPartID else { return nil }
        return project.parts.first(where: { $0.id == selectedPartID })
    }

    var selectedWire: WireDefinition? {
        guard let selectedWireID else { return nil }
        return project.diagram.wires.first(where: { $0.id == selectedWireID })
    }

    var selectedCatalogEntry: PartCatalogEntry? {
        selectedPart.flatMap(PartCatalog.entry(for:))
    }

    var pendingPlacementEntry: PartCatalogEntry? {
        PartCatalog.entry(id: pendingPlacementCatalogID)
            ?? pendingPlacementKind.flatMap { PartCatalog.defaultEntry(for: $0) }
    }

    init() {
        sourceFiles = Self.loadInitialSourceFiles(for: project, workspaceURL: nil)
        persist()
    }

    func movePart(id: String, to position: CanvasPoint) {
        guard let index = project.diagram.parts.firstIndex(where: { $0.id == id }) else { return }
        project.diagram.parts[index].position = position
        persist()
    }

    func newProject(named name: String = "Untitled Project") {
        project = .untitled(named: name)
        workspaceURL = nil
        lastSavedURL = nil
        selectedPartID = "board"
        selectedWireID = nil
        selectedFilePath = project.demo.source
        isCodeEditorVisible = true
        isConsoleVisible = true
        sourceFiles = Self.loadInitialSourceFiles(for: project, workspaceURL: nil)
        pendingPlacementKind = nil
        pendingPlacementCatalogID = nil
        placementPreviewPoint = nil
        activeButtonIDs = []
        partSearchQuery = ""
        canvasZoom = 1.0
        canvasOffset = CanvasPoint(x: 0, y: 0)
        persist()
    }

    func loadTemplate(_ template: ProjectTemplateKind) {
        let generated = ProjectTemplateFactory.makeProject(for: template)
        project = generated.project
        workspaceURL = nil
        lastSavedURL = nil
        selectedPartID = "board"
        selectedWireID = nil
        selectedFilePath = project.demo.source
        isCodeEditorVisible = true
        isConsoleVisible = true
        sourceFiles = generated.sourceFiles
        pendingPlacementKind = nil
        pendingPlacementCatalogID = nil
        placementPreviewPoint = nil
        activeButtonIDs = []
        partSearchQuery = ""
        canvasZoom = 1.0
        canvasOffset = CanvasPoint(x: 0, y: 0)
        persist()
    }

    func openProject(at url: URL) throws {
        let loadedProject = try ProjectBundleLoader.loadProject(from: url)
        project = loadedProject
        workspaceURL = url
        lastSavedURL = url
        selectedPartID = project.parts.first?.id
        selectedWireID = nil
        selectedFilePath = project.demo.source
        isCodeEditorVisible = true
        isConsoleVisible = true
        sourceFiles = Self.loadInitialSourceFiles(for: project, workspaceURL: url)
        pendingPlacementKind = nil
        pendingPlacementCatalogID = nil
        placementPreviewPoint = nil
        activeButtonIDs = []
        canvasZoom = 1.0
        canvasOffset = CanvasPoint(x: 0, y: 0)
        lastSaveError = nil
    }

    func setCanvasViewport(zoom: Double, offset: CanvasPoint) {
        canvasZoom = min(max(zoom, 0.5), 2.5)
        canvasOffset = offset
    }

    func beginPlacement(of kind: PartKind) {
        pendingPlacementCatalogID = PartCatalog.defaultEntry(for: kind)?.id
        pendingPlacementKind = kind
        placementPreviewPoint = nil
        isPartPalettePresented = false
        selectedWireID = nil
    }

    func beginPlacement(catalogEntryID: String) {
        guard let entry = PartCatalog.entry(id: catalogEntryID) else { return }
        pendingPlacementCatalogID = entry.id
        pendingPlacementKind = entry.kind
        placementPreviewPoint = nil
        isPartPalettePresented = false
        selectedWireID = nil
    }

    func cancelPlacement() {
        pendingPlacementCatalogID = nil
        pendingPlacementKind = nil
        placementPreviewPoint = nil
    }

    func addPart(kind: PartKind, at position: CanvasPoint? = nil) {
        if let entry = PartCatalog.defaultEntry(for: kind) {
            addPart(catalogEntry: entry, at: position)
            return
        }

        guard kind != .board || project.parts.contains(where: { $0.kind == .board }) == false else {
            selectedPartID = project.parts.first(where: { $0.kind == .board })?.id
            return
        }

        let part = PartDefinition(
            id: nextPartID(for: kind),
            kind: kind,
            label: kind.defaultLabel,
            pins: kind.defaultPins,
            position: position ?? nextPlacementPosition(),
            attributes: kind.defaultAttributes,
            pinBindings: [:]
        )

        project.diagram.parts.append(part)
        selectedPartID = part.id
        selectedWireID = nil
        pendingPlacementKind = nil
        placementPreviewPoint = nil
        persist()
    }

    func addPart(catalogEntry: PartCatalogEntry, at position: CanvasPoint? = nil) {
        let kind = catalogEntry.kind
        guard kind != .board || project.parts.contains(where: { $0.kind == .board }) == false else {
            selectedPartID = project.parts.first(where: { $0.kind == .board })?.id
            return
        }

        let part = catalogEntry.instantiate(
            id: nextPartID(for: kind),
            at: position ?? nextPlacementPosition()
        )

        project.diagram.parts.append(part)
        selectedPartID = part.id
        selectedWireID = nil
        pendingPlacementCatalogID = nil
        pendingPlacementKind = nil
        placementPreviewPoint = nil
        persist()
    }

    func placePendingPart(at position: CanvasPoint) {
        if let pendingPlacementEntry {
            addPart(catalogEntry: pendingPlacementEntry, at: position)
            return
        }
        guard let pendingPlacementKind else { return }
        addPart(kind: pendingPlacementKind, at: position)
    }

    func updatePlacementPreview(_ position: CanvasPoint?) {
        placementPreviewPoint = position
    }

    func selectPart(id: String?) {
        selectedPartID = id
        if id != nil {
            selectedWireID = nil
        }
    }

    func selectWire(id: String?) {
        selectedWireID = id
        if id != nil {
            selectedPartID = nil
        }
    }

    func selectFile(path: String) {
        selectedFilePath = path
        isCodeEditorVisible = true
    }

    func addSourceFile() {
        let existingNames = Set(project.files.map(\.path))
        var index = 1
        var candidate = "helpers.h"
        while existingNames.contains(candidate) {
            index += 1
            candidate = "helpers\(index).h"
        }

        project.files.append(ProjectFile(name: candidate, path: candidate, kind: .source))
        sourceFiles[candidate] = "// \(candidate)\n"
        selectedFilePath = candidate
        isCodeEditorVisible = true
        persist()
    }

    func handleCanvasBackgroundActivation(at point: CanvasPoint?) {
        if let point, pendingPlacementKind != nil {
            placePendingPart(at: point)
            return
        }

        selectedPartID = nil
        selectedWireID = nil
    }

    func handleCanvasPartActivation(_ partID: String?) {
        guard let partID else {
            selectedPartID = nil
            selectedWireID = nil
            return
        }

        selectedPartID = partID
        selectedWireID = nil
    }

    func handleCanvasWireActivation(_ wireID: String?) {
        selectedWireID = wireID
        if wireID != nil {
            selectedPartID = nil
        }
    }

    func createWire(from: PinReference, to: PinReference) {
        selectedPartID = to.partID
        selectedWireID = nil
        addWire(from: from, to: to)
    }

    func updateSourceCode(_ sourceCode: String) {
        guard selectedFilePath.isEmpty == false else { return }
        sourceFiles[selectedFilePath] = sourceCode
        persist()
    }

    func updateSelectedPartLabel(_ label: String) {
        guard let selectedPartID, let index = project.diagram.parts.firstIndex(where: { $0.id == selectedPartID }) else { return }
        project.diagram.parts[index].label = label
        persist()
    }

    func updateSelectedPartAttribute(key: String, value: String) {
        guard let selectedPartID, let index = project.diagram.parts.firstIndex(where: { $0.id == selectedPartID }) else { return }
        project.diagram.parts[index].attributes[key] = value
        persist()
    }

    func updateSelectedWireColor(_ color: String) {
        guard let selectedWireID, let index = project.diagram.wires.firstIndex(where: { $0.id == selectedWireID }) else { return }
        project.diagram.wires[index].color = color
        persist()
    }

    func updateWireMidX(_ wireID: String, to midX: Double) {
        guard let index = project.diagram.wires.firstIndex(where: { $0.id == wireID }) else { return }
        project.diagram.wires[index].midX = midX
        persist()
    }

    func deleteSelection() {
        if let selectedWireID, let index = project.diagram.wires.firstIndex(where: { $0.id == selectedWireID }) {
            project.diagram.wires.remove(at: index)
            self.selectedWireID = nil
            persist()
            return
        }

        guard let selectedPartID, selectedPartID != "board", let index = project.diagram.parts.firstIndex(where: { $0.id == selectedPartID }) else {
            return
        }

        project.diagram.parts.remove(at: index)
        project.diagram.wires.removeAll { $0.from.partID == selectedPartID || $0.to.partID == selectedPartID }
        self.selectedPartID = nil
        persist()
    }

    func duplicateSelection() {
        guard let selectedPartID,
              selectedPartID != "board",
              let part = project.diagram.parts.first(where: { $0.id == selectedPartID }) else {
            return
        }

        let duplicated = PartDefinition(
            id: nextPartID(for: part.kind),
            kind: part.kind,
            label: "\(part.label) Copy",
            pins: part.pins,
            position: CanvasPoint(x: part.position.x + 48, y: part.position.y + 48),
            attributes: part.attributes,
            pinBindings: part.pinBindings
        )
        project.diagram.parts.append(duplicated)
        self.selectedPartID = duplicated.id
        self.selectedWireID = nil
        persist()
    }

    func fileContents(for file: ProjectFile) -> String {
        switch file.kind {
        case .source:
            return sourceFiles[file.path] ?? ""
        case .manifest:
            return formattedJSON(project)
        case .diagram:
            return formattedJSON(project.diagram)
        case .firmware:
            return "Firmware artifact: \(file.name)\n\nBuild and Run to regenerate this file from the current sketch."
        }
    }

    func save() {
        persist()
    }

    func saveAs(to destinationURL: URL) {
        persist(to: destinationURL)
    }

    func recordError(_ message: String) {
        lastSaveError = message
    }

    func setButtonPressed(_ partID: String, isPressed: Bool) {
        if isPressed {
            activeButtonIDs.insert(partID)
        } else {
            activeButtonIDs.remove(partID)
        }
    }

    func persist(to destinationURL: URL? = nil) {
        do {
            let savedURL = try ProjectPersistenceService.save(
                project,
                destinationURL: destinationURL ?? workspaceURL,
                sourceWorkspaceURL: workspaceURL ?? lastSavedURL,
                artifactOverrides: sourceFiles
            )
            workspaceURL = savedURL
            lastSavedURL = savedURL
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
        }
    }

    private func addWire(from: PinReference, to: PinReference) {
        guard from != to else { return }
        guard wireExists(from: from, to: to) == false else { return }

        let color = wireColor(from: from.pin, to: to.pin)
        project.diagram.wires.append(
            WireDefinition(
                id: "wire-\(from.partID)-\(from.pin.lowercased())-\(to.partID)-\(to.pin.lowercased())-\(project.diagram.wires.count + 1)",
                from: from,
                to: to,
                color: color,
                midX: nil
            )
        )
        persist()
    }

    private func nextPartID(for kind: PartKind) -> String {
        let prefix: String
        switch kind {
        case .board:
            prefix = "board"
        case .led:
            prefix = "led"
        case .resistor:
            prefix = "r"
        case .button:
            prefix = "btn"
        case .buzzer:
            prefix = "buzz"
        case .sevenSegment:
            prefix = "seg"
        case .potentiometer:
            prefix = "pot"
        case .shiftRegister:
            prefix = "sr"
        case .soilSensor:
            prefix = "soil"
        case .lightSensor:
            prefix = "light"
        case .climateSensor:
            prefix = "climate"
        case .relay:
            prefix = "relay"
        case .oledDisplay:
            prefix = "oled"
        case .microphone:
            prefix = "mic"
        case .speaker:
            prefix = "spk"
        case .rgbLamp:
            prefix = "lamp"
        case .lineSensor:
            prefix = "line"
        case .motorDriver:
            prefix = "driver"
        case .motor:
            prefix = "motor"
        case .servo:
            prefix = "servo"
        case .digitalSensorModule:
            prefix = "ds"
        case .analogSensorModule:
            prefix = "as"
        case .i2cSensorModule:
            prefix = "i2c"
        case .uartSensorModule:
            prefix = "uart"
        case .visionSensorModule:
            prefix = "vision"
        case .distanceSensorModule:
            prefix = "dist"
        }

        let existing = Set(project.parts.map(\.id))
        var index = 1
        while existing.contains("\(prefix)\(index)") {
            index += 1
        }
        return "\(prefix)\(index)"
    }

    private func nextPlacementPosition() -> CanvasPoint {
        let count = project.parts.count
        return CanvasPoint(
            x: 420 + Double((count % 3) * 180),
            y: 220 + Double((count / 3) * 150)
        )
    }

    private func wireColor(from fromPin: String, to toPin: String) -> String {
        let pins = [fromPin, toPin]
        if pins.contains("GND") {
            return "black"
        }
        if pins.contains("5V") {
            return "red"
        }
        return "green"
    }

    private func formattedJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try? encoder.encode(value)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
    }

    private func wireExists(from: PinReference, to: PinReference) -> Bool {
        project.diagram.wires.contains { wire in
            (wire.from == from && wire.to == to) || (wire.from == to && wire.to == from)
        }
    }

    private static func loadInitialSourceFiles(for project: RobotProject, workspaceURL: URL?) -> [String: String] {
        var contents: [String: String] = [:]
        for file in project.files where file.kind == .source {
            contents[file.path] = (try? ProjectArtifactLoader.loadTextFile(named: file.path, workspaceURL: workspaceURL)) ?? defaultSource(named: file.path)
        }
        return contents
    }

    private static func defaultSource(named path: String) -> String {
        if path == "sketch.ino" {
            return """
            void setup() {
              pinMode(13, OUTPUT);
              Serial.begin(115200);
            }

            void loop() {
              digitalWrite(13, HIGH);
              Serial.println("RobotKit D13 HIGH");
              delay(500);
              digitalWrite(13, LOW);
              Serial.println("RobotKit D13 LOW");
              delay(500);
            }
            """
        }

        return "// \(path)\n"
    }
}
