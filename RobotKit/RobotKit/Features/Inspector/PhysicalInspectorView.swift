import SwiftUI

struct PhysicalInspectorView: View {
    @ObservedObject var projectStore: ProjectStore
    private let breadboardPitch = 2.54
    private let breadboardWidth = 320.0
    private let breadboardHeight = 180.0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("Physical Layer") {
                    let enclosure = projectStore.project.physical.enclosure
                    inspectorRow("Placed Parts", "\(projectStore.project.physical.placements.count)")
                    inspectorRow("Envelope", "\(Int(enclosure.width)) × \(Int(enclosure.height)) × \(Int(enclosure.depth)) mm")
                    inspectorRow("Wall", String(format: "%.1f mm", enclosure.wallThickness))
                    inspectorRow("Lid", enclosure.lidStyle.rawValue.capitalized)
                    inspectorRow("Renderer", "RealityKit")
                    inspectorRow("Camera", "Orbit")
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
                        inspectorRow("Grid", String(format: "%.2f mm breadboard pitch", breadboardPitch))

                        let center = projectStore.project.physical.enclosure.center
                        let currentPosition = projectStore.selectedPhysicalPlacement?.position ?? placement.position
                        let xCandidates = breadboardColumnCandidates(centerX: center.x, footprintWidth: placement.footprint.width)
                        let yCandidates = breadboardRowCandidates(
                            centerY: center.y,
                            partKind: selectedPart.kind,
                            footprintHeight: placement.footprint.height
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Position")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(String(format: "X %.2f • Y %.2f mm", currentPosition.x, currentPosition.y))
                                    .font(.caption.monospaced())
                            }

                            HStack(spacing: 8) {
                                Button {
                                    nudgeSelectedPart(
                                        axis: .x,
                                        direction: -1,
                                        current: currentPosition,
                                        xCandidates: xCandidates,
                                        yCandidates: yCandidates,
                                        partID: selectedPart.id
                                    )
                                } label: {
                                    Label("Left", systemImage: "arrow.left")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    nudgeSelectedPart(
                                        axis: .x,
                                        direction: 1,
                                        current: currentPosition,
                                        xCandidates: xCandidates,
                                        yCandidates: yCandidates,
                                        partID: selectedPart.id
                                    )
                                } label: {
                                    Label("Right", systemImage: "arrow.right")
                                }
                                .buttonStyle(.bordered)
                            }

                            HStack(spacing: 8) {
                                Button {
                                    nudgeSelectedPart(
                                        axis: .y,
                                        direction: -1,
                                        current: currentPosition,
                                        xCandidates: xCandidates,
                                        yCandidates: yCandidates,
                                        partID: selectedPart.id
                                    )
                                } label: {
                                    Label("Up", systemImage: "arrow.up")
                                }
                                .buttonStyle(.bordered)
                                .disabled(yCandidates.count <= 1)

                                Button {
                                    nudgeSelectedPart(
                                        axis: .y,
                                        direction: 1,
                                        current: currentPosition,
                                        xCandidates: xCandidates,
                                        yCandidates: yCandidates,
                                        partID: selectedPart.id
                                    )
                                } label: {
                                    Label("Down", systemImage: "arrow.down")
                                }
                                .buttonStyle(.bordered)
                                .disabled(yCandidates.count <= 1)
                            }
                        }

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

    private func nudgeSelectedPart(
        axis: MovementAxis,
        direction: Int,
        current: CanvasPoint,
        xCandidates: [Double],
        yCandidates: [Double],
        partID: String
    ) {
        let nextX: Double
        let nextY: Double

        switch axis {
        case .x:
            nextX = adjacentCandidate(from: current.x, in: xCandidates, direction: direction) ?? current.x
            nextY = current.y
        case .y:
            nextX = current.x
            nextY = adjacentCandidate(from: current.y, in: yCandidates, direction: direction) ?? current.y
        }

        let next = CanvasPoint(
            x: nextX.snapped(to: breadboardPitch),
            y: nextY.snapped(to: breadboardPitch)
        )
        projectStore.movePhysicalPart(id: partID, to: next)
    }

    private func breadboardColumnCandidates(centerX: Double, footprintWidth: Double) -> [Double] {
        let usableWidth = breadboardWidth * 0.82
        let count = max(20, Int((usableWidth / breadboardPitch).rounded()))
        let span = Double(max(count - 1, 1)) * breadboardPitch
        let start = centerX - span / 2
        let minX = centerX - (breadboardWidth / 2) + (footprintWidth / 2)
        let maxX = centerX + (breadboardWidth / 2) - (footprintWidth / 2)
        return (0..<count)
            .map { start + (Double($0) * breadboardPitch) }
            .filter { $0 >= minX && $0 <= maxX }
    }

    private func breadboardRowCandidates(centerY: Double, partKind: PartKind, footprintHeight: Double) -> [Double] {
        if partKind == .board {
            let minY = centerY - (breadboardHeight / 2) + (footprintHeight / 2)
            let maxY = centerY + (breadboardHeight / 2) - (footprintHeight / 2)
            return stride(from: minY, through: maxY, by: breadboardPitch).map { $0 }
        }

        let minY = centerY - (breadboardHeight / 2) + (footprintHeight / 2)
        let maxY = centerY + (breadboardHeight / 2) - (footprintHeight / 2)

        let rows: [Double]
        if footprintHeight > 32 || partKind == .servo || partKind == .motor || partKind == .rgbLamp {
            rows = [centerY + 26.67]
        } else {
            let terminalRows = [-16.51, -13.97, -11.43, -8.89, -6.35, 6.35, 8.89, 11.43, 13.97, 16.51].map { centerY + $0 }
            switch partKind {
            case .led, .button, .resistor, .buzzer, .speaker, .potentiometer:
                rows = terminalRows
            default:
                rows = terminalRows + [-31.75, -26.67, 26.67, 31.75].map { centerY + $0 }
            }
        }

        return rows.filter { $0 >= minY && $0 <= maxY }
    }

    private func adjacentCandidate(from current: Double, in candidates: [Double], direction: Int) -> Double? {
        guard candidates.isEmpty == false else { return nil }
        let ordered = candidates.sorted()
        let closestIndex = ordered.indices.min { abs(ordered[$0] - current) < abs(ordered[$1] - current) } ?? 0
        let nextIndex = (closestIndex + direction).clamped(to: ordered.startIndex...ordered.index(before: ordered.endIndex))
        return ordered[nextIndex]
    }
}

private enum MovementAxis {
    case x
    case y
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }

    func snapped(to step: Double) -> Double {
        guard step > 0 else { return self }
        return (self / step).rounded() * step
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
