import RealityKit
import SwiftUI

private let breadboardSurfaceWidthMm = 320.0
private let breadboardSurfaceHeightMm = 180.0
private let workbenchDeskWidthMm = 560.0
private let workbenchDeskDepthMm = 380.0
private let breadboardPitchMm = 2.54
private let breadboardTerminalRowOffsetsMm: [Double] = [-16.51, -13.97, -11.43, -8.89, -6.35, 6.35, 8.89, 11.43, 13.97, 16.51]
private let breadboardRailRowOffsetsMm: [Double] = [-31.75, -26.67, 26.67, 31.75]

struct PhysicalCanvasView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel

    var body: some View {
        content
            .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        if #available(macOS 15.0, *) {
            RealityKitWorkbenchScene(projectStore: projectStore, simulator: simulator)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .underPageBackgroundColor))
        } else {
            VStack(spacing: 12) {
                Image(systemName: "cube.transparent")
                    .font(.system(size: 36))
                Text("RealityKit workbench requires macOS 15 or newer.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .underPageBackgroundColor))
        }
    }
}

@available(macOS 15.0, *)
private struct RealityKitWorkbenchScene: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @State private var controller = WorkbenchSceneController()
    @State private var navigation = WorkbenchNavigationState.top
    @State private var dragStartNavigation: WorkbenchNavigationState?
    @State private var magnifyStartZoom: Double?
    @State private var pendingWireStart: PinReference?
    @State private var viewportSize: CGSize = .zero
    @State private var partDragSession: WorkbenchPartDragSession?
    @State private var transientPartPositions: [String: CanvasPoint] = [:]

    var body: some View {
        GeometryReader { proxy in
            RealityView { content in
                controller.install(
                    into: &content,
                    project: projectStore.project,
                    selectedPartID: projectStore.selectedPartID,
                    selectedWireID: projectStore.selectedWireID,
                    pinStates: simulator.pinStates,
                    activeButtons: projectStore.activeButtonIDs,
                    snapshot: simulator.worldSnapshot,
                    frameCount: simulator.frameCount,
                    navigation: navigation,
                    pendingWireStart: pendingWireStart,
                    transientPartPositions: transientPartPositions
                )
            } update: { content in
                controller.update(
                    content: &content,
                    project: projectStore.project,
                    selectedPartID: projectStore.selectedPartID,
                    selectedWireID: projectStore.selectedWireID,
                    pinStates: simulator.pinStates,
                    activeButtons: projectStore.activeButtonIDs,
                    snapshot: simulator.worldSnapshot,
                    frameCount: simulator.frameCount,
                    navigation: navigation,
                    pendingWireStart: pendingWireStart,
                    transientPartPositions: transientPartPositions
                )
            } placeholder: {
                ZStack {
                    Color(nsColor: .underPageBackgroundColor)
                    ProgressView()
                }
            }
            .task(id: proxy.size) {
                viewportSize = proxy.size
            }
            .simultaneousGesture(selectionGesture)
            .simultaneousGesture(partDragGesture)
            .gesture(orbitGesture)
            .simultaneousGesture(magnifyGesture)
            .overlay(alignment: .topTrailing) {
                if let selectedPart = projectStore.selectedPart {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(selectedPart.label)
                            .font(.caption.weight(.semibold))
                        Text(selectedPart.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding(18)
                }
            }
        }
    }

    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard partDragSession == nil else { return }
                if dragStartNavigation == nil {
                    dragStartNavigation = navigation
                }
                guard let dragStartNavigation else { return }
                navigation.yaw = dragStartNavigation.yaw + (value.translation.width * 0.0085)
                navigation.pitch = (dragStartNavigation.pitch - (value.translation.height * 0.0065))
                    .clamped(to: WorkbenchNavigationState.pitchRange)
            }
            .onEnded { _ in
                dragStartNavigation = nil
            }
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if magnifyStartZoom == nil {
                    magnifyStartZoom = navigation.zoom
                }
                guard let magnifyStartZoom else { return }
                navigation.zoom = (magnifyStartZoom * value.magnification).clamped(to: WorkbenchNavigationState.zoomRange)
            }
            .onEnded { _ in
                magnifyStartZoom = nil
            }
    }

    private var partDragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .targetedToAnyEntity()
            .onChanged { value in
                guard case .part(let partID) = WorkbenchTapTarget(from: value.entity) else { return }
                guard projectStore.project.parts.contains(where: { $0.id == partID }) else { return }
                guard let nextPosition = partDragPosition(for: partID, translation: value.translation) else { return }

                if partDragSession == nil || partDragSession?.partID != partID {
                    if let placement = projectStore.project.physical.placement(for: partID) {
                        partDragSession = WorkbenchPartDragSession(partID: partID, startPosition: placement.position)
                    }
                    projectStore.selectPart(id: partID)
                    pendingWireStart = nil
                }

                transientPartPositions[partID] = nextPosition
            }
            .onEnded { value in
                guard case .part(let partID) = WorkbenchTapTarget(from: value.entity) else { return }
                defer {
                    partDragSession = nil
                    transientPartPositions.removeValue(forKey: partID)
                }
                guard projectStore.project.parts.contains(where: { $0.id == partID }) else { return }
                let nextPosition = transientPartPositions[partID] ?? partDragPosition(for: partID, translation: value.translation)
                guard let nextPosition else { return }
                projectStore.movePhysicalPart(id: partID, to: nextPosition, shouldPersist: true)
            }
    }

    private var selectionGesture: some Gesture {
        TapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                switch WorkbenchTapTarget(from: value.entity) {
                case .part(let partID):
                    pendingWireStart = nil
                    projectStore.handleCanvasPartActivation(partID)
                case .wire(let wireID):
                    pendingWireStart = nil
                    projectStore.handleCanvasWireActivation(wireID)
                case .pin(let reference):
                    projectStore.selectPart(id: reference.partID)

                    if let pendingWireStart, pendingWireStart != reference {
                        projectStore.createWire(from: pendingWireStart, to: reference)
                        self.pendingWireStart = nil
                    } else if pendingWireStart == reference {
                        pendingWireStart = nil
                    } else {
                        pendingWireStart = reference
                    }
                case .none:
                    break
                }
            }
    }

    private func partDragPosition(for partID: String, translation: CGSize) -> CanvasPoint? {
        guard viewportSize.width > 1, viewportSize.height > 1 else { return nil }
        guard let placement = projectStore.project.physical.placement(for: partID) else { return nil }
        guard let part = projectStore.project.parts.first(where: { $0.id == partID }) else { return nil }

        let startPosition = partDragSession?.partID == partID
            ? (partDragSession?.startPosition ?? placement.position)
            : placement.position
        let boardCenter = projectStore.project.physical.enclosure.center
        let projectedPixelsPerMm = min(
            Double(viewportSize.width) / breadboardSurfaceWidthMm,
            Double(viewportSize.height) / breadboardSurfaceHeightMm
        ) * Double(navigation.zoom) * 0.72
        guard projectedPixelsPerMm > 0.0001 else { return nil }

        let mmPerPoint = 1 / projectedPixelsPerMm
        let dx = Double(translation.width) * mmPerPoint
        let dy = Double(translation.height) * mmPerPoint
        let yaw = navigation.yaw
        let rotatedX = (dx * cos(yaw)) - (dy * sin(yaw))
        let rotatedY = (dx * sin(yaw)) + (dy * cos(yaw))

        let candidate = CanvasPoint(
            x: startPosition.x + rotatedX,
            y: startPosition.y + rotatedY
        )
        return resolvedWorkbenchPosition(
            candidate,
            footprint: placement.footprint,
            partKind: part.kind,
            boardCenter: boardCenter
        )
    }

    private func resolvedWorkbenchPosition(
        _ position: CanvasPoint,
        footprint: PhysicalFootprint,
        partKind: PartKind,
        boardCenter: CanvasPoint
    ) -> CanvasPoint {
        return normalizedBreadboardPosition(
            position,
            footprint: footprint,
            partKind: partKind,
            boardCenter: boardCenter
        )
    }

    private func normalizedBreadboardPosition(
        _ position: CanvasPoint,
        footprint: PhysicalFootprint,
        partKind: PartKind,
        boardCenter: CanvasPoint
    ) -> CanvasPoint {
        let minX = boardCenter.x - (breadboardSurfaceWidthMm / 2) + (footprint.width / 2)
        let maxX = boardCenter.x + (breadboardSurfaceWidthMm / 2) - (footprint.width / 2)
        let minY = boardCenter.y - (breadboardSurfaceHeightMm / 2) + (footprint.height / 2)
        let maxY = boardCenter.y + (breadboardSurfaceHeightMm / 2) - (footprint.height / 2)

        let xCandidates = breadboardColumnCenters(centerX: boardCenter.x).filter { $0 >= minX && $0 <= maxX }
        let yCandidates = breadboardRowCenters(centerY: boardCenter.y, partKind: partKind, footprintHeight: footprint.height)
            .filter { $0 >= minY && $0 <= maxY }

        return CanvasPoint(
            x: nearestCandidate(to: position.x, candidates: xCandidates) ?? position.x.clamped(to: minX...maxX),
            y: nearestCandidate(to: position.y, candidates: yCandidates) ?? position.y.clamped(to: minY...maxY)
        )
    }

    private func breadboardColumnCenters(centerX: Double) -> [Double] {
        let usableWidth = breadboardSurfaceWidthMm * 0.82
        let count = max(20, Int((usableWidth / breadboardPitchMm).rounded()))
        let span = Double(max(count - 1, 1)) * breadboardPitchMm
        let start = centerX - span / 2
        return (0..<count).map { start + Double($0) * breadboardPitchMm }
    }

    private func breadboardRowCenters(centerY: Double, partKind: PartKind, footprintHeight: Double) -> [Double] {
        if partKind == .board {
            let minY = centerY - (breadboardSurfaceHeightMm / 2) + (footprintHeight / 2)
            let maxY = centerY + (breadboardSurfaceHeightMm / 2) - (footprintHeight / 2)
            return stride(from: minY, through: maxY, by: breadboardPitchMm).map { $0 }
        }

        if footprintHeight > 32 || partKind == .servo || partKind == .motor || partKind == .rgbLamp {
            let laneOffset = footprintHeight <= 42 ? breadboardRailRowOffsetsMm[2] : 0
            return [centerY + laneOffset]
        }

        let terminalRows = breadboardTerminalRowOffsetsMm.map { centerY + $0 }
        switch partKind {
        case .led, .button, .resistor, .buzzer, .speaker, .potentiometer:
            return terminalRows
        default:
            return terminalRows + breadboardRailRowOffsetsMm.map { centerY + $0 }
        }
    }

    private func nearestCandidate(to value: Double, candidates: [Double]) -> Double? {
        candidates.min { abs($0 - value) < abs($1 - value) }
    }
}

