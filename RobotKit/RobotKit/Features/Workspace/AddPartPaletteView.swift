import SwiftUI

struct AddPartPaletteView: View {
    enum CatalogScope: String, CaseIterable, Identifiable {
        case all
        case outputs
        case sensors
        case motion

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "Parts"
            case .outputs:
                return "Outputs"
            case .sensors:
                return "Sensors"
            case .motion:
                return "Motion"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var appModel: AppModel

    @State private var selectedPartID: String?
    @State private var isCustomPartEditorPresented = false
    @State private var selectedScope: CatalogScope = .all

    private var availableParts: [PartCatalogEntry] {
        PartCatalog.availableEntries(for: projectStore.project.board).filter { entry in
            let matchesBoardConstraint = entry.kind != .board || projectStore.project.parts.contains(where: { $0.kind == .board }) == false
            let matchesScope = selectedScope.matches(entry.kind)
            let query = projectStore.partSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            let matchesQuery = query.isEmpty
                || entry.displayName.localizedCaseInsensitiveContains(query)
                || entry.summary.localizedCaseInsensitiveContains(query)
                || entry.groupTitle.localizedCaseInsensitiveContains(query)
                || entry.vendor.displayName.localizedCaseInsensitiveContains(query)
                || (entry.sku?.localizedCaseInsensitiveContains(query) ?? false)
            return matchesBoardConstraint && matchesScope && matchesQuery
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                content
                Divider()
                footer
            }
            .frame(width: 860, height: 560)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .onAppear {
            if selectedPartID == nil {
                selectedPartID = availableParts.first?.id
            }
        }
        .onChange(of: availableParts) { _, updatedParts in
            if let selectedPartID, updatedParts.contains(where: { $0.id == selectedPartID }) == false {
                self.selectedPartID = updatedParts.first?.id
            }
        }
        .onDisappear {
            projectStore.partSearchQuery = ""
        }
        .onExitCommand {
            dismiss()
        }
        .sheet(isPresented: $isCustomPartEditorPresented, onDismiss: {
            PartCatalog.reload()
        }) {
            CustomPartEditorView(appModel: appModel)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose a component to add:")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                ForEach(CatalogScope.allCases) { scope in
                    chooserScopePill(scope)
                }
                Spacer()
                Button("New Custom Part") {
                    isCustomPartEditorPresented = true
                }
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $projectStore.partSearchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black.opacity(0.18))
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: 220)
            }
        }
        .padding(22)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                chooserSectionTitle(sectionTitle)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 16)], spacing: 16) {
                    ForEach(availableParts) { entry in
                        partCard(entry)
                    }
                }

                if let selectedPart {
                    chooserSectionTitle("Description")
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(selectedPart.summary)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedPart.vendor.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        if let sku = selectedPart.sku {
                            Text("SKU: \(sku)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.tertiary)
                        }
                        if selectedPart.isCustom {
                            Text("Custom part stored in the RobotKit part library")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Pins: \(selectedPart.defaultPins.joined(separator: ", "))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        Text("Electrical: \(selectedPart.electricalInterfaces.map { "\($0.name) [\($0.signals.map(\.rawValue).joined(separator: "/"))]" }.joined(separator: " • "))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("Functional: \(selectedPart.functionalInterfaces.map(\.name).joined(separator: " • "))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                }
            }
            .padding(22)
        }
        .background(Color.white.opacity(0.015))
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Add Part") {
                guard let selectedPart else { return }
                projectStore.beginPlacement(catalogEntryID: selectedPart.id)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedPart == nil)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private func partCard(_ entry: PartCatalogEntry) -> some View {
        let isSelected = selectedPartID == entry.id

        return Button {
            selectedPartID = entry.id
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.04))
                        .frame(width: 74, height: 74)
                    Image(systemName: entry.kind.symbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                }

                VStack(spacing: 4) {
                    Text(entry.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)

                    Text(entry.groupTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if entry.isCustom {
                        Text("Custom")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.orange.opacity(0.18)))
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            selectedPartID = entry.id
            projectStore.beginPlacement(catalogEntryID: entry.id)
            dismiss()
        }
    }

    private func chooserScopePill(_ scope: CatalogScope) -> some View {
        let isActive = selectedScope == scope

        return Button {
            selectedScope = scope
        } label: {
            Text(scope.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? Color.accentColor : Color.white.opacity(0.05))
                )
                .foregroundStyle(isActive ? Color.white : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    private func chooserSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedPart: PartCatalogEntry? {
        availableParts.first(where: { $0.id == selectedPartID })
    }

    private var sectionTitle: String {
        switch selectedScope {
        case .all:
            return "Component Library"
        case .outputs:
            return "Output Components"
        case .sensors:
            return "Sensor Components"
        case .motion:
            return "Motion Components"
        }
    }
}

private extension PartKind {
    var symbolName: String {
        switch self {
        case .board:
            return "cpu"
        case .led:
            return "lightbulb"
        case .resistor:
            return "line.diagonal"
        case .button:
            return "button.programmable"
        case .buzzer:
            return "speaker.wave.2"
        case .soilSensor:
            return "drop"
        case .lightSensor:
            return "sun.max"
        case .climateSensor:
            return "thermometer.medium"
        case .relay:
            return "switch.2"
        case .oledDisplay:
            return "rectangle.inset.filled"
        case .microphone:
            return "mic"
        case .speaker:
            return "speaker"
        case .rgbLamp:
            return "lamp.table"
        case .lineSensor:
            return "dot.scope"
        case .motorDriver:
            return "gearshape.2"
        case .motor:
            return "fanblades"
        case .servo:
            return "dial.high"
        case .sevenSegment:
            return "rectangle.3.group"
        case .potentiometer:
            return "dial.medium"
        case .shiftRegister:
            return "memorychip"
        case .digitalSensorModule:
            return "sensor.tag.radiowaves.forward"
        case .analogSensorModule:
            return "waveform.path.ecg"
        case .i2cSensorModule:
            return "point.3.connected.trianglepath.dotted"
        case .uartSensorModule:
            return "arrow.left.arrow.right.square"
        case .visionSensorModule:
            return "camera.viewfinder"
        case .distanceSensorModule:
            return "ruler"
        }
    }

    var categoryTitle: String {
        switch self {
        case .board:
            return "Boards"
        case .led, .buzzer, .speaker, .rgbLamp, .oledDisplay, .sevenSegment:
            return "Outputs"
        case .soilSensor, .lightSensor, .climateSensor, .microphone, .lineSensor, .potentiometer:
            return "Sensors"
        case .button, .relay:
            return "Controls"
        case .motorDriver, .motor, .servo:
            return "Motion"
        case .resistor, .shiftRegister:
            return "Components"
        case .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            return "DFRobot"
        }
    }
}

private extension AddPartPaletteView.CatalogScope {
    func matches(_ kind: PartKind) -> Bool {
        switch self {
        case .all:
            return true
        case .outputs:
            return kind.categoryTitle == "Outputs"
        case .sensors:
            return kind.categoryTitle == "Sensors" || kind.categoryTitle == "DFRobot"
        case .motion:
            return kind.categoryTitle == "Motion"
        }
    }
}
