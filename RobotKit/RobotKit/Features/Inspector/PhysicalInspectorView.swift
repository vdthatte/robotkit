import SwiftUI

struct PhysicalInspectorView: View {
    @ObservedObject var projectStore: ProjectStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Physical Layer") {
                    let enclosure = projectStore.project.physical.enclosure
                    inspectorRow("Placed Parts", "\(projectStore.project.physical.placements.count)")
                    inspectorRow("Envelope", "\(Int(enclosure.width)) × \(Int(enclosure.height)) × \(Int(enclosure.depth)) mm")
                    inspectorRow("Wall", String(format: "%.1f mm", enclosure.wallThickness))
                    inspectorRow("Lid", enclosure.lidStyle.rawValue.capitalized)
                    inspectorRow("Projection", projectStore.selectedPhysicalCanvasMode.title)
                    inspectorRow("CAD Output", projectStore.project.generatedTextArtifacts["enclosure.scad"] == nil ? "Not generated" : "enclosure.scad")
                }

                GroupBox("Actions") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Auto-layout") {
                            projectStore.autoLayoutPhysical()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Compact This") {
                            projectStore.compactPhysicalLayout()
                        }
                        .buttonStyle(.bordered)

                        Button("Expose Ports") {
                            projectStore.exposePhysicalPorts()
                        }
                        .buttonStyle(.bordered)

                        Button("Generate Enclosure") {
                            projectStore.generateEnclosure()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Selection") {
                    inspectorRow("Part", projectStore.selectedPart?.label ?? "None")
                    inspectorRow("Mount", projectStore.selectedPhysicalPlacement?.mount.rawValue.capitalized ?? "None")
                    inspectorRow("Face", projectStore.selectedPhysicalPlacement?.face.rawValue.capitalized ?? "None")
                }

                if let selectedPart = projectStore.selectedPart,
                   let placement = projectStore.selectedPhysicalPlacement {
                    GroupBox("Physical Inspector") {
                        inspectorRow("Kind", selectedPart.kind.displayName)
                        inspectorRow(
                            "Footprint",
                            "\(Int(placement.footprint.width)) × \(Int(placement.footprint.height)) × \(Int(placement.footprint.depth)) mm"
                        )
                        inspectorRow(
                            "Dimensions Source",
                            PhysicalFootprint.usesExplicitDimensions(for: selectedPart) ? "Part metadata" : "Estimated by part type"
                        )

                        Picker("Face", selection: Binding(
                            get: { projectStore.selectedPhysicalPlacement?.face ?? placement.face },
                            set: { projectStore.updateSelectedPhysicalFace($0) }
                        )) {
                            ForEach(PhysicalFace.allCases) { face in
                                Text(face.rawValue.capitalized).tag(face)
                            }
                        }

                        Picker("Mount", selection: Binding(
                            get: { projectStore.selectedPhysicalPlacement?.mount ?? placement.mount },
                            set: { projectStore.updateSelectedPhysicalMount($0) }
                        )) {
                            ForEach(PhysicalMountKind.allCases) { mount in
                                Text(mount.rawValue.capitalized).tag(mount)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Rotation")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(projectStore.selectedPhysicalPlacement?.rotationDegrees ?? placement.rotationDegrees)) deg")
                                    .font(.caption.monospaced())
                            }
                            Slider(
                                value: Binding(
                                    get: { projectStore.selectedPhysicalPlacement?.rotationDegrees ?? placement.rotationDegrees },
                                    set: { projectStore.updateSelectedPhysicalRotation($0.rounded()) }
                                ),
                                in: 0...270,
                                step: 90
                            )
                        }

                        if (projectStore.selectedPhysicalPlacement?.mount ?? placement.mount) == .standoff {
                            Stepper(
                                "Standoff Height: \(Int(projectStore.selectedPhysicalPlacement?.standoffHeight ?? placement.standoffHeight)) mm",
                                value: Binding(
                                    get: { Int(projectStore.selectedPhysicalPlacement?.standoffHeight ?? placement.standoffHeight) },
                                    set: { projectStore.updateSelectedPhysicalStandoffHeight(Double($0)) }
                                ),
                                in: 0...24
                            )
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private func inspectorRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