private struct WorkbenchNavigationState: Equatable {
    static let pitchRange: ClosedRange<Double> = (-1.54)...1.54
    static let zoomRange: ClosedRange<Double> = 0.08...10.0

    var yaw: Double = -0.55
    var pitch: Double = -0.42
    var zoom: Double = 0.86
    var pan = CGSize(width: 0, height: -0.03)

    static let `default` = WorkbenchNavigationState()
    static let top = WorkbenchNavigationState(yaw: 0, pitch: 1.54, zoom: 2.05, pan: CGSize(width: 0, height: -0.02))
    static let front = WorkbenchNavigationState(yaw: 0, pitch: -0.02, zoom: 1.05, pan: CGSize(width: 0, height: -0.02))
}

@available(macOS 15.0, *)
@MainActor
private final class WorkbenchSceneController {
    private static let rootName = "robotkit-workbench-root"
    private static let partsContainerName = "robotkit-workbench-parts"
    private static let cameraTargetName = "robotkit-workbench-camera-target"

    private let root = Entity()
    private let partsContainer = Entity()
    private let cameraTarget = Entity()
    private var partEntities: [String: Entity] = [:]
    private var wireEntities: [String: Entity] = [:]
    private var pinEntities: [WorkbenchPinKey: ModelEntity] = [:]
    private var staticSceneSignature = ""
    private var wireSceneSignature = ""
    private var transientPartPositions: [String: CanvasPoint] = [:]
    private var installed = false

    init() {
        root.name = Self.rootName
        partsContainer.name = Self.partsContainerName
        cameraTarget.name = Self.cameraTargetName
        root.addChild(partsContainer)
        root.addChild(cameraTarget)

        let sun = DirectionalLight()
        sun.light.intensity = 18_000
        sun.position = [0.9, 1.4, 0.7]
        sun.orientation = simd_quatf(angle: -.pi / 4.5, axis: [1, 0, 0]) * simd_quatf(angle: .pi / 5, axis: [0, 1, 0])
        root.addChild(sun)
    }

    func install(
        into content: inout RealityViewCameraContent,
        project: RobotProject,
        selectedPartID: String?,
        selectedWireID: String?,
        pinStates: [String: Int],
        activeButtons: Set<String>,
        snapshot: SimulationWorldSnapshot,
        frameCount: Int,
        navigation: WorkbenchNavigationState,
        pendingWireStart: PinReference?,
        transientPartPositions: [String: CanvasPoint]
    ) {
        guard installed == false else {
            update(
                content: &content,
                project: project,
                selectedPartID: selectedPartID,
                selectedWireID: selectedWireID,
                pinStates: pinStates,
                activeButtons: activeButtons,
                snapshot: snapshot,
                frameCount: frameCount,
                navigation: navigation,
                pendingWireStart: pendingWireStart,
                transientPartPositions: transientPartPositions
            )
            return
        }

        content.camera = .virtual
        content.environment = .default
        content.add(root)
        content.cameraTarget = cameraTarget
        installed = true

        update(
            content: &content,
            project: project,
            selectedPartID: selectedPartID,
            selectedWireID: selectedWireID,
            pinStates: pinStates,
            activeButtons: activeButtons,
            snapshot: snapshot,
            frameCount: frameCount,
            navigation: navigation,
            pendingWireStart: pendingWireStart,
            transientPartPositions: transientPartPositions
        )
    }

    func update(
        content: inout RealityViewCameraContent,
        project: RobotProject,
        selectedPartID: String?,
        selectedWireID: String?,
        pinStates: [String: Int],
        activeButtons: Set<String>,
        snapshot: SimulationWorldSnapshot,
        frameCount: Int,
        navigation: WorkbenchNavigationState,
        pendingWireStart: PinReference?,
        transientPartPositions: [String: CanvasPoint]
    ) {
        content.cameraTarget = cameraTarget

        let nextStaticSignature = staticSignature(for: project)
        let nextWireSignature = wireSignature(for: project)
        if nextStaticSignature != staticSceneSignature {
            rebuildStaticScene(for: project)
            staticSceneSignature = nextStaticSignature
            wireSceneSignature = nextWireSignature
        } else if nextWireSignature != wireSceneSignature {
            rebuildWireEntities(for: project)
            wireSceneSignature = nextWireSignature
        }

        refreshTransientWireEntitiesIfNeeded(project: project, transientPartPositions: transientPartPositions)

        applyNavigation(navigation)

        updateDynamicState(
            project: project,
            selectedPartID: selectedPartID,
            selectedWireID: selectedWireID,
            pinStates: pinStates,
            activeButtons: activeButtons,
            snapshot: snapshot,
            frameCount: frameCount,
            pendingWireStart: pendingWireStart,
            transientPartPositions: transientPartPositions
        )
    }

    private func rebuildStaticScene(for project: RobotProject) {
        partEntities.removeAll()
        pinEntities.removeAll()
        partsContainer.children.removeAll()

        let workbench = makeWorkbenchSurface(enclosure: project.physical.enclosure)
        partsContainer.addChild(workbench)

        let boundsEntity = makeBoundsFrame(enclosure: project.physical.enclosure)
        partsContainer.addChild(boundsEntity)

        for placement in project.physical.placements {
            guard let part = project.parts.first(where: { $0.id == placement.partID }) else { continue }
            let entity = makePartEntity(part: part, placement: placement, enclosure: project.physical.enclosure)
            partEntities[part.id] = entity
            partsContainer.addChild(entity)
        }

        rebuildWireEntities(for: project)

        cameraTarget.position = [0, 0.03, 0]
    }

    private func rebuildWireEntities(for project: RobotProject) {
        for entity in wireEntities.values {
            entity.removeFromParent()
        }
        wireEntities.removeAll()

        for wire in project.diagram.wires {
            guard let entity = makeWireEntity(wire: wire, project: project, transientPartPositions: transientPartPositions) else { continue }
            wireEntities[wire.id] = entity
            partsContainer.addChild(entity)
        }
    }

    private func refreshTransientWireEntitiesIfNeeded(project: RobotProject, transientPartPositions nextTransientPositions: [String: CanvasPoint]) {
        guard nextTransientPositions != transientPartPositions else { return }

        let changedPartIDs = Set(transientPartPositions.keys).union(nextTransientPositions.keys).filter { partID in
            transientPartPositions[partID] != nextTransientPositions[partID]
        }

        transientPartPositions = nextTransientPositions

        guard changedPartIDs.isEmpty == false else { return }

        let affectedWireIDs = project.diagram.wires
            .filter { changedPartIDs.contains($0.from.partID) || changedPartIDs.contains($0.to.partID) }
            .map(\.id)

        guard affectedWireIDs.isEmpty == false else { return }

        for wireID in affectedWireIDs {
            wireEntities[wireID]?.removeFromParent()
            wireEntities.removeValue(forKey: wireID)
        }

        for wire in project.diagram.wires where affectedWireIDs.contains(wire.id) {
            guard let entity = makeWireEntity(wire: wire, project: project, transientPartPositions: transientPartPositions) else { continue }
            wireEntities[wire.id] = entity
            partsContainer.addChild(entity)
        }
    }

    private func applyNavigation(_ navigation: WorkbenchNavigationState) {
        let yaw = simd_quatf(angle: Float(navigation.yaw), axis: [0, 1, 0])
        let pitch = simd_quatf(angle: Float(navigation.pitch), axis: [1, 0, 0])
        partsContainer.orientation = yaw * pitch
        let zoom = Float(navigation.zoom)
        partsContainer.scale = [zoom, zoom, zoom]
        partsContainer.position = [Float(navigation.pan.width), Float(navigation.pan.height), 0]
    }

