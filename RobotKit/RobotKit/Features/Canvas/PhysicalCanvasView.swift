import SwiftUI

struct PhysicalCanvasView: View {
    @ObservedObject var projectStore: ProjectStore
    @State private var dragOrigins: [String: CanvasPoint] = [:]
    @State private var orbitYawDegrees = -36.0
    @State private var orbitPitchFactor = 0.50
    @State private var cameraZoom = 1.0
    @State private var cameraPan = CGSize.zero
    @State private var orbitDragStart: CameraOrbitState?

    private let canvasPadding: CGFloat = 24
    private let minimumPitchFactor = 0.24
    private let maximumPitchFactor = 0.78
    private let minimumCameraZoom = 0.55
    private let maximumCameraZoom = 2.2

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            GeometryReader { proxy in
                Group {
                    if projectStore.selectedPhysicalCanvasMode == .isometric {
                        isometricCanvas(in: proxy)
                    } else {
                        topDownCanvas(in: proxy)
                    }
                }
            }
            .background(Color(nsColor: .underPageBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Physical Layout")
                    .font(.headline)
                Text("Place components, inspect envelope volume, and generate the enclosure without leaving the project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Picker("Projection", selection: $projectStore.selectedPhysicalCanvasMode) {
                ForEach(ProjectStore.PhysicalCanvasMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 140)

            actionButton("Auto-layout", systemName: "wand.and.stars") {
                projectStore.autoLayoutPhysical()
            }
            actionButton("Compact This", systemName: "rectangle.compress.vertical") {
                projectStore.compactPhysicalLayout()
            }
            actionButton("Expose Ports", systemName: "arrow.up.forward.app") {
                projectStore.exposePhysicalPorts()
            }
            actionButton("Generate Enclosure", systemName: "cube.transparent") {
                projectStore.generateEnclosure()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func topDownCanvas(in proxy: GeometryProxy) -> some View {
        let canvas = projectStore.project.physical.canvas
        let scale = min(
            max(Double(proxy.size.width - canvasPadding * 2) / canvas.width, 0.4),
            max(Double(proxy.size.height - canvasPadding * 2) / canvas.height, 0.4)
        )

        return ZStack(alignment: .topLeading) {
            backgroundShell

            gridLayer(scale: scale)
            enclosurePlanLayer(scale: scale)

            ForEach(projectStore.project.physical.placements) { placement in
                if let part = projectStore.project.parts.first(where: { $0.id == placement.partID }) {
                    planPartCard(part: part, placement: placement, scale: scale)
                }
            }

            footerBadge
                .padding(18)
        }
        .padding(canvasPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            projectStore.handleCanvasPartActivation(nil)
        }
    }

    private func isometricCanvas(in proxy: GeometryProxy) -> some View {
        let enclosure = projectStore.project.physical.enclosure
        let scale = isometricScale(for: enclosure, in: proxy.size) * cameraZoom
        let origin = CGPoint(
            x: proxy.size.width * 0.5 + cameraPan.width,
            y: proxy.size.height * 0.74 + cameraPan.height
        )
        let sortedPlacements = projectStore.project.physical.placements.sorted {
            ($0.position.x + $0.position.y) < ($1.position.x + $1.position.y)
        }

        return ZStack(alignment: .topLeading) {
            backgroundShell
                .contentShape(Rectangle())
                .gesture(orbitGesture())

            isometricGuidePlane(
                enclosure: enclosure,
                scale: scale,
                origin: origin
            )

            ForEach(sortedPlacements) { placement in
                if let part = projectStore.project.parts.first(where: { $0.id == placement.partID }) {
                    isometricPart(part: part, placement: placement, enclosure: enclosure, scale: scale, origin: origin)
                }
            }

            isometricEnvelopeBadge(enclosure: enclosure)
                .padding(18)

            cameraHUD
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if let selectedPart = projectStore.selectedPart,
               projectStore.selectedPhysicalPlacement != nil {
                selectionHUD(for: selectedPart)
                    .padding(.trailing, 18)
                    .padding(.top, 144)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            footerBadge
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .padding(canvasPadding)
        .contentShape(Rectangle())
        .onTapGesture {
            projectStore.handleCanvasPartActivation(nil)
        }
    }

    private var backgroundShell: some View {
        RoundedRectangle(cornerRadius: 22)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.10, green: 0.13, blue: 0.18),
                        Color(red: 0.05, green: 0.07, blue: 0.10)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func actionButton(_ title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var cameraHUD: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Navigate 3D")
                .font(.caption.weight(.semibold))

            Text("Drag empty space to orbit")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                hudButton("minus.magnifyingglass") {
                    cameraZoom = (cameraZoom - 0.12).clamped(to: minimumCameraZoom...maximumCameraZoom)
                }
                hudButton("arrow.up.left.and.arrow.down.right") {
                    resetCamera()
                }
                hudButton("plus.magnifyingglass") {
                    cameraZoom = (cameraZoom + 0.12).clamped(to: minimumCameraZoom...maximumCameraZoom)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Orbit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    hudButton("rotate.left") {
                        orbitYawDegrees -= 12
                    }
                    hudButton("arrow.up") {
                        orbitPitchFactor = (orbitPitchFactor + 0.05).clamped(to: minimumPitchFactor...maximumPitchFactor)
                    }
                    hudButton("rotate.right") {
                        orbitYawDegrees += 12
                    }
                    hudButton("arrow.down") {
                        orbitPitchFactor = (orbitPitchFactor - 0.05).clamped(to: minimumPitchFactor...maximumPitchFactor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Pan")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    hudButton("arrow.left") {
                        cameraPan.width -= 28
                    }
                    hudButton("arrow.up") {
                        cameraPan.height -= 28
                    }
                    hudButton("arrow.down") {
                        cameraPan.height += 28
                    }
                    hudButton("arrow.right") {
                        cameraPan.width += 28
                    }
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func selectionHUD(for part: PartDefinition) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Selected Part")
                .font(.caption.weight(.semibold))
            Text(part.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                hudButton("rotate.left") {
                    projectStore.rotateSelectedPhysical(by: -90)
                }
                hudButton("rotate.right") {
                    projectStore.rotateSelectedPhysical(by: 90)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func hudButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func gridLayer(scale: Double) -> some View {
        let canvas = projectStore.project.physical.canvas
        let grid = max(canvas.grid * scale, 12)

        return Canvas { context, size in
            let step = CGFloat(grid)
            var path = Path()

            stride(from: canvasPadding, through: size.width - canvasPadding, by: step).forEach { x in
                path.move(to: CGPoint(x: x, y: canvasPadding))
                path.addLine(to: CGPoint(x: x, y: size.height - canvasPadding))
            }

            stride(from: canvasPadding, through: size.height - canvasPadding, by: step).forEach { y in
                path.move(to: CGPoint(x: canvasPadding, y: y))
                path.addLine(to: CGPoint(x: size.width - canvasPadding, y: y))
            }

            context.stroke(path, with: .color(.white.opacity(0.06)), lineWidth: 1)
        }
    }

    private func enclosurePlanLayer(scale: Double) -> some View {
        let enclosure = projectStore.project.physical.enclosure
        let width = CGFloat(enclosure.width * scale)
        let height = CGFloat(enclosure.height * scale)
        let center = planPoint(for: enclosure.center, scale: scale)

        return RoundedRectangle(cornerRadius: 26)
            .fill(Color.accentColor.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .strokeBorder(Color.accentColor.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [10, 7]))
            )
            .frame(width: width, height: height)
            .overlay(alignment: .topLeading) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enclosure")
                        .font(.caption.weight(.semibold))
                    Text("\(Int(enclosure.width)) × \(Int(enclosure.height)) × \(Int(enclosure.depth)) mm")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(10)
            }
            .position(center)
    }

    private func planPartCard(part: PartDefinition, placement: PhysicalPartPlacement, scale: Double) -> some View {
        let isSelected = part.id == projectStore.selectedPartID
        let size = CGSize(
            width: CGFloat(max(placement.footprint.width * scale, 48)),
            height: CGFloat(max(placement.footprint.height * scale, 34))
        )

        return RoundedRectangle(cornerRadius: 16)
            .fill(isSelected ? Color.accentColor.opacity(0.88) : Color.white.opacity(0.11))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
            )
            .overlay {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.label)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(2)
                    Text("\(part.kind.displayName) • \(placement.face.rawValue.capitalized)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.88) : Color.white.opacity(0.66))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
            }
            .frame(width: size.width, height: size.height)
            .rotationEffect(.degrees(placement.rotationDegrees))
            .position(planPoint(for: placement.position, scale: scale))
            .shadow(color: .black.opacity(isSelected ? 0.28 : 0.14), radius: isSelected ? 14 : 8, y: 6)
            .gesture(dragGesture(for: placement, scale: scale, isometric: false))
            .onTapGesture {
                projectStore.selectPart(id: part.id)
            }
    }

    private func isometricGuidePlane(
        enclosure: PhysicalEnclosure,
        scale: Double,
        origin: CGPoint
    ) -> some View {
        let x0 = enclosure.center.x - (enclosure.width / 2)
        let x1 = enclosure.center.x + (enclosure.width / 2)
        let y0 = enclosure.center.y - (enclosure.height / 2)
        let y1 = enclosure.center.y + (enclosure.height / 2)
        let z0 = 0.0
        let z1 = enclosure.depth

        let floor = [
            isoPoint(x: x0, y: y0, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y0, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x0, y: y1, z: z0, center: enclosure.center, scale: scale, origin: origin)
        ]
        let roof = [
            isoPoint(x: x0, y: y0, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y0, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x0, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin)
        ]
        let rightWall = [floor[1], floor[2], roof[2], roof[1]]
        let leftWall = [floor[2], floor[3], roof[3], roof[2]]

        return ZStack {
            PolygonShape(points: floor)
                .fill(Color.accentColor.opacity(0.12))
            PolygonShape(points: rightWall)
                .fill(Color.accentColor.opacity(0.07))
            PolygonShape(points: leftWall)
                .fill(Color.accentColor.opacity(0.05))

            PolygonShape(points: floor)
                .stroke(Color.accentColor.opacity(0.58), style: StrokeStyle(lineWidth: 2))
            PolygonShape(points: roof)
                .stroke(Color.accentColor.opacity(0.34), style: StrokeStyle(lineWidth: 1.5, dash: [9, 7]))

            ForEach(0..<4, id: \.self) { index in
                Path { path in
                    path.move(to: floor[index])
                    path.addLine(to: roof[index])
                }
                .stroke(Color.accentColor.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [6, 6]))
            }
        }
    }

    private func isometricPart(
        part: PartDefinition,
        placement: PhysicalPartPlacement,
        enclosure: PhysicalEnclosure,
        scale: Double,
        origin: CGPoint
    ) -> some View {
        let isSelected = part.id == projectStore.selectedPartID
        let width = placement.footprint.width
        let height = placement.footprint.height
        let depth = placement.footprint.depth
        let z0 = partElevation(for: placement, in: enclosure)
        let z1 = z0 + depth
        let x0 = placement.position.x - (width / 2)
        let x1 = placement.position.x + (width / 2)
        let y0 = placement.position.y - (height / 2)
        let y1 = placement.position.y + (height / 2)

        let top = [
            isoPoint(x: x0, y: y0, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y0, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x0, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin)
        ]
        let right = [
            isoPoint(x: x1, y: y0, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y0, z: z1, center: enclosure.center, scale: scale, origin: origin)
        ]
        let left = [
            isoPoint(x: x0, y: y1, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z0, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x1, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin),
            isoPoint(x: x0, y: y1, z: z1, center: enclosure.center, scale: scale, origin: origin)
        ]

        let points = top + right + left
        let bounds = bounds(for: points)
        let baseColor = isSelected ? Color.accentColor : Color.white.opacity(0.78)
        let topColor = isSelected ? Color.accentColor.opacity(0.96) : Color(red: 0.44, green: 0.51, blue: 0.63)
        let rightColor = isSelected ? Color.accentColor.opacity(0.72) : Color(red: 0.26, green: 0.33, blue: 0.42)
        let leftColor = isSelected ? Color.accentColor.opacity(0.54) : Color(red: 0.19, green: 0.25, blue: 0.33)

        return ZStack {
            PolygonShape(points: left)
                .fill(leftColor)
            PolygonShape(points: right)
                .fill(rightColor)
            PolygonShape(points: top)
                .fill(topColor)

            PolygonShape(points: left)
                .stroke(baseColor.opacity(0.22), lineWidth: 1)
            PolygonShape(points: right)
                .stroke(baseColor.opacity(0.22), lineWidth: 1)
            PolygonShape(points: top)
                .stroke(baseColor.opacity(0.92), lineWidth: isSelected ? 2 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(part.label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text("\(Int(width)) × \(Int(height)) × \(Int(depth)) mm")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .position(
                x: top.map(\.x).reduce(0, +) / CGFloat(top.count),
                y: top.map(\.y).reduce(0, +) / CGFloat(top.count) - 8
            )

            Color.clear
                .frame(width: bounds.width + 20, height: bounds.height + 20)
                .position(x: bounds.midX, y: bounds.midY)
                .contentShape(Rectangle())
                .gesture(dragGesture(for: placement, scale: scale, isometric: true))
                .onTapGesture {
                    projectStore.selectPart(id: part.id)
                }
        }
    }

    private func dragGesture(for placement: PhysicalPartPlacement, scale: Double, isometric: Bool) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                if dragOrigins[placement.partID] == nil {
                    dragOrigins[placement.partID] = placement.position
                }

                guard let origin = dragOrigins[placement.partID] else { return }
                projectStore.selectPart(id: placement.partID)

                let delta = isometric
                    ? isometricDelta(for: value.translation, scale: scale)
                    : CanvasPoint(
                        x: value.translation.width / scale,
                        y: value.translation.height / scale
                    )

                projectStore.movePhysicalPart(
                    id: placement.partID,
                    to: CanvasPoint(
                        x: (origin.x + delta.x).clamped(to: 80...1000),
                        y: (origin.y + delta.y).clamped(to: 80...640)
                    ),
                    shouldPersist: false
                )
            }
            .onEnded { _ in
                if let finalPosition = projectStore.project.physical.placement(for: placement.partID)?.position {
                    projectStore.movePhysicalPart(id: placement.partID, to: finalPosition)
                }
                dragOrigins.removeValue(forKey: placement.partID)
            }
    }

    private func orbitGesture() -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                if orbitDragStart == nil {
                    orbitDragStart = CameraOrbitState(
                        yawDegrees: orbitYawDegrees,
                        pitchFactor: orbitPitchFactor
                    )
                }

                guard let start = orbitDragStart else { return }
                orbitYawDegrees = start.yawDegrees + Double(value.translation.width) * 0.16
                orbitPitchFactor = (start.pitchFactor - Double(value.translation.height) * 0.0016)
                    .clamped(to: minimumPitchFactor...maximumPitchFactor)
            }
            .onEnded { _ in
                orbitDragStart = nil
            }
    }

    private func resetCamera() {
        orbitYawDegrees = -36
        orbitPitchFactor = 0.50
        cameraZoom = 1.0
        cameraPan = .zero
        orbitDragStart = nil
    }

    private var footerBadge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Generated from circuit parts")
                .font(.caption.weight(.semibold))
            Text("\(projectStore.project.physical.placements.count) placed • \(projectStore.project.generatedTextArtifacts.isEmpty ? "no CAD artifacts yet" : "CAD artifact ready")")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func isometricEnvelopeBadge(enclosure: PhysicalEnclosure) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("3D Envelope")
                .font(.caption.weight(.semibold))
            Text("\(Int(enclosure.width)) × \(Int(enclosure.height)) × \(Int(enclosure.depth)) mm")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func planPoint(for canvasPoint: CanvasPoint, scale: Double) -> CGPoint {
        CGPoint(
            x: canvasPadding + CGFloat(canvasPoint.x * scale),
            y: canvasPadding + CGFloat(canvasPoint.y * scale)
        )
    }

    private func isoPoint(
        x: Double,
        y: Double,
        z: Double,
        center: CanvasPoint,
        scale: Double,
        origin: CGPoint
    ) -> CGPoint {
        let yaw = orbitYawDegrees * .pi / 180
        let dx = x - center.x
        let dy = y - center.y
        let rotatedX = (dx * cos(yaw)) - (dy * sin(yaw))
        let rotatedY = (dx * sin(yaw)) + (dy * cos(yaw))
        let dz = z * scale

        return CGPoint(
            x: origin.x + CGFloat(rotatedX * scale),
            y: origin.y + CGFloat((rotatedY * scale * orbitPitchFactor) - (dz * 0.92))
        )
    }

    private func isometricScale(for enclosure: PhysicalEnclosure, in size: CGSize) -> Double {
        let horizontal = max(1, Double(size.width - canvasPadding * 2) / (max(enclosure.width, enclosure.height) * 1.65))
        let vertical = max(1, Double(size.height - canvasPadding * 2) / ((enclosure.width + enclosure.height) * 0.34 + enclosure.depth * 1.2))
        return min(horizontal, vertical)
    }

    private func partElevation(for placement: PhysicalPartPlacement, in enclosure: PhysicalEnclosure) -> Double {
        switch placement.face {
        case .top:
            return max(enclosure.wallThickness, enclosure.depth - placement.footprint.depth - enclosure.wallThickness)
        case .bottom:
            return enclosure.wallThickness
        case .front, .back, .side:
            return max(enclosure.depth * 0.4, placement.standoffHeight + enclosure.wallThickness)
        case .internal:
            return placement.standoffHeight + enclosure.wallThickness
        }
    }

    private func isometricDelta(for translation: CGSize, scale: Double) -> CanvasPoint {
        let yaw = orbitYawDegrees * .pi / 180
        let rotatedX = Double(translation.width) / scale
        let rotatedY = Double(translation.height) / (scale * orbitPitchFactor)
        return CanvasPoint(
            x: (rotatedX * cos(yaw)) + (rotatedY * sin(yaw)),
            y: -(rotatedX * sin(yaw)) + (rotatedY * cos(yaw))
        )
    }

    private func bounds(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private struct PolygonShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }

        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

private struct CameraOrbitState {
    let yawDegrees: Double
    let pitchFactor: Double
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
