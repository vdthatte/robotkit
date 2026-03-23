import SwiftUI

struct InspectorView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel

    private let wireColors = ["green", "red", "black", "blue", "yellow", "gray"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Project") {
                    inspectorRow("Target", projectStore.project.board.displayName)
                    inspectorRow("Clock", projectStore.project.board.clockDescription)
                    inspectorRow("JS Engine", simulator.engineName)
                    inspectorRow("Observed Pins", projectStore.project.demo.observedPins.joined(separator: ", "))
                }

                GroupBox("Runtime") {
                    inspectorRow("Demo", projectStore.project.demo.name)
                    inspectorRow("Status", simulator.status.summary)
                    inspectorRow("Frames", "\(simulator.frameCount)")
                    inspectorRow("Cycles", "\(simulator.totalCycles)")
                    inspectorRow("D13", simulator.pinValue(for: "D13") == 1 ? "High" : "Low")
                    inspectorRow("Serial Lines", "\(simulator.serialLines.count)")
                    inspectorRow("Build Notes", "\(simulator.buildDiagnostics.count)")
                    inspectorRow("Firmware", simulator.firmwareStatus)
                }

                GroupBox("Toolchain") {
                    inspectorRow("arduino-cli", simulator.toolchainStatus.arduinoCLIPath ?? "Not found")
                    inspectorRow("Compile Uno", simulator.toolchainStatus.canCompileUno ? "Available" : "Unavailable")
                    Text(simulator.toolchainStatus.statusMessage)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                GroupBox("Selection") {
                    inspectorRow("Part", projectStore.selectedPart?.id ?? "None")
                    inspectorRow("Wire", projectStore.selectedWire?.id ?? "None")
                    inspectorRow("Pins", projectStore.selectedPart?.pins.joined(separator: ", ") ?? "None")
                }

                if let selectedPart = projectStore.selectedPart {
                    GroupBox("Part Editor") {
                        TextField(
                            "Label",
                            text: Binding(
                                get: { projectStore.selectedPart?.label ?? selectedPart.label },
                                set: { projectStore.updateSelectedPartLabel($0) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)

                        ForEach(selectedPart.attributes.keys.sorted(), id: \.self) { key in
                            HStack {
                                Text(key)
                                    .foregroundStyle(.secondary)
                                TextField(
                                    key,
                                    text: Binding(
                                        get: { projectStore.selectedPart?.attributes[key] ?? "" },
                                        set: { projectStore.updateSelectedPartAttribute(key: key, value: $0) }
                                    )
                                )
                                .textFieldStyle(.roundedBorder)
                            }
                        }

                        if selectedPart.id == "board" {
                            Text("The board is fixed and cannot be deleted.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let catalogEntry = projectStore.selectedCatalogEntry {
                        GroupBox("Part Model") {
                            inspectorRow("Catalog", catalogEntry.displayName)
                            inspectorRow("Vendor", catalogEntry.vendor.displayName)
                            inspectorRow("Group", catalogEntry.groupTitle)
                            if let sku = catalogEntry.sku {
                                inspectorRow("SKU", sku)
                            }

                            if let wikiURL = catalogEntry.wikiURL {
                                Text(wikiURL)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }

                            Divider()

                            Text("Electrical Interfaces")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(catalogEntry.electricalInterfaces.enumerated()), id: \.offset) { _, interface in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(interface.name) • \(interface.direction.rawValue.capitalized)")
                                    Text(interface.signals.map { $0.rawValue.uppercased() }.joined(separator: ", "))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Text(interface.description)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Divider()

                            Text("Functional Interfaces")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ForEach(Array(catalogEntry.functionalInterfaces.enumerated()), id: \.offset) { _, interface in
                                Text("\(interface.direction.rawValue.capitalized) • \(interface.name) • \(interface.role.rawValue)")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            if catalogEntry.compatibility.isEmpty == false {
                                Divider()
                                Text("Compatibility")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(PartCatalog.compatibilityMessages(for: catalogEntry, board: projectStore.project.board).enumerated()), id: \.offset) { _, message in
                                    Text(message)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }

                if let selectedWire = projectStore.selectedWire {
                    GroupBox("Wire Editor") {
                        inspectorRow("From", "\(selectedWire.from.partID).\(selectedWire.from.pin)")
                        inspectorRow("To", "\(selectedWire.to.partID).\(selectedWire.to.pin)")

                        Picker("Color", selection: Binding(
                            get: { projectStore.selectedWire?.color ?? selectedWire.color },
                            set: { projectStore.updateSelectedWireColor($0) }
                        )) {
                            ForEach(wireColors, id: \.self) { color in
                                Text(color.capitalized).tag(color)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text("Drag the square handle on the selected wire to reroute its vertical segment.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                GroupBox("Editor") {
                    inspectorRow("Active File", projectStore.selectedFilePath)
                    inspectorRow(
                        "Placement",
                        projectStore.pendingPlacementKind?.displayName ?? "Disabled"
                    )
                inspectorRow("Zoom", String(format: "%.0f%%", projectStore.canvasZoom * 100))
                inspectorRow("Pan", "\(Int(projectStore.canvasOffset.x)), \(Int(projectStore.canvasOffset.y))")
                    inspectorRow("Placement Catalog", projectStore.pendingPlacementEntry?.displayName ?? "None")
                }

                GroupBox("Persistence") {
                    inspectorRow("Workspace", projectStore.lastSavedURL?.lastPathComponent ?? "Not saved yet")
                    if let lastSaveError = projectStore.lastSaveError {
                        Text(lastSaveError)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if let path = projectStore.lastSavedURL?.path {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