    private func updateDynamicState(
        project: RobotProject,
        selectedPartID: String?,
        selectedWireID: String?,
        pinStates: [String: Int],
        activeButtons: Set<String>,
        snapshot: SimulationWorldSnapshot,
        frameCount: Int,
        pendingWireStart: PinReference?,
        transientPartPositions: [String: CanvasPoint]
    ) {
        let selectedWire = selectedWireID.flatMap { id in
            project.diagram.wires.first(where: { $0.id == id })
        }

        for placement in project.physical.placements {
            guard
                let part = project.parts.first(where: { $0.id == placement.partID }),
                let entity = partEntities[part.id]
            else {
                continue
            }

            entity.position = worldPosition(
                for: effectivePlacement(placement, partID: part.id, transientPartPositions: transientPartPositions),
                partKind: part.kind,
                enclosure: project.physical.enclosure
            )
            entity.orientation = simd_quatf(angle: Float(placement.rotationDegrees) * (.pi / 180), axis: [0, 1, 0])

            let isSelected = selectedPartID == part.id
            let isActive = CircuitGraph.partIsActive(part, in: project, pinStates: pinStates, activeButtons: activeButtons)
            let emphasisScale: Float = isSelected ? 1.04 : 1.0
            entity.scale = [emphasisScale, emphasisScale, emphasisScale]

            if let pedestal = entity.findEntity(named: "pedestal") as? ModelEntity {
                pedestal.model?.materials = [unlitMaterial(isSelected ? NSColor.systemBlue.withAlphaComponent(0.9) : NSColor.white.withAlphaComponent(0.16))]
            }

            switch part.kind {
            case .led:
                if let bulb = entity.findEntity(named: "bulb") as? ModelEntity {
                    let litColor = nsColor(for: part, active: isActive)
                    bulb.model?.materials = [
                        isActive
                            ? glowingMaterial(color: litColor, intensity: 3.2)
                            : simpleMaterial(NSColor(calibratedWhite: 0.92, alpha: 1), roughness: 0.18, metallic: 0.0)
                    ]
                    bulb.scale = isActive ? [1.12, 1.12, 1.12] : [1, 1, 1]
                }
                if let glow = entity.findEntity(named: "led-glow") as? ModelEntity {
                    let glowColor = nsColor(for: part, active: true)
                    glow.model?.materials = [
                        unlitMaterial(isActive ? glowColor.withAlphaComponent(0.28) : glowColor.withAlphaComponent(0.02))
                    ]
                    glow.scale = isActive ? [1.9, 1.9, 1.9] : [0.55, 0.55, 0.55]
                }
            case .rgbLamp:
                if let bulb = entity.findEntity(named: "bulb") as? ModelEntity {
                    let color = NSColor(
                        calibratedRed: CGFloat(max(snapshot.lamp.redLevel, 0.08)),
                        green: CGFloat(max(snapshot.lamp.greenLevel, 0.08)),
                        blue: CGFloat(max(snapshot.lamp.blueLevel, 0.08)),
                        alpha: 1
                    )
                    let intensity = Float(max(snapshot.lamp.redLevel, max(snapshot.lamp.greenLevel, snapshot.lamp.blueLevel)))
                    bulb.model?.materials = [glowingMaterial(color: color, intensity: max(intensity * 1.5, 0.08))]
                }
                if let glow = entity.findEntity(named: "lamp-glow") as? ModelEntity {
                    let color = NSColor(
                        calibratedRed: CGFloat(max(snapshot.lamp.redLevel, 0.12)),
                        green: CGFloat(max(snapshot.lamp.greenLevel, 0.12)),
                        blue: CGFloat(max(snapshot.lamp.blueLevel, 0.12)),
                        alpha: 1
                    )
                    let intensity = Float(max(snapshot.lamp.redLevel, max(snapshot.lamp.greenLevel, snapshot.lamp.blueLevel)))
                    glow.model?.materials = [
                        unlitMaterial(color.withAlphaComponent(CGFloat(max(0.05, intensity * 0.4))))
                    ]
                    let glowScale = max(0.65, 0.85 + intensity * 1.5)
                    glow.scale = [glowScale, glowScale, glowScale]
                }
            case .button:
                if let cap = entity.findEntity(named: "button-cap") {
                    let pressed = activeButtons.contains(part.id)
                    cap.position.y = pressed ? 0.004 : 0.008
                }
            case .servo:
                if let arm = entity.findEntity(named: "servo-arm") {
                    let angle = Float(snapshot.mechanism.servoAngle) * (.pi / 180)
                    arm.orientation = simd_quatf(angle: -angle, axis: [0, 1, 0])
                }
                if let leftFinger = entity.findEntity(named: "left-finger") {
                    let closure = Float(snapshot.mechanism.servoAngle / 180)
                    leftFinger.orientation = simd_quatf(angle: -(0.18 + closure * 0.6), axis: [0, 0, 1])
                }
                if let rightFinger = entity.findEntity(named: "right-finger") {
                    let closure = Float(snapshot.mechanism.servoAngle / 180)
                    rightFinger.orientation = simd_quatf(angle: 0.18 + closure * 0.6, axis: [0, 0, 1])
                }
            case .motor:
                if let shaft = entity.findEntity(named: "motor-shaft") {
                    let side = part.attributes["side"] ?? ""
                    let power = side == "right" ? snapshot.rover.rightMotorPower : snapshot.rover.leftMotorPower
                    let spin = Float(frameCount) * Float(power) * 0.2
                    shaft.orientation = simd_quatf(angle: spin, axis: [1, 0, 0])
                }
            case .speaker, .buzzer:
                if let cone = entity.findEntity(named: "speaker-cone") {
                    let amplitude = Float(snapshot.lamp.speakerLevel) * 0.006
                    cone.position.z = amplitude
                }
                default:
                    if let body = entity.findEntity(named: "body") as? ModelEntity {
                        body.model?.materials = [partMaterial(for: part, isActive: isActive, selected: isSelected)]
                    }
                }

            for pin in part.pins {
                let key = WorkbenchPinKey(partID: part.id, pin: pin)
                guard let marker = pinEntities[key] else { continue }
                let reference = PinReference(partID: part.id, pin: pin)
                let connectsSelectedWire = selectedWire.map { $0.from == reference || $0.to == reference } ?? false
                let isPending = pendingWireStart == reference
                let emphasize = isPending || connectsSelectedWire || isSelected
                marker.model?.materials = [simpleMaterial(NSColor(calibratedWhite: 0.08, alpha: 1), roughness: 0.52, metallic: 0.12)]
                if let insert = marker.findEntity(named: "jack-insert") as? ModelEntity {
                    let alpha: CGFloat = isPending ? 0.96 : (emphasize ? 0.84 : 0.04)
                    insert.model?.materials = [unlitMaterial(pinMarkerColor(for: pin, emphasized: emphasize, pending: isPending).withAlphaComponent(alpha))]
                }
                let scale: Float = isPending ? 1.16 : (emphasize ? 1.04 : 0.88)
                marker.scale = [scale, scale, scale]
            }
        }

        for wire in project.diagram.wires {
            guard let entity = wireEntities[wire.id] else { continue }
            let isSelected = selectedWireID == wire.id
            let touchesPendingStart = pendingWireStart.map { $0 == wire.from || $0 == wire.to } ?? false
            updateWireAppearance(entity, colorName: wire.color, selected: isSelected, pending: touchesPendingStart)
        }
    }

    private func staticSignature(for project: RobotProject) -> String {
        let enclosure = project.physical.enclosure
        let enclosureSignature = [
            String(format: "%.1f", enclosure.width),
            String(format: "%.1f", enclosure.height),
            String(format: "%.1f", enclosure.depth),
            String(format: "%.1f", enclosure.center.x),
            String(format: "%.1f", enclosure.center.y)
        ].joined(separator: "|")
        let parts = project.parts
            .sorted { $0.id < $1.id }
            .map { part in
                let footprint = PhysicalFootprint.resolved(for: part)
                return [
                    part.id,
                    part.kind.rawValue,
                    String(format: "%.1f", footprint.width),
                    String(format: "%.1f", footprint.height),
                    String(format: "%.1f", footprint.depth)
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        let wires = project.diagram.wires
            .sorted { $0.id < $1.id }
            .map {
                [
                    $0.id,
                    $0.from.partID,
                    $0.from.pin,
                    $0.to.partID,
                    $0.to.pin,
                    $0.color
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        return [enclosureSignature, parts, wires].joined(separator: "\n--\n")
    }

    private func wireSignature(for project: RobotProject) -> String {
        let placements = project.physical.placements
            .sorted { $0.partID < $1.partID }
            .map {
                [
                    $0.partID,
                    String(format: "%.2f", $0.position.x),
                    String(format: "%.2f", $0.position.y),
                    String(format: "%.1f", $0.rotationDegrees),
                    String(format: "%.1f", $0.standoffHeight),
                    String(format: "%.1f", $0.footprint.width),
                    String(format: "%.1f", $0.footprint.height),
                    String(format: "%.1f", $0.footprint.depth),
                    $0.face.rawValue,
                    $0.mount.rawValue
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        let wires = project.diagram.wires
            .sorted { $0.id < $1.id }
            .map {
                [
                    $0.id,
                    $0.from.partID,
                    $0.from.pin,
                    $0.to.partID,
                    $0.to.pin,
                    $0.color
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        return [placements, wires].joined(separator: "\n--\n")
    }

    private func makeWorkbenchSurface(enclosure: PhysicalEnclosure) -> Entity {
        let deskWidth = Float(workbenchDeskWidthMm) * 0.001
        let deskDepth = Float(workbenchDeskDepthMm) * 0.001
        let breadboardWidth = Float(breadboardSurfaceWidthMm) * 0.001
        let breadboardDepth = Float(breadboardSurfaceHeightMm) * 0.001

        let deskTop = ModelEntity(
            mesh: .generateBox(width: deskWidth, height: 0.024, depth: deskDepth, cornerRadius: 0.02),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.82, alpha: 1), roughness: 0.95, metallic: 0.01)]
        )
        deskTop.position = [0, -0.02, 0]

        let breadboard = ModelEntity(
            mesh: .generateBox(width: breadboardWidth, height: 0.008, depth: breadboardDepth, cornerRadius: 0.012),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.985, alpha: 1), roughness: 0.94, metallic: 0.01)]
        )
        breadboard.position = [0, -0.002, 0]

        let trench = ModelEntity(
            mesh: .generateBox(width: breadboardWidth * 0.9, height: 0.0012, depth: 0.016, cornerRadius: 0.003),
            materials: [unlitMaterial(NSColor(calibratedWhite: 0.88, alpha: 1))]
        )
        trench.position = [0, 0.0025, 0]

        let railRedTop = ModelEntity(
            mesh: .generateBox(width: breadboardWidth * 0.9, height: 0.0007, depth: 0.0022, cornerRadius: 0.0008),
            materials: [unlitMaterial(NSColor.systemRed.withAlphaComponent(0.7))]
        )
        railRedTop.position = [0, 0.0026, -breadboardDepth * 0.33]
        let railBlueTop = railRedTop.clone(recursive: true)
        railBlueTop.model?.materials = [unlitMaterial(NSColor.systemBlue.withAlphaComponent(0.55))]
        railBlueTop.position = [0, 0.0026, -breadboardDepth * 0.28]
        let railRedBottom = railRedTop.clone(recursive: true)
        railRedBottom.position = [0, 0.0026, breadboardDepth * 0.28]
        let railBlueBottom = railBlueTop.clone(recursive: true)
        railBlueBottom.position = [0, 0.0026, breadboardDepth * 0.33]

        let entity = Entity()
        entity.addChild(deskTop)
        entity.addChild(breadboard)
        entity.addChild(trench)
        entity.addChild(railRedTop)
        entity.addChild(railBlueTop)
        entity.addChild(railRedBottom)
        entity.addChild(railBlueBottom)

        let terminalColumnCount = max(18, Int((Double(breadboardWidth) * 1000 * 0.82) / breadboardPitchMm))
        let railColumnCount = max(terminalColumnCount - 2, 12)
        let terminalSpan = breadboardWidth * 0.82
        let railSpan = breadboardWidth * 0.78

        for rowOffsetMm in breadboardTerminalRowOffsetsMm {
            let z = Float(rowOffsetMm) * 0.001
            for column in 0..<terminalColumnCount {
                let t = Float(column) / Float(max(terminalColumnCount - 1, 1))
                let x = -terminalSpan / 2 + t * terminalSpan
                let hole = ModelEntity(
                    mesh: .generateCylinder(height: 0.0008, radius: 0.0008),
                    materials: [unlitMaterial(NSColor(calibratedWhite: 0.78, alpha: 0.75))]
                )
                hole.position = [x, 0.0028, z]
                entity.addChild(hole)
            }
        }

        for railOffsetMm in breadboardRailRowOffsetsMm {
            let z = Float(railOffsetMm) * 0.001
            for column in 0..<railColumnCount {
                let t = Float(column) / Float(max(railColumnCount - 1, 1))
                let x = -railSpan / 2 + t * railSpan
                let hole = ModelEntity(
                    mesh: .generateCylinder(height: 0.0008, radius: 0.0008),
                    materials: [unlitMaterial(NSColor(calibratedWhite: 0.76, alpha: 0.72))]
                )
                hole.position = [x, 0.0028, z]
                entity.addChild(hole)
            }
        }
        return entity
    }

    private func makeBoundsFrame(enclosure: PhysicalEnclosure) -> Entity {
        let width = Float(breadboardSurfaceWidthMm) * 0.001
        let depth = Float(breadboardSurfaceHeightMm) * 0.001
        let railHeight: Float = 0.003
        let railThickness: Float = 0.004

        let entity = Entity()
        let railMaterial = unlitMaterial(NSColor(calibratedWhite: 0.68, alpha: 0.34))

        let top = ModelEntity(mesh: .generateBox(width: width, height: railHeight, depth: railThickness), materials: [railMaterial])
        top.position = [0, 0.001, -depth / 2]
        let bottom = ModelEntity(mesh: .generateBox(width: width, height: railHeight, depth: railThickness), materials: [railMaterial])
        bottom.position = [0, 0.001, depth / 2]
        let left = ModelEntity(mesh: .generateBox(width: railThickness, height: railHeight, depth: depth), materials: [railMaterial])
        left.position = [-width / 2, 0.001, 0]
        let right = ModelEntity(mesh: .generateBox(width: railThickness, height: railHeight, depth: depth), materials: [railMaterial])
        right.position = [width / 2, 0.001, 0]

        entity.addChild(top)
        entity.addChild(bottom)
        entity.addChild(left)
        entity.addChild(right)
        return entity
    }

    private func makePartEntity(part: PartDefinition, placement: PhysicalPartPlacement, enclosure: PhysicalEnclosure) -> Entity {
        let entity = Entity()
        entity.name = partEntityName(for: part.id)
        entity.position = worldPosition(for: placement, partKind: part.kind, enclosure: enclosure)
        entity.orientation = simd_quatf(angle: Float(placement.rotationDegrees) * (.pi / 180), axis: [0, 1, 0])

        let pedestal = ModelEntity(
            mesh: .generateCylinder(height: 0.0015, radius: max(Float(placement.footprint.width), Float(placement.footprint.height)) * 0.00037),
            materials: [unlitMaterial(NSColor.white.withAlphaComponent(0.16))]
        )
        pedestal.name = "pedestal"
        pedestal.position = [0, -0.0005, 0]
        entity.addChild(pedestal)
        entity.addChild(makePanelBase(placement: placement))

        switch part.kind {
        case .board:
            entity.addChild(makeBoardEntity(placement: placement))
        case .led:
            entity.addChild(makeLEDEntity(part: part))
        case .resistor:
            entity.addChild(makeResistorEntity())
        case .button:
            entity.addChild(makeButtonEntity())
        case .buzzer, .speaker:
            entity.addChild(makeSpeakerEntity(part: part))
        case .sevenSegment:
            entity.addChild(makeSevenSegmentEntity())
        case .potentiometer:
            entity.addChild(makePotentiometerEntity())
        case .shiftRegister, .motorDriver, .soilSensor, .lightSensor, .climateSensor, .relay, .oledDisplay,
             .microphone, .lineSensor, .digitalSensorModule, .analogSensorModule, .i2cSensorModule,
             .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            entity.addChild(makeModuleEntity(part: part, placement: placement))
        case .rgbLamp:
            entity.addChild(makeLampEntity())
        case .motor:
            entity.addChild(makeMotorEntity())
        case .servo:
            entity.addChild(makeServoEntity())
        }

        installPinMarkers(on: entity, part: part, placement: placement)
        enableInteraction(on: entity)
        return entity
    }

    private func installPinMarkers(on entity: Entity, part: PartDefinition, placement: PhysicalPartPlacement) {
        for pin in part.pins {
            guard let position = localPinPosition(for: pin, part: part, placement: placement) else { continue }
            let marker = makePinJackEntity(color: pinMarkerColor(for: pin, emphasized: false, pending: false))
            marker.name = pinEntityName(for: part.id, pin: pin)
            marker.position = position
            marker.components.set(InputTargetComponent())
            marker.generateCollisionShapes(recursive: false)
            pinEntities[WorkbenchPinKey(partID: part.id, pin: pin)] = marker
            entity.addChild(marker)
        }
    }

    private func makeWireEntity(wire: WireDefinition, project: RobotProject, transientPartPositions: [String: CanvasPoint]) -> Entity? {
        guard
            let start = pinScenePosition(for: wire.from, project: project, transientPartPositions: transientPartPositions),
            let end = pinScenePosition(for: wire.to, project: project, transientPartPositions: transientPartPositions)
        else {
            return nil
        }

        let span = simd_length(end - start)
        let lift = max(start.y, end.y) + min(0.02, max(0.007, span * 0.22))
        let lateralSeed = Float(abs(wire.id.hashValue % 11) - 5) * 0.002
        let control1 = SIMD3<Float>(start.x + lateralSeed, lift, start.z + span * 0.18)
        let control2 = SIMD3<Float>(end.x - lateralSeed, lift * 0.97, end.z - span * 0.18)
        let points = sampledCablePath(from: start, control1: control1, control2: control2, to: end, steps: 22)

        let root = Entity()
        root.name = wireEntityName(for: wire.id)

        for index in 0..<(points.count - 1) {
            let from = points[index]
            let to = points[index + 1]
            guard let segment = makeWireSegment(from: from, to: to, color: wireColor(named: wire.color)) else { continue }
            segment.name = "wire-segment-\(index)"
            root.addChild(segment)
        }

        if let startPlug = makeCablePlug(at: start, toward: points[min(1, points.count - 1)], color: wireColor(named: wire.color)) {
            root.addChild(startPlug)
        }
        if let endPlug = makeCablePlug(at: end, toward: points[max(points.count - 2, 0)], color: wireColor(named: wire.color)) {
            root.addChild(endPlug)
        }

        enableInteraction(on: root)
        return root
    }

    private func makeWireSegment(from start: SIMD3<Float>, to end: SIMD3<Float>, color: NSColor) -> ModelEntity? {
        let delta = end - start
        let length = simd_length(delta)
        guard length > 0.0005 else { return nil }

        let segment = ModelEntity(
            mesh: .generateCylinder(height: length, radius: 0.00095),
            materials: [simpleMaterial(color.withAlphaComponent(0.92), roughness: 0.72, metallic: 0)]
        )
        segment.position = (start + end) * 0.5
        segment.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))
        return segment
    }

    private func makeCablePlug(at point: SIMD3<Float>, toward neighbor: SIMD3<Float>, color: NSColor) -> Entity? {
        let delta = neighbor - point
        guard simd_length(delta) > 0.0001 else { return nil }

        let plug = ModelEntity(
            mesh: .generateCylinder(height: 0.0075, radius: 0.0021),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.42, metallic: 0.18)]
        )
        plug.position = point + simd_normalize(delta) * 0.003
        plug.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: simd_normalize(delta))

        let strainRelief = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: 0.0025),
            materials: [unlitMaterial(color.withAlphaComponent(0.95))]
        )
        strainRelief.position = point + simd_normalize(delta) * 0.0065
        strainRelief.orientation = plug.orientation

        let entity = Entity()
        entity.addChild(plug)
        entity.addChild(strainRelief)
        return entity
    }

    private func makeBoardEntity(placement: PhysicalPartPlacement) -> Entity {
        let width = Float(placement.footprint.width) * 0.001
        let depth = Float(placement.footprint.height) * 0.001
        let thickness: Float = 0.004

        let board = ModelEntity(
            mesh: .generateBox(width: width, height: thickness, depth: depth, cornerRadius: 0.003),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.97, alpha: 1), roughness: 0.9, metallic: 0.02)]
        )
        board.name = "body"
        board.position = [0, thickness / 2, 0]

        let headerTrackMaterial = simpleMaterial(NSColor(calibratedWhite: 0.14, alpha: 1), roughness: 0.58, metallic: 0.05)
        let leftHeader = ModelEntity(
            mesh: .generateBox(width: 0.004, height: 0.0045, depth: depth * 0.84, cornerRadius: 0.001),
            materials: [headerTrackMaterial]
        )
        leftHeader.position = [-width * 0.34, thickness + 0.001, 0]

        let rightHeader = ModelEntity(
            mesh: .generateBox(width: 0.004, height: 0.0045, depth: depth * 0.84, cornerRadius: 0.001),
            materials: [headerTrackMaterial]
        )
        rightHeader.position = [width * 0.34, thickness + 0.001, 0]

        let usb = ModelEntity(
            mesh: .generateBox(width: 0.014, height: 0.008, depth: 0.012, cornerRadius: 0.001),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.86, alpha: 1), roughness: 0.28, metallic: 0.44)]
        )
        usb.position = [-width * 0.48, thickness + 0.002, -depth * 0.22]

        let display = ModelEntity(
            mesh: .generateBox(width: width * 0.16, height: 0.0012, depth: depth * 0.16, cornerRadius: 0.001),
            materials: [unlitMaterial(NSColor(calibratedWhite: 0.16, alpha: 1))]
        )
        display.position = [width * 0.18, thickness + 0.0023, -depth * 0.08]

        let accent = ModelEntity(
            mesh: .generateCylinder(height: 0.0024, radius: 0.006),
            materials: [simpleMaterial(NSColor.systemRed, roughness: 0.36, metallic: 0.0)]
        )
        accent.position = [-width * 0.08, thickness + 0.0022, depth * 0.12]

        let entity = Entity()
        entity.addChild(board)
        entity.addChild(leftHeader)
        entity.addChild(rightHeader)
        entity.addChild(usb)
        entity.addChild(display)
        entity.addChild(accent)
        return entity
    }

    private func makeLEDEntity(part: PartDefinition) -> Entity {
        let body = ModelEntity(
            mesh: .generateCylinder(height: 0.012, radius: 0.0045),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.34)]
        )
        body.name = "body"
        body.position = [0, 0.006, 0]

        let bulb = ModelEntity(
            mesh: .generateSphere(radius: 0.0062),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.92, alpha: 1), roughness: 0.18, metallic: 0.0)]
        )
        bulb.name = "bulb"
        bulb.position = [0, 0.014, 0]

        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.0115),
            materials: [unlitMaterial(nsColor(for: part, active: true).withAlphaComponent(0.02))]
        )
        glow.name = "led-glow"
        glow.position = [0, 0.014, 0]
        glow.scale = [0.55, 0.55, 0.55]

        let leftLead = ModelEntity(
            mesh: .generateCylinder(height: 0.014, radius: 0.0008),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.78, alpha: 1), roughness: 0.22, metallic: 0.72)]
        )
        leftLead.position = [-0.002, 0.004, 0]
        let rightLead = ModelEntity(
            mesh: .generateCylinder(height: 0.017, radius: 0.0008),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.78, alpha: 1), roughness: 0.22, metallic: 0.72)]
        )
        rightLead.position = [0.002, 0.0055, 0]

        let entity = Entity()
        entity.addChild(body)
        entity.addChild(glow)
        entity.addChild(bulb)
        entity.addChild(leftLead)
        entity.addChild(rightLead)
        return entity
    }

    private func makeResistorEntity() -> Entity {
        let body = ModelEntity(
            mesh: .generateCylinder(height: 0.014, radius: 0.0034),
            materials: [simpleMaterial(NSColor(calibratedRed: 0.71, green: 0.57, blue: 0.33, alpha: 1), roughness: 0.76)]
        )
        body.name = "body"
        body.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        body.position = [0, 0.0045, 0]

        let leftLead = ModelEntity(
            mesh: .generateCylinder(height: 0.012, radius: 0.0007),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.8, alpha: 1), roughness: 0.24, metallic: 0.7)]
        )
        leftLead.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        leftLead.position = [-0.013, 0.0045, 0]
        let rightLead = leftLead.clone(recursive: true)
        rightLead.position = [0.013, 0.0045, 0]

        let entity = Entity()
        entity.addChild(body)
        entity.addChild(leftLead)
        entity.addChild(rightLead)
        return entity
    }

    private func makeButtonEntity() -> Entity {
        let base = ModelEntity(
            mesh: .generateBox(width: 0.016, height: 0.008, depth: 0.016, cornerRadius: 0.0015),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.72)]
        )
        base.name = "body"
        base.position = [0, 0.004, 0]

        let cap = ModelEntity(
            mesh: .generateCylinder(height: 0.006, radius: 0.0055),
            materials: [simpleMaterial(NSColor.systemGreen, roughness: 0.36)]
        )
        cap.name = "button-cap"
        cap.position = [0, 0.008, 0]

        let entity = Entity()
        entity.addChild(base)
        entity.addChild(cap)
        return entity
    }

    private func makeSpeakerEntity(part: PartDefinition) -> Entity {
        let housing = ModelEntity(
            mesh: .generateCylinder(height: 0.01, radius: 0.016),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.82)]
        )
        housing.name = "body"
        housing.position = [0, 0.005, 0]

        let cone = ModelEntity(
            mesh: .generateCylinder(height: 0.004, radius: part.kind == .buzzer ? 0.010 : 0.012),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.08, alpha: 1), roughness: 0.36)]
        )
        cone.name = "speaker-cone"
        cone.position = [0, 0.009, 0]

        let entity = Entity()
        entity.addChild(housing)
        entity.addChild(cone)
        return entity
    }

    private func makeSevenSegmentEntity() -> Entity {
        let body = ModelEntity(
            mesh: .generateBox(width: 0.022, height: 0.005, depth: 0.040, cornerRadius: 0.002),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.4)]
        )
        body.name = "body"
        body.position = [0, 0.0025, 0]

        let screen = ModelEntity(
            mesh: .generateBox(width: 0.016, height: 0.001, depth: 0.030, cornerRadius: 0.001),
            materials: [unlitMaterial(NSColor.systemRed.withAlphaComponent(0.55))]
        )
        screen.position = [0, 0.0055, 0]

        let entity = Entity()
        entity.addChild(body)
        entity.addChild(screen)
        return entity
    }

    private func makePotentiometerEntity() -> Entity {
        let body = ModelEntity(
            mesh: .generateCylinder(height: 0.013, radius: 0.012),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.14, alpha: 1), roughness: 0.68)]
        )
        body.name = "body"
        body.position = [0, 0.0065, 0]

        let shaft = ModelEntity(
            mesh: .generateCylinder(height: 0.015, radius: 0.003),
            materials: [simpleMaterial(NSColor.systemRed, roughness: 0.22, metallic: 0.12)]
        )
        shaft.position = [0, 0.017, 0]

        let entity = Entity()
        entity.addChild(body)
        entity.addChild(shaft)
        return entity
    }

    private func makeModuleEntity(part: PartDefinition, placement: PhysicalPartPlacement) -> Entity {
        let width = Float(placement.footprint.width) * 0.001
        let depth = Float(placement.footprint.height) * 0.001
        let thickness = max(Float(placement.footprint.depth) * 0.00035, 0.004)

        let board = ModelEntity(
            mesh: .generateBox(width: width, height: thickness, depth: depth, cornerRadius: 0.002),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.98, alpha: 1), roughness: 0.92, metallic: 0.01)]
        )
        board.name = "body"
        board.position = [0, thickness / 2, 0]

        let feature = panelFeatureEntity(for: part, width: width, depth: depth, thickness: thickness)

        let entity = Entity()
        entity.addChild(board)
        entity.addChild(feature)
        return entity
    }

    private func makeLampEntity() -> Entity {
        let stem = ModelEntity(
            mesh: .generateCylinder(height: 0.03, radius: 0.004),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.14, alpha: 1), roughness: 0.44)]
        )
        stem.position = [0, 0.015, 0]

        let bulb = ModelEntity(
            mesh: .generateSphere(radius: 0.017),
            materials: [glowingMaterial(color: NSColor.systemYellow, intensity: 0.08)]
        )
        bulb.name = "bulb"
        bulb.position = [0, 0.04, 0]

        let glow = ModelEntity(
            mesh: .generateSphere(radius: 0.028),
            materials: [unlitMaterial(NSColor.systemYellow.withAlphaComponent(0.05))]
        )
        glow.name = "lamp-glow"
        glow.position = [0, 0.04, 0]
        glow.scale = [0.65, 0.65, 0.65]

        let entity = Entity()
        entity.addChild(stem)
        entity.addChild(glow)
        entity.addChild(bulb)
        return entity
    }

    private func makeMotorEntity() -> Entity {
        let housing = ModelEntity(
            mesh: .generateCylinder(height: 0.04, radius: 0.014),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.16, alpha: 1), roughness: 0.38, metallic: 0.55)]
        )
        housing.name = "body"
        housing.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        housing.position = [0, 0.014, 0]

        let shaft = ModelEntity(
            mesh: .generateCylinder(height: 0.018, radius: 0.0036),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.88, alpha: 1), roughness: 0.22, metallic: 0.82)]
        )
        shaft.name = "motor-shaft"
        shaft.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        shaft.position = [0.022, 0.014, 0]

        let entity = Entity()
        entity.addChild(housing)
        entity.addChild(shaft)
        return entity
    }

    private func makeServoEntity() -> Entity {
        let body = ModelEntity(
            mesh: .generateBox(width: 0.026, height: 0.034, depth: 0.018, cornerRadius: 0.002),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.65)]
        )
        body.name = "body"
        body.position = [0, 0.017, 0]

        let armPivot = Entity()
        armPivot.position = [0, 0.036, 0]
        armPivot.name = "servo-arm"

        let arm = ModelEntity(
            mesh: .generateBox(width: 0.034, height: 0.0035, depth: 0.005, cornerRadius: 0.001),
            materials: [simpleMaterial(NSColor.white, roughness: 0.4)]
        )
        arm.position = [0.017, 0, 0]
        armPivot.addChild(arm)

        let gripperBase = Entity()
        gripperBase.position = [0.034, 0, 0]

        let leftFinger = ModelEntity(
            mesh: .generateBox(width: 0.004, height: 0.024, depth: 0.004, cornerRadius: 0.001),
            materials: [simpleMaterial(NSColor.systemRed, roughness: 0.65)]
        )
        leftFinger.name = "left-finger"
        leftFinger.position = [0.006, -0.010, 0]

        let rightFinger = ModelEntity(
            mesh: .generateBox(width: 0.004, height: 0.024, depth: 0.004, cornerRadius: 0.001),
            materials: [simpleMaterial(NSColor.systemRed, roughness: 0.65)]
        )
        rightFinger.name = "right-finger"
        rightFinger.position = [0.006, 0.010, 0]

        gripperBase.addChild(leftFinger)
        gripperBase.addChild(rightFinger)
        armPivot.addChild(gripperBase)

        let entity = Entity()
        entity.addChild(body)
        entity.addChild(armPivot)
        return entity
    }

    private func worldPosition(for placement: PhysicalPartPlacement, partKind: PartKind, enclosure: PhysicalEnclosure) -> SIMD3<Float> {
        let normalized = resolvedWorkbenchPosition(
            placement.position,
            footprint: placement.footprint,
            partKind: partKind,
            boardCenter: enclosure.center
        )
        let x = Float(normalized.x - enclosure.center.x) * 0.001
        let z = Float(normalized.y - enclosure.center.y) * 0.001
        let standoff = Float(placement.standoffHeight) * 0.001
        let halfHeight = Float(placement.footprint.depth) * 0.0005
        let faceOffset: Float = placement.face == .internal ? 0 : 0.004
        return [x, standoff + halfHeight + faceOffset, z]
    }

    private func resolvedWorkbenchPosition(
        _ position: CanvasPoint,
        footprint: PhysicalFootprint,
        partKind: PartKind,
        boardCenter: CanvasPoint
    ) -> CanvasPoint {
        return normalizedBreadboardPosition(
            position,
            footprint: footprint,
            partKind: partKind,
            boardCenter: boardCenter
        )
    }

    private func normalizedBreadboardPosition(
        _ position: CanvasPoint,
        footprint: PhysicalFootprint,
        partKind: PartKind,
        boardCenter: CanvasPoint
    ) -> CanvasPoint {
        let minX = boardCenter.x - (breadboardSurfaceWidthMm / 2) + (footprint.width / 2)
        let maxX = boardCenter.x + (breadboardSurfaceWidthMm / 2) - (footprint.width / 2)
        let minY = boardCenter.y - (breadboardSurfaceHeightMm / 2) + (footprint.height / 2)
        let maxY = boardCenter.y + (breadboardSurfaceHeightMm / 2) - (footprint.height / 2)

        let xCandidates = breadboardColumnCenters(centerX: boardCenter.x).filter { $0 >= minX && $0 <= maxX }
        let yCandidates = breadboardRowCenters(centerY: boardCenter.y, partKind: partKind, footprintHeight: footprint.height)
            .filter { $0 >= minY && $0 <= maxY }

        return CanvasPoint(
            x: nearestCandidate(to: position.x, candidates: xCandidates) ?? position.x.clamped(to: minX...maxX),
            y: nearestCandidate(to: position.y, candidates: yCandidates) ?? position.y.clamped(to: minY...maxY)
        )
    }

    private func breadboardColumnCenters(centerX: Double) -> [Double] {
        let usableWidth = breadboardSurfaceWidthMm * 0.82
        let count = max(20, Int((usableWidth / breadboardPitchMm).rounded()))
        let span = Double(max(count - 1, 1)) * breadboardPitchMm
        let start = centerX - span / 2
        return (0..<count).map { start + Double($0) * breadboardPitchMm }
    }

    private func breadboardRowCenters(centerY: Double, partKind: PartKind, footprintHeight: Double) -> [Double] {
        if partKind == .board {
            let minY = centerY - (breadboardSurfaceHeightMm / 2) + (footprintHeight / 2)
            let maxY = centerY + (breadboardSurfaceHeightMm / 2) - (footprintHeight / 2)
            return stride(from: minY, through: maxY, by: breadboardPitchMm).map { $0 }
        }

        if footprintHeight > 32 || partKind == .servo || partKind == .motor || partKind == .rgbLamp {
            let laneOffset = footprintHeight <= 42 ? breadboardRailRowOffsetsMm[2] : 0
            return [centerY + laneOffset]
        }

        let terminalRows = breadboardTerminalRowOffsetsMm.map { centerY + $0 }
        switch partKind {
        case .led, .button, .resistor, .buzzer, .speaker, .potentiometer:
            return terminalRows
        default:
            return terminalRows + breadboardRailRowOffsetsMm.map { centerY + $0 }
        }
    }

    private func nearestCandidate(to value: Double, candidates: [Double]) -> Double? {
        candidates.min { abs($0 - value) < abs($1 - value) }
    }

    private func partMaterial(for part: PartDefinition, isActive: Bool, selected: Bool) -> any RealityKit.Material {
        let baseColor: NSColor
        switch part.kind {
        case .shiftRegister, .motorDriver:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        case .soilSensor, .lightSensor, .climateSensor, .lineSensor:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        case .oledDisplay:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        case .relay:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        case .microphone:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        case .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        default:
            baseColor = NSColor(calibratedWhite: 0.96, alpha: 1)
        }

        let tint = selected ? NSColor.systemBlue.blended(withFraction: 0.05, of: baseColor) ?? baseColor : baseColor
        return simpleMaterial(tint, roughness: isActive ? 0.26 : 0.9, metallic: 0.02)
    }

    private func nsColor(for part: PartDefinition, active: Bool) -> NSColor {
        let base: NSColor
        switch part.attributes["color"]?.lowercased() {
        case "red":
            base = .systemRed
        case "green":
            base = .systemGreen
        case "blue":
            base = .systemBlue
        case "amber", "yellow":
            base = .systemYellow
        default:
            base = .systemOrange
        }
        return active ? base : base.withAlphaComponent(0.35)
    }

    private func pinScenePosition(for reference: PinReference, project: RobotProject, transientPartPositions: [String: CanvasPoint]) -> SIMD3<Float>? {
        guard
            let part = project.parts.first(where: { $0.id == reference.partID }),
            let placement = project.physical.placement(for: reference.partID),
            let local = localPinPosition(for: reference.pin, part: part, placement: placement)
        else {
            return nil
        }

        let effectivePlacement = effectivePlacement(placement, partID: reference.partID, transientPartPositions: transientPartPositions)
        let rotation = simd_quatf(angle: Float(placement.rotationDegrees) * (.pi / 180), axis: [0, 1, 0])
        return worldPosition(for: effectivePlacement, partKind: part.kind, enclosure: project.physical.enclosure) + rotation.act(local)
    }

    private func effectivePlacement(
        _ placement: PhysicalPartPlacement,
        partID: String,
        transientPartPositions: [String: CanvasPoint]
    ) -> PhysicalPartPlacement {
        guard let transientPosition = transientPartPositions[partID] else { return placement }
        var updatedPlacement = placement
        updatedPlacement.position = transientPosition
        return updatedPlacement
    }

    private func localPinPosition(for pin: String, part: PartDefinition, placement: PhysicalPartPlacement) -> SIMD3<Float>? {
        let width = Float(placement.footprint.width) * 0.001
        let depth = Float(placement.footprint.height) * 0.001
        let topY = max(Float(placement.footprint.depth) * 0.001 * 0.55, 0.007)

        switch part.kind {
        case .board:
            return edgePinPosition(
                pin: pin,
                leadingPins: ["D13", "D12", "D11", "D10", "D9", "D8", "D7", "D6", "D5", "D4", "D3", "D2"],
                trailingPins: ["A0", "A1", "A2", "A3", "A4", "A5", "5V", "GND"],
                width: width,
                depth: depth,
                y: topY
            )
        case .led:
            return discretePinPosition(pin: pin, positions: ["A": [-0.003, 0.006, -0.002], "K": [0.003, 0.006, 0.002]])
        case .resistor:
            return discretePinPosition(pin: pin, positions: ["1": [-0.015, 0.0045, 0], "2": [0.015, 0.0045, 0]])
        case .button:
            return discretePinPosition(pin: pin, positions: ["1": [-0.008, 0.004, -0.005], "2": [-0.008, 0.004, 0.005], "3": [0.008, 0.004, -0.005], "4": [0.008, 0.004, 0.005]])
        case .buzzer:
            return discretePinPosition(pin: pin, positions: ["+": [-0.010, 0.005, -0.004], "-": [0.010, 0.005, 0.004]])
        case .sevenSegment:
            return discretePinPosition(
                pin: pin,
                positions: [
                    "A": [-0.012, 0.004, -0.015], "F": [-0.012, 0.004, -0.007], "G": [-0.012, 0.004, 0],
                    "E": [-0.012, 0.004, 0.007], "COM": [-0.012, 0.004, 0.015], "B": [0.012, 0.004, -0.015],
                    "C": [0.012, 0.004, -0.004], "D": [0.012, 0.004, 0.007], "DP": [0.012, 0.004, 0.015]
                ]
            )
        case .potentiometer:
            return discretePinPosition(pin: pin, positions: ["1": [-0.010, 0.006, 0.010], "2": [0, 0.006, -0.012], "3": [0.010, 0.006, 0.010]])
        case .shiftRegister:
            return edgePinPosition(
                pin: pin,
                leadingPins: ["DS", "SH_CP", "ST_CP", "OE", "MR", "VCC"],
                trailingPins: ["Q0", "Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7", "GND"],
                width: width,
                depth: depth,
                y: topY
            )
        case .soilSensor, .lightSensor, .microphone, .lineSensor, .digitalSensorModule:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: ["OUT"], leftSidePins: ["VCC", "GND"])
        case .analogSensorModule:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: ["AOUT", "DOUT"], leftSidePins: ["VCC", "GND"])
        case .climateSensor:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: ["DATA"], leftSidePins: ["VCC", "GND"])
        case .relay:
            return relayPinPosition(pin: pin, width: width, depth: depth, y: topY)
        case .oledDisplay, .i2cSensorModule:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: ["VCC", "GND"], leftSidePins: ["SDA", "SCL"])
        case .speaker:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: [], leftSidePins: ["SIG", "GND"])
        case .rgbLamp:
            return discretePinPosition(pin: pin, positions: ["R": [-0.010, 0.006, -0.010], "G": [-0.010, 0.006, 0], "B": [-0.010, 0.006, 0.010], "GND": [0.010, 0.006, 0]])
        case .motorDriver:
            return edgePinPosition(
                pin: pin,
                leadingPins: ["ENA", "IN1", "IN2", "ENB", "IN3", "IN4", "VM"],
                trailingPins: ["L+", "L-", "R+", "R-", "GND"],
                width: width,
                depth: depth,
                y: topY
            )
        case .motor:
            return discretePinPosition(pin: pin, positions: ["+": [-0.020, 0.014, -0.006], "-": [-0.020, 0.014, 0.006]])
        case .servo:
            return discretePinPosition(pin: pin, positions: ["SIG": [-0.013, 0.008, -0.006], "VCC": [-0.013, 0.008, 0], "GND": [-0.013, 0.008, 0.006]])
        case .uartSensorModule, .visionSensorModule:
            return moduleSidePinPosition(pin: pin, depth: depth, y: topY, rightSidePins: ["TX", "RX"], leftSidePins: ["VCC", "GND"])
        case .distanceSensorModule:
            return discretePinPosition(pin: pin, positions: ["TRIG": [-0.015, 0.006, -0.008], "ECHO": [0.015, 0.006, -0.008], "VCC": [-0.015, 0.006, 0.008], "GND": [0.015, 0.006, 0.008]])
        }
    }

    private func edgePinPosition(
        pin: String,
        leadingPins: [String],
        trailingPins: [String],
        width: Float,
        depth: Float,
        y: Float
    ) -> SIMD3<Float>? {
        if let index = leadingPins.firstIndex(of: pin) {
            return spacedEdgePosition(index: index, count: leadingPins.count, width: width, z: -depth / 2 - 0.0015, y: y)
        }

        if let index = trailingPins.firstIndex(of: pin) {
            return spacedEdgePosition(index: index, count: trailingPins.count, width: width, z: depth / 2 + 0.0015, y: y)
        }

        return nil
    }

    private func spacedEdgePosition(index: Int, count: Int, width: Float, z: Float, y: Float) -> SIMD3<Float> {
        let step = width / Float(count + 1)
        let x = -width / 2 + step * Float(index + 1)
        return [x, y, z]
    }

    private func moduleSidePinPosition(
        pin: String,
        depth: Float,
        y: Float,
        rightSidePins: [String],
        leftSidePins: [String]
    ) -> SIMD3<Float>? {
        if let index = rightSidePins.firstIndex(of: pin) {
            return spacedSidePosition(index: index, count: rightSidePins.count, x: 0.026, depth: depth, y: y)
        }

        if let index = leftSidePins.firstIndex(of: pin) {
            return spacedSidePosition(index: index, count: leftSidePins.count, x: -0.026, depth: depth, y: y)
        }

        return nil
    }

    private func relayPinPosition(pin: String, width: Float, depth: Float, y: Float) -> SIMD3<Float>? {
        if let position = moduleSidePinPosition(pin: pin, depth: depth, y: y, rightSidePins: ["NO", "COM"], leftSidePins: ["IN", "VCC", "GND"]) {
            return position
        }
        return nil
    }

    private func spacedSidePosition(index: Int, count: Int, x: Float, depth: Float, y: Float) -> SIMD3<Float> {
        if count == 1 {
            return [x, y, 0]
        }

        let step = depth / Float(count + 1)
        let z = -depth / 2 + step * Float(index + 1)
        return [x, y, z]
    }

    private func discretePinPosition(pin: String, positions: [String: SIMD3<Float>]) -> SIMD3<Float>? {
        positions[pin]
    }

    private func updateWireAppearance(_ entity: Entity, colorName: String, selected: Bool, pending: Bool) {
        let color = wireColor(named: colorName)
        let visibleColor: NSColor
        if selected {
            visibleColor = NSColor.systemBlue.blended(withFraction: 0.25, of: color) ?? color
        } else if pending {
            visibleColor = NSColor.systemOrange.blended(withFraction: 0.4, of: color) ?? color
        } else {
            visibleColor = color.withAlphaComponent(0.88)
        }

        for child in entity.children {
            if let model = child as? ModelEntity {
                model.model?.materials = [unlitMaterial(visibleColor)]
            }
        }
    }

    private func pinMarkerColor(for pin: String, emphasized: Bool, pending: Bool) -> NSColor {
        if pending {
            return NSColor.systemOrange.withAlphaComponent(0.95)
        }

        let uppercased = pin.uppercased()
        let base: NSColor
        if uppercased == "GND" || uppercased == "-" {
            base = NSColor(calibratedWhite: 0.12, alpha: 1)
        } else if uppercased == "VCC" || uppercased == "5V" || uppercased == "+" || uppercased == "VM" {
            base = .systemRed
        } else if uppercased == "SDA" || uppercased == "SCL" {
            base = .systemCyan
        } else {
            base = .systemYellow
        }
        return base.withAlphaComponent(emphasized ? 0.94 : 0.6)
    }

    private func makePanelBase(placement: PhysicalPartPlacement) -> Entity {
        let width = Float(placement.footprint.width) * 0.001
        let depth = Float(placement.footprint.height) * 0.001
        let panel = ModelEntity(
            mesh: .generateBox(width: width, height: 0.0032, depth: depth, cornerRadius: 0.0035),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.985, alpha: 1), roughness: 0.94, metallic: 0.01)]
        )
        panel.name = "panel-base"
        panel.position = [0, 0.0014, 0]

        let trim = ModelEntity(
            mesh: .generateBox(width: width * 0.965, height: 0.001, depth: depth * 0.965, cornerRadius: 0.003),
            materials: [unlitMaterial(NSColor(calibratedWhite: 0.86, alpha: 0.7))]
        )
        trim.position = [0, 0.0032, 0]

        let entity = Entity()
        entity.addChild(panel)
        entity.addChild(trim)

        let screwRadius = min(width, depth) * 0.05
        for x in [-1.0 as Float, 1.0] {
            for z in [-1.0 as Float, 1.0] {
                let screw = ModelEntity(
                    mesh: .generateCylinder(height: 0.0022, radius: screwRadius),
                    materials: [simpleMaterial(NSColor(calibratedWhite: 0.16, alpha: 1), roughness: 0.44, metallic: 0.18)]
                )
                screw.position = [x * (width * 0.42), 0.003, z * (depth * 0.42)]
                entity.addChild(screw)
            }
        }

        return entity
    }

    private func panelFeatureEntity(for part: PartDefinition, width: Float, depth: Float, thickness: Float) -> Entity {
        let entity = Entity()

        switch part.kind {
        case .oledDisplay:
            let screen = ModelEntity(
                mesh: .generateBox(width: width * 0.6, height: 0.002, depth: depth * 0.38, cornerRadius: 0.002),
                materials: [unlitMaterial(NSColor(calibratedWhite: 0.12, alpha: 1))]
            )
            screen.position = [0, thickness + 0.0022, 0]
            entity.addChild(screen)
        case .relay:
            let block = ModelEntity(
                mesh: .generateBox(width: width * 0.44, height: 0.008, depth: depth * 0.32, cornerRadius: 0.002),
                materials: [simpleMaterial(NSColor(calibratedRed: 0.23, green: 0.40, blue: 0.82, alpha: 1), roughness: 0.28, metallic: 0.04)]
            )
            block.position = [0, thickness + 0.004, 0]
            entity.addChild(block)
        case .soilSensor, .lightSensor, .climateSensor, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule, .lineSensor, .microphone:
            for index in 0..<3 {
                let led = ModelEntity(
                    mesh: .generateCylinder(height: 0.0022, radius: 0.003),
                    materials: [simpleMaterial(index == 0 ? .systemGreen : (index == 1 ? .systemYellow : .systemRed), roughness: 0.28)]
                )
                led.position = [-width * 0.16 + Float(index) * (width * 0.16), thickness + 0.002, depth * 0.18]
                entity.addChild(led)
            }
            let slot = ModelEntity(
                mesh: .generateBox(width: width * 0.18, height: 0.005, depth: depth * 0.34, cornerRadius: 0.001),
                materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.44)]
            )
            slot.position = [width * 0.18, thickness + 0.003, 0]
            entity.addChild(slot)
        case .shiftRegister, .motorDriver:
            for index in 0..<4 {
                let knob = ModelEntity(
                    mesh: .generateCylinder(height: 0.006, radius: 0.0065),
                    materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.48)]
                )
                knob.position = [-width * 0.24 + Float(index) * (width * 0.16), thickness + 0.003, 0]
                entity.addChild(knob)
            }
        default:
            let feature = ModelEntity(
                mesh: .generateBox(width: width * 0.22, height: thickness * 1.4, depth: depth * 0.16, cornerRadius: 0.001),
                materials: [simpleMaterial(NSColor(calibratedWhite: 0.12, alpha: 1), roughness: 0.38)]
            )
            feature.position = [0, thickness + 0.0022, 0]
            entity.addChild(feature)
        }

        return entity
    }

    private func makePinJackEntity(color: NSColor) -> ModelEntity {
        let jack = ModelEntity(
            mesh: .generateCylinder(height: 0.0022, radius: 0.0032),
            materials: [simpleMaterial(NSColor(calibratedWhite: 0.08, alpha: 1), roughness: 0.52, metallic: 0.12)]
        )
        jack.position = [0, 0.0012, 0]

        let insert = ModelEntity(
            mesh: .generateCylinder(height: 0.0011, radius: 0.0011),
            materials: [unlitMaterial(color.withAlphaComponent(0.04))]
        )
        insert.name = "jack-insert"
        insert.position = [0, 0.0024, 0]
        jack.addChild(insert)
        return jack
    }

    private func sampledCablePath(
        from start: SIMD3<Float>,
        control1: SIMD3<Float>,
        control2: SIMD3<Float>,
        to end: SIMD3<Float>,
        steps: Int
    ) -> [SIMD3<Float>] {
        let count = max(steps, 2)
        return (0...count).map { index in
            let t = Float(index) / Float(count)
            let inv = 1 - t
            return (inv * inv * inv * start)
                + (3 * inv * inv * t * control1)
                + (3 * inv * t * t * control2)
                + (t * t * t * end)
        }
    }

    private func wireColor(named name: String) -> NSColor {
        switch name.lowercased() {
        case "black":
            return NSColor(calibratedWhite: 0.10, alpha: 1)
        case "green":
            return NSColor(calibratedRed: 0.18, green: 0.58, blue: 0.28, alpha: 1)
        case "red":
            return NSColor(calibratedRed: 0.85, green: 0.44, blue: 0.42, alpha: 1)
        case "blue":
            return NSColor(calibratedRed: 0.44, green: 0.68, blue: 0.84, alpha: 1)
        case "yellow":
            return NSColor(calibratedRed: 0.86, green: 0.74, blue: 0.32, alpha: 1)
        default:
            return NSColor(calibratedWhite: 0.42, alpha: 1)
        }
    }

    private func enableInteraction(on entity: Entity) {
        entity.components.set(InputTargetComponent())
        entity.generateCollisionShapes(recursive: true)
    }
}

@available(macOS 15.0, *)
private func simpleMaterial(_ color: NSColor, roughness: Float = 0.65, metallic: Float = 0.04) -> any RealityKit.Material {
    var material = SimpleMaterial()
    var baseColor = material.color
    baseColor.__tint = color.cgColor
    material.color = baseColor
    material.roughness = .init(floatLiteral: roughness)
    material.metallic = .init(floatLiteral: metallic)
    return material
}

@available(macOS 15.0, *)
private func glowingMaterial(color: NSColor, intensity: Float) -> any RealityKit.Material {
    var material = PhysicallyBasedMaterial()
    var baseColor = material.baseColor
    baseColor.__tint = color.withAlphaComponent(0.98).cgColor
    material.baseColor = baseColor
    var emissive = material.emissiveColor
    emissive.__color = color.cgColor
    material.emissiveColor = emissive
    material.emissiveIntensity = intensity
    material.roughness = .init(floatLiteral: 0.18)
    material.metallic = .init(floatLiteral: 0.0)
    return material
}

@available(macOS 15.0, *)
private func unlitMaterial(_ color: NSColor) -> any RealityKit.Material {
    var material = UnlitMaterial()
    var baseColor = material.color
    baseColor.__tint = color.cgColor
    material.color = baseColor
    return material
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

private struct WorkbenchPinKey: Hashable {
    let partID: String
    let pin: String
}

private struct WorkbenchPartDragSession {
    let partID: String
    let startPosition: CanvasPoint
}

@available(macOS 15.0, *)
private enum WorkbenchTapTarget {
    case part(String)
    case wire(String)
    case pin(PinReference)

    init?(from entity: Entity) {
        var current: Entity? = entity
        while let currentEntity = current {
            if let reference = Self.pinReference(from: currentEntity.name) {
                self = .pin(reference)
                return
            }

            if let wireID = Self.wireID(from: currentEntity.name) {
                self = .wire(wireID)
                return
            }

            if let partID = Self.partID(from: currentEntity.name) {
                self = .part(partID)
                return
            }

            current = currentEntity.parent
        }

        return nil
    }

    private static func partID(from name: String) -> String? {
        guard name.hasPrefix("part|") else { return nil }
        return String(name.dropFirst(5))
    }

    private static func wireID(from name: String) -> String? {
        guard name.hasPrefix("wire|") else { return nil }
        return String(name.dropFirst(5))
    }

    private static func pinReference(from name: String) -> PinReference? {
        guard name.hasPrefix("pin|") else { return nil }
        let components = String(name.dropFirst(4)).split(separator: "|", maxSplits: 1).map(String.init)
        guard components.count == 2 else { return nil }
        return PinReference(partID: components[0], pin: components[1])
    }
}

private func partEntityName(for partID: String) -> String {
    "part|\(partID)"
}

private func wireEntityName(for wireID: String) -> String {
    "wire|\(wireID)"
}

private func pinEntityName(for partID: String, pin: String) -> String {
    "pin|\(partID)|\(pin)"
}
