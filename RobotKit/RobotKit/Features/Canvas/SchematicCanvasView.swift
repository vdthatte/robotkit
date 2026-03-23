import AppKit
import SwiftUI

struct SchematicCanvasView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            SchematicEditorRepresentable(
                project: projectStore.project,
                selectedPartID: $projectStore.selectedPartID,
                selectedWireID: $projectStore.selectedWireID,
                pinStates: simulator.pinStates,
                pendingPlacementKind: projectStore.pendingPlacementKind,
                pendingPlacementEntry: projectStore.pendingPlacementEntry,
                placementPreviewPoint: projectStore.placementPreviewPoint,
                activeButtonIDs: projectStore.activeButtonIDs,
                zoom: projectStore.canvasZoom,
                offset: projectStore.canvasOffset,
                onBackgroundActivate: { point in
                    projectStore.handleCanvasBackgroundActivation(at: point)
                },
                onPartActivate: { partID in
                    projectStore.handleCanvasPartActivation(partID)
                },
                onWireActivate: { wireID in
                    projectStore.handleCanvasWireActivation(wireID)
                },
                onPinSelect: { pin in
                    projectStore.selectPart(id: pin.partID)
                },
                onWireCreate: { start, end in
                    projectStore.createWire(from: start, to: end)
                },
                onPartMove: { partID, position in
                    projectStore.movePart(id: partID, to: position)
                },
                onWireMidXMove: { wireID, midX in
                    projectStore.updateWireMidX(wireID, to: midX)
                },
                onDeleteSelection: {
                    projectStore.deleteSelection()
                },
                onDuplicateSelection: {
                    projectStore.duplicateSelection()
                },
                onButtonPress: { partID, isPressed in
                    projectStore.setButtonPressed(partID, isPressed: isPressed)
                    guard simulator.isBootstrapped else { return }
                    do {
                        try simulator.synchronizeInputs(
                            project: projectStore.project,
                            activeButtons: projectStore.activeButtonIDs
                        )
                    } catch {
                        NSLog("RobotKit input sync failed: %@", error.localizedDescription)
                    }
                },
                onPlacementPreview: { point in
                    projectStore.updatePlacementPreview(point)
                },
                onCancelPlacement: {
                    projectStore.cancelPlacement()
                },
                onViewportChange: { zoom, offset in
                    projectStore.setCanvasViewport(zoom: zoom, offset: offset)
                },
                onDropPartKind: { kind, point in
                    projectStore.addPart(kind: kind, at: point)
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(projectStore.project.name)
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)
                Text("Dark canvas with pan, zoom, drag placement, hover pins, and schematic editing.")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.78))
                HStack(spacing: 12) {
                    Text("Observed pins: \(projectStore.project.demo.observedPins.joined(separator: ", "))")
                    Text("Zoom \(Int(projectStore.canvasZoom * 100))%")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))

                if let pendingPlacementEntry = projectStore.pendingPlacementEntry {
                    Text("Placement mode: click or drop on the canvas to place \(pendingPlacementEntry.displayName). Press Esc to cancel.")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                } else {
                    Text("Drag from pin to pin to create wires, drag parts to move, Option-drag to pan, and press Delete to remove a selection.")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SchematicEditorRepresentable: NSViewRepresentable {
    let project: RobotProject
    @Binding var selectedPartID: String?
    @Binding var selectedWireID: String?
    let pinStates: [String: Int]
    let pendingPlacementKind: PartKind?
    let pendingPlacementEntry: PartCatalogEntry?
    let placementPreviewPoint: CanvasPoint?
    let activeButtonIDs: Set<String>
    let zoom: Double
    let offset: CanvasPoint
    let onBackgroundActivate: (CanvasPoint?) -> Void
    let onPartActivate: (String?) -> Void
    let onWireActivate: (String?) -> Void
    let onPinSelect: (PinReference) -> Void
    let onWireCreate: (PinReference, PinReference) -> Void
    let onPartMove: (String, CanvasPoint) -> Void
    let onWireMidXMove: (String, Double) -> Void
    let onDeleteSelection: () -> Void
    let onDuplicateSelection: () -> Void
    let onButtonPress: (String, Bool) -> Void
    let onPlacementPreview: (CanvasPoint?) -> Void
    let onCancelPlacement: () -> Void
    let onViewportChange: (Double, CanvasPoint) -> Void
    let onDropPartKind: (PartKind, CanvasPoint) -> Void

    func makeNSView(context: Context) -> SchematicEditorNSView {
        let view = SchematicEditorNSView()
        view.onSelectionChange = { selectedPartID, selectedWireID in
            self.selectedPartID = selectedPartID
            self.selectedWireID = selectedWireID
        }
        return view
    }

    func updateNSView(_ nsView: SchematicEditorNSView, context: Context) {
        nsView.project = project
        nsView.selectedPartID = selectedPartID
        nsView.selectedWireID = selectedWireID
        nsView.pinStates = pinStates
        nsView.pendingPlacementKind = pendingPlacementKind
        nsView.pendingPlacementEntry = pendingPlacementEntry
        nsView.placementPreviewPoint = placementPreviewPoint
        nsView.activeButtonIDs = activeButtonIDs
        nsView.zoom = CGFloat(zoom)
        nsView.offset = CGPoint(x: offset.x, y: offset.y)
        nsView.onSelectionChange = { selectedPartID, selectedWireID in
            self.selectedPartID = selectedPartID
            self.selectedWireID = selectedWireID
        }
        nsView.onBackgroundActivate = onBackgroundActivate
        nsView.onPartActivate = onPartActivate
        nsView.onWireActivate = onWireActivate
        nsView.onPinSelect = onPinSelect
        nsView.onWireCreate = onWireCreate
        nsView.onPartMove = onPartMove
        nsView.onWireMidXMove = onWireMidXMove
        nsView.onDeleteSelection = onDeleteSelection
        nsView.onDuplicateSelection = onDuplicateSelection
        nsView.onButtonPress = onButtonPress
        nsView.onPlacementPreview = onPlacementPreview
        nsView.onCancelPlacement = onCancelPlacement
        nsView.onViewportChange = onViewportChange
        nsView.onDropPartKind = onDropPartKind
        nsView.needsDisplay = true
    }
}

private final class SchematicEditorNSView: NSView {
    var project: RobotProject = .starter
    var selectedPartID: String?
    var selectedWireID: String?
    var pinStates: [String: Int] = [:]
    var pendingPlacementKind: PartKind?
    var pendingPlacementEntry: PartCatalogEntry?
    var placementPreviewPoint: CanvasPoint?
    var activeButtonIDs: Set<String> = []
    var zoom: CGFloat = 1.0
    var offset = CGPoint.zero
    var onSelectionChange: ((String?, String?) -> Void)?
    var onBackgroundActivate: ((CanvasPoint?) -> Void)?
    var onPartActivate: ((String?) -> Void)?
    var onWireActivate: ((String?) -> Void)?
    var onPinSelect: ((PinReference) -> Void)?
    var onWireCreate: ((PinReference, PinReference) -> Void)?
    var onPartMove: ((String, CanvasPoint) -> Void)?
    var onWireMidXMove: ((String, Double) -> Void)?
    var onDeleteSelection: (() -> Void)?
    var onDuplicateSelection: (() -> Void)?
    var onButtonPress: ((String, Bool) -> Void)?
    var onPlacementPreview: ((CanvasPoint?) -> Void)?
    var onCancelPlacement: (() -> Void)?
    var onViewportChange: ((Double, CanvasPoint) -> Void)?
    var onDropPartKind: ((PartKind, CanvasPoint) -> Void)?

    private var draggingPartID: String?
    private var draggingWireID: String?
    private var draggingWireStartPin: PinReference?
    private var draggingWireEndViewPoint: CGPoint?
    private var pressedButtonID: String?
    private var hoveringPin: PinReference?
    private var hoveringWireID: String?
    private var dragOffset = CGPoint.zero
    private var trackingAreaRef: NSTrackingArea?
    private var panningStartViewPoint: CGPoint?
    private var panningStartOffset = CGPoint.zero
    private var marqueeStartCanvasPoint: CGPoint?
    private var marqueeRectCanvas: CGRect?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.string])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.string])
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingAreaRef = NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingAreaRef)
        self.trackingAreaRef = trackingAreaRef
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        drawBackground(in: dirtyRect)
        drawGrid(in: dirtyRect)
        drawWires()
        drawTransientWire()
        drawPlacementPreview()
        drawParts()
        drawMarqueeSelection()
    }

    override func mouseMoved(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = canvasPoint(fromView: viewPoint)
        hoveringPin = pinReference(atViewPoint: viewPoint)
        hoveringWireID = wireID(atViewPoint: viewPoint)

        if pendingPlacementKind != nil {
            let snapped = snap(canvasPoint)
            onPlacementPreview?(CanvasPoint(x: snapped.x, y: snapped.y))
        } else {
            onPlacementPreview?(nil)
        }
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = canvasPoint(fromView: viewPoint)
        let snapped = snap(canvasPoint)

        if event.modifierFlags.contains(.option) {
            panningStartViewPoint = viewPoint
            panningStartOffset = offset
            return
        }

        if pendingPlacementKind != nil {
            onBackgroundActivate?(CanvasPoint(x: snapped.x, y: snapped.y))
            needsDisplay = true
            return
        }

        if let wireHandle = selectedWireHandle(atViewPoint: viewPoint) {
            draggingWireID = wireHandle
            needsDisplay = true
            return
        }

        if let pinReference = pinReference(atViewPoint: viewPoint) {
            selectedPartID = pinReference.partID
            selectedWireID = nil
            onSelectionChange?(pinReference.partID, nil)
            onPinSelect?(pinReference)
            draggingWireStartPin = pinReference
            draggingWireEndViewPoint = viewPoint
            needsDisplay = true
            return
        }

        if let wireID = wireID(atViewPoint: viewPoint) {
            selectedWireID = wireID
            selectedPartID = nil
            onSelectionChange?(nil, wireID)
            onWireActivate?(wireID)
            needsDisplay = true
            return
        }

        let hitPartID = project.parts.first(where: { partRect(for: $0).contains(canvasPoint) })?.id
        selectedPartID = hitPartID
        selectedWireID = nil
        onSelectionChange?(hitPartID, nil)
        onPartActivate?(hitPartID)

        if let hitPart = project.parts.first(where: { $0.id == hitPartID }) {
            if hitPart.kind == .button {
                onButtonPress?(hitPart.id, true)
                pressedButtonID = hitPart.id
            } else {
                draggingPartID = hitPart.id
                dragOffset = CGPoint(x: canvasPoint.x - hitPart.position.x, y: canvasPoint.y - hitPart.position.y)
            }
        } else {
            if event.modifierFlags.contains(.shift) {
                marqueeStartCanvasPoint = canvasPoint
                marqueeRectCanvas = CGRect(origin: canvasPoint, size: .zero)
            } else {
                onBackgroundActivate?(nil)
            }
        }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let viewPoint = convert(event.locationInWindow, from: nil)
        let canvasPoint = canvasPoint(fromView: viewPoint)

        if let panningStartViewPoint {
            let dx = viewPoint.x - panningStartViewPoint.x
            let dy = viewPoint.y - panningStartViewPoint.y
            offset = CGPoint(x: panningStartOffset.x + dx, y: panningStartOffset.y + dy)
            onViewportChange?(Double(zoom), CanvasPoint(x: offset.x, y: offset.y))
            needsDisplay = true
            return
        }

        if let marqueeStartCanvasPoint {
            marqueeRectCanvas = CGRect(
                x: min(marqueeStartCanvasPoint.x, canvasPoint.x),
                y: min(marqueeStartCanvasPoint.y, canvasPoint.y),
                width: abs(canvasPoint.x - marqueeStartCanvasPoint.x),
                height: abs(canvasPoint.y - marqueeStartCanvasPoint.y)
            )
            needsDisplay = true
            return
        }

        if let draggingWireID {
            let snapped = snap(canvasPoint)
            onWireMidXMove?(draggingWireID, snapped.x)
            return
        }

        if draggingWireStartPin != nil {
            draggingWireEndViewPoint = viewPoint
            needsDisplay = true
            return
        }

        guard let draggingPartID else { return }
        let snapped = snap(CGPoint(x: canvasPoint.x - dragOffset.x, y: canvasPoint.y - dragOffset.y))
        onPartMove?(draggingPartID, CanvasPoint(x: snapped.x, y: snapped.y))
    }

    override func mouseUp(with event: NSEvent) {
        if let pressedButtonID {
            onButtonPress?(pressedButtonID, false)
        }

        if let draggingWireStartPin {
            let viewPoint = convert(event.locationInWindow, from: nil)
            if let destination = pinReference(atViewPoint: viewPoint), destination != draggingWireStartPin {
                onWireCreate?(draggingWireStartPin, destination)
            }
        }

        if let marqueeRectCanvas, marqueeRectCanvas.width > 8, marqueeRectCanvas.height > 8 {
            let hitPart = project.parts.first { marqueeRectCanvas.intersects(partRect(for: $0)) }
            selectedPartID = hitPart?.id
            selectedWireID = nil
            onSelectionChange?(hitPart?.id, nil)
            onPartActivate?(hitPart?.id)
        }

        draggingPartID = nil
        draggingWireID = nil
        draggingWireStartPin = nil
        draggingWireEndViewPoint = nil
        pressedButtonID = nil
        dragOffset = .zero
        panningStartViewPoint = nil
        marqueeStartCanvasPoint = nil
        marqueeRectCanvas = nil
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 51, 117:
            onDeleteSelection?()
        case 2 where event.modifierFlags.contains(.command):
            onDuplicateSelection?()
        case 53:
            onCancelPlacement?()
            onPlacementPreview?(nil)
        default:
            super.keyDown(with: event)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let nextZoom = min(max(zoom * CGFloat(1 - (event.deltaY * 0.05)), 0.5), 2.5)
            let anchor = convert(event.locationInWindow, from: nil)
            let canvasAnchor = canvasPoint(fromView: anchor)
            zoom = nextZoom
            offset = CGPoint(
                x: anchor.x - canvasAnchor.x * zoom,
                y: anchor.y - canvasAnchor.y * zoom
            )
            onViewportChange?(Double(zoom), CanvasPoint(x: offset.x, y: offset.y))
            needsDisplay = true
            return
        }

        offset = CGPoint(x: offset.x - event.scrollingDeltaX, y: offset.y - event.scrollingDeltaY)
        onViewportChange?(Double(zoom), CanvasPoint(x: offset.x, y: offset.y))
        needsDisplay = true
    }

    override func magnify(with event: NSEvent) {
        let anchor = convert(event.locationInWindow, from: nil)
        let canvasAnchor = canvasPoint(fromView: anchor)
        zoom = min(max(zoom * CGFloat(1 + event.magnification), 0.5), 2.5)
        offset = CGPoint(
            x: anchor.x - canvasAnchor.x * zoom,
            y: anchor.y - canvasAnchor.y * zoom
        )
        onViewportChange?(Double(zoom), CanvasPoint(x: offset.x, y: offset.y))
        needsDisplay = true
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedPartKind(from: sender) != nil else { return [] }
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard droppedPartKind(from: sender) != nil else { return [] }
        let viewPoint = convert(sender.draggingLocation, from: nil)
        let snapped = snap(canvasPoint(fromView: viewPoint))
        onPlacementPreview?(CanvasPoint(x: snapped.x, y: snapped.y))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        onPlacementPreview?(nil)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let kind = droppedPartKind(from: sender) else { return false }
        let viewPoint = convert(sender.draggingLocation, from: nil)
        let snapped = snap(canvasPoint(fromView: viewPoint))
        onDropPartKind?(kind, CanvasPoint(x: snapped.x, y: snapped.y))
        onPlacementPreview?(nil)
        needsDisplay = true
        return true
    }

    private func droppedPartKind(from sender: NSDraggingInfo) -> PartKind? {
        guard let rawValue = sender.draggingPasteboard.string(forType: .string) else { return nil }
        return PartKind(rawValue: rawValue)
    }

    private func drawBackground(in rect: NSRect) {
        let gradient = NSGradient(
            colors: [
                NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.14, alpha: 1),
                NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.10, alpha: 1)
            ]
        )
        gradient?.draw(in: rect, angle: 30)
    }

    private func drawGrid(in rect: NSRect) {
        let path = NSBezierPath()
        let scaledStep = max(CGFloat(10), 24 * zoom)

        let startX = offset.x.truncatingRemainder(dividingBy: scaledStep)
        let startY = offset.y.truncatingRemainder(dividingBy: scaledStep)

        stride(from: startX, through: rect.width, by: scaledStep).forEach { x in
            path.move(to: NSPoint(x: x, y: 0))
            path.line(to: NSPoint(x: x, y: rect.height))
        }

        stride(from: startY, through: rect.height, by: scaledStep).forEach { y in
            path.move(to: NSPoint(x: 0, y: y))
            path.line(to: NSPoint(x: rect.width, y: y))
        }

        NSColor.white.withAlphaComponent(0.08).setStroke()
        path.lineWidth = 1
        path.stroke()
    }

    private func drawWires() {
        for wire in project.diagram.wires {
            let route = routePoints(for: wire).map(viewPoint(fromCanvas:))
            guard route.count == 4 else { continue }

            let path = NSBezierPath()
            path.move(to: route[0])
            for point in route.dropFirst() {
                path.line(to: point)
            }

            let isSelected = selectedWireID == wire.id
            let isHovered = hoveringWireID == wire.id
            path.lineWidth = isSelected ? 5 : (isHovered ? 4 : 3)
            wireColor(named: wire.color).setStroke()
            path.stroke()

            if isSelected, let handlePoint = wireHandlePoint(for: wire).map(viewPoint(fromCanvas:)) {
                let handleRect = NSRect(x: handlePoint.x - 6, y: handlePoint.y - 6, width: 12, height: 12)
                let handlePath = NSBezierPath(roundedRect: handleRect, xRadius: 3, yRadius: 3)
                NSColor.systemBlue.setFill()
                handlePath.fill()
            }

            drawText(
                wire.from.pin,
                in: NSRect(x: route[0].x + 6, y: route[0].y - 16, width: 42, height: 16),
                font: .monospacedSystemFont(ofSize: 10, weight: .medium),
                color: wireColor(named: wire.color).withAlphaComponent(0.82)
            )
            drawText(
                wire.to.pin,
                in: NSRect(x: route[3].x + 6, y: route[3].y - 16, width: 42, height: 16),
                font: .monospacedSystemFont(ofSize: 10, weight: .medium),
                color: wireColor(named: wire.color).withAlphaComponent(0.82)
            )
        }
    }

    private func drawTransientWire() {
        guard let draggingWireStartPin,
              let startPoint = pinPoint(for: draggingWireStartPin).map(viewPoint(fromCanvas:)),
              let draggingWireEndViewPoint
        else {
            return
        }

        let endPoint: CGPoint
        if let destination = pinReference(atViewPoint: draggingWireEndViewPoint),
           let pinnedEnd = pinPoint(for: destination).map(viewPoint(fromCanvas:)) {
            endPoint = pinnedEnd
        } else {
            endPoint = draggingWireEndViewPoint
        }

        let path = NSBezierPath()
        path.move(to: startPoint)
        path.line(to: endPoint)
        NSColor.systemOrange.setStroke()
        path.lineWidth = 3
        path.setLineDash([8, 6], count: 2, phase: 0)
        path.stroke()
    }

    private func drawPlacementPreview() {
        guard let placementPreviewPoint else { return }
        let previewPart: PartDefinition
        if let pendingPlacementEntry {
            previewPart = pendingPlacementEntry.instantiate(id: "preview", at: placementPreviewPoint)
        } else if let pendingPlacementKind {
            previewPart = PartDefinition(
                id: "preview",
                kind: pendingPlacementKind,
                label: pendingPlacementKind.defaultLabel,
                pins: pendingPlacementKind.defaultPins,
                position: placementPreviewPoint,
                attributes: pendingPlacementKind.defaultAttributes,
                pinBindings: [:]
            )
        } else {
            return
        }
        let rect = viewRect(fromCanvas: partRect(for: previewPart))
        let path = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
        partFill(previewPart, isActive: false).withAlphaComponent(0.45).setFill()
        path.fill()
        NSColor.systemBlue.withAlphaComponent(0.6).setStroke()
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.lineWidth = 2
        path.stroke()
    }

    private func drawParts() {
        for part in project.parts {
            let canvasRect = partRect(for: part)
            let rect = viewRect(fromCanvas: canvasRect)
            let isSelected = selectedPartID == part.id
            let isActive = isPartActive(part)
            let isPendingWireStart = draggingWireStartPin?.partID == part.id

            let fill = partFill(part, isActive: isActive)
            fill.setFill()
            let cardPath = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
            cardPath.fill()

            let borderColor: NSColor = if isSelected {
                .systemBlue
            } else if isPendingWireStart {
                .systemOrange
            } else if isActive {
                .systemOrange
            } else {
                .white.withAlphaComponent(0.8)
            }

            borderColor.setStroke()
            cardPath.lineWidth = isSelected ? 3 : (isPendingWireStart ? 3 : (isActive ? 2 : 1))
            cardPath.stroke()

            let titleColor = part.kind == .board ? NSColor.white : NSColor.labelColor
            let subtitleColor = part.kind == .board ? NSColor.white.withAlphaComponent(0.85) : NSColor.secondaryLabelColor
            let pinColor = part.kind == .board ? NSColor.white.withAlphaComponent(0.72) : NSColor.tertiaryLabelColor

            drawText(part.kind.displayName, in: rect.insetBy(dx: 14, dy: 12), font: .systemFont(ofSize: 14, weight: .semibold), color: titleColor)
            drawText(part.label, in: rect.insetBy(dx: 14, dy: 34), font: .systemFont(ofSize: 12, weight: .regular), color: subtitleColor)
            let pinSummary = part.pins.prefix(part.kind == .board ? 6 : min(part.pins.count, 8)).joined(separator: " • ")
            let pinSuffix = part.pins.count > 8 ? " …" : ""
            drawText(pinSummary + pinSuffix, in: rect.insetBy(dx: 14, dy: 52), font: .monospacedSystemFont(ofSize: 11, weight: .regular), color: pinColor)

            drawPartDetail(part, in: rect, isActive: isActive)
            drawPins(for: part)
        }
    }

    private func drawPartDetail(_ part: PartDefinition, in rect: NSRect, isActive: Bool) {
        switch part.kind {
        case .led:
            let indicatorRect = NSRect(x: rect.maxX - 28, y: rect.minY + 12, width: 14, height: 14)
            let indicator = NSBezierPath(ovalIn: indicatorRect)
            (isActive ? NSColor.systemOrange : NSColor.tertiaryLabelColor.withAlphaComponent(0.35)).setFill()
            indicator.fill()
        case .button:
            let buttonRect = NSRect(x: rect.maxX - 34, y: rect.minY + 10, width: 22, height: 22)
            let buttonPath = NSBezierPath(ovalIn: buttonRect)
            (isActive ? NSColor.systemBlue.withAlphaComponent(0.18) : NSColor.clear).setFill()
            buttonPath.fill()
            buttonPath.stroke()
        case .buzzer:
            drawText("~", in: NSRect(x: rect.maxX - 34, y: rect.minY + 8, width: 20, height: 20), font: .systemFont(ofSize: 20, weight: .bold), color: isActive ? .systemOrange : .secondaryLabelColor)
        case .sevenSegment:
            drawSevenSegment(part, in: rect)
        case .potentiometer:
            let track = NSBezierPath()
            track.move(to: CGPoint(x: rect.minX + 24, y: rect.midY + 10))
            track.line(to: CGPoint(x: rect.maxX - 24, y: rect.midY + 10))
            NSColor.darkGray.setStroke()
            track.lineWidth = 3
            track.stroke()
            let wiper = NSBezierPath()
            wiper.move(to: CGPoint(x: rect.midX, y: rect.midY - 20))
            wiper.line(to: CGPoint(x: rect.midX, y: rect.midY + 10))
            wiper.line(to: CGPoint(x: rect.midX + 14, y: rect.midY - 2))
            NSColor.systemBlue.setStroke()
            wiper.lineWidth = 2
            wiper.stroke()
        case .shiftRegister:
            let chipRect = rect.insetBy(dx: 22, dy: 26)
            NSColor(calibratedWhite: 0.15, alpha: 1).setFill()
            NSBezierPath(roundedRect: chipRect, xRadius: 10, yRadius: 10).fill()
            drawText("74HC595", in: NSRect(x: chipRect.minX + 16, y: chipRect.midY - 8, width: chipRect.width - 32, height: 18), font: .monospacedSystemFont(ofSize: 13, weight: .bold), color: .white)
        case .relay:
            let relayRect = rect.insetBy(dx: 26, dy: 26)
            NSColor(calibratedRed: 0.17, green: 0.28, blue: 0.65, alpha: 1).setFill()
            NSBezierPath(roundedRect: relayRect, xRadius: 10, yRadius: 10).fill()
        case .oledDisplay:
            let screenRect = rect.insetBy(dx: 18, dy: 22)
            NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.10, alpha: 1).setFill()
            NSBezierPath(roundedRect: screenRect, xRadius: 10, yRadius: 10).fill()
            drawText("OLED", in: NSRect(x: screenRect.minX + 14, y: screenRect.minY + 10, width: 60, height: 18), font: .monospacedSystemFont(ofSize: 12, weight: .bold), color: .systemGreen)
        case .microphone:
            let micRect = NSRect(x: rect.midX - 12, y: rect.midY - 18, width: 24, height: 36)
            NSColor.darkGray.setFill()
            NSBezierPath(roundedRect: micRect, xRadius: 10, yRadius: 10).fill()
        case .speaker:
            let cone = NSBezierPath()
            cone.move(to: CGPoint(x: rect.minX + 34, y: rect.midY))
            cone.line(to: CGPoint(x: rect.midX, y: rect.minY + 18))
            cone.line(to: CGPoint(x: rect.midX, y: rect.maxY - 18))
            cone.close()
            NSColor.darkGray.setFill()
            cone.fill()
        case .rgbLamp:
            let bulbRect = NSRect(x: rect.midX - 26, y: rect.minY + 18, width: 52, height: 52)
            NSColor.systemYellow.withAlphaComponent(isActive ? 0.9 : 0.25).setFill()
            NSBezierPath(ovalIn: bulbRect).fill()
        case .soilSensor, .lightSensor, .climateSensor, .lineSensor, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            let sensorRect = rect.insetBy(dx: 26, dy: 24)
            NSColor(calibratedRed: 0.14, green: 0.42, blue: 0.24, alpha: 1).setFill()
            NSBezierPath(roundedRect: sensorRect, xRadius: 10, yRadius: 10).fill()
            if [.i2cSensorModule, .uartSensorModule, .visionSensorModule].contains(part.kind) {
                drawText(
                    part.kind == .visionSensorModule ? "AI" : (part.kind == .uartSensorModule ? "UART" : "I2C"),
                    in: NSRect(x: sensorRect.minX + 12, y: sensorRect.midY - 8, width: 48, height: 18),
                    font: .monospacedSystemFont(ofSize: 12, weight: .bold),
                    color: .white
                )
            }
        case .motorDriver:
            let driverRect = rect.insetBy(dx: 18, dy: 18)
            NSColor(calibratedWhite: 0.18, alpha: 1).setFill()
            NSBezierPath(roundedRect: driverRect, xRadius: 12, yRadius: 12).fill()
            drawText("TB6612", in: NSRect(x: driverRect.minX + 14, y: driverRect.midY - 8, width: driverRect.width - 28, height: 18), font: .monospacedSystemFont(ofSize: 13, weight: .bold), color: .white)
        case .motor:
            let motorRect = NSRect(x: rect.midX - 28, y: rect.midY - 20, width: 56, height: 40)
            NSColor.systemGray.setFill()
            NSBezierPath(roundedRect: motorRect, xRadius: 12, yRadius: 12).fill()
        case .servo:
            let servoRect = rect.insetBy(dx: 30, dy: 20)
            NSColor(calibratedRed: 0.13, green: 0.22, blue: 0.72, alpha: 1).setFill()
            NSBezierPath(roundedRect: servoRect, xRadius: 10, yRadius: 10).fill()
            let arm = NSBezierPath()
            arm.move(to: CGPoint(x: servoRect.midX, y: servoRect.midY))
            arm.line(to: CGPoint(x: servoRect.midX + 24, y: servoRect.midY - 18))
            arm.lineWidth = 4
            NSColor.white.setStroke()
            arm.stroke()
        case .board, .resistor:
            break
        }
    }

    private func drawSevenSegment(_ part: PartDefinition, in rect: NSRect) {
        let lit = CircuitGraph.litSegments(for: part, in: project, pinStates: pinStates, activeButtons: activeButtonIDs)
        let bezel = rect.insetBy(dx: 48, dy: 14)
        NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: bezel, xRadius: 12, yRadius: 12).fill()

        for (segment, segmentRect) in sevenSegmentRects(in: bezel) {
            let path = NSBezierPath(roundedRect: segmentRect, xRadius: 4, yRadius: 4)
            (lit.contains(segment) ? NSColor.systemRed : NSColor.systemRed.withAlphaComponent(0.14)).setFill()
            path.fill()
        }
    }

    private func sevenSegmentRects(in rect: NSRect) -> [String: NSRect] {
        [
            "A": NSRect(x: rect.minX + 16, y: rect.minY + 8, width: rect.width - 32, height: 10),
            "B": NSRect(x: rect.maxX - 18, y: rect.minY + 18, width: 10, height: rect.height * 0.3),
            "C": NSRect(x: rect.maxX - 18, y: rect.midY + 4, width: 10, height: rect.height * 0.3),
            "D": NSRect(x: rect.minX + 16, y: rect.maxY - 18, width: rect.width - 32, height: 10),
            "E": NSRect(x: rect.minX + 8, y: rect.midY + 4, width: 10, height: rect.height * 0.3),
            "F": NSRect(x: rect.minX + 8, y: rect.minY + 18, width: 10, height: rect.height * 0.3),
            "G": NSRect(x: rect.minX + 16, y: rect.midY - 5, width: rect.width - 32, height: 10),
            "DP": NSRect(x: rect.maxX - 16, y: rect.maxY - 20, width: 8, height: 8)
        ]
    }

    private func drawMarqueeSelection() {
        guard let marqueeRectCanvas else { return }
        let rect = viewRect(fromCanvas: marqueeRectCanvas)
        let path = NSBezierPath(rect: rect)
        NSColor.systemBlue.withAlphaComponent(0.12).setFill()
        path.fill()
        NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
        path.lineWidth = 1.5
        path.setLineDash([6, 4], count: 2, phase: 0)
        path.stroke()
    }

    private func drawText(_ string: String, in rect: NSRect, font: NSFont, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        (string as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func partRect(for part: PartDefinition) -> NSRect {
        let size: NSSize
        switch part.kind {
        case .board:
            size = NSSize(width: 220, height: 110)
        case .button:
            size = NSSize(width: 130, height: 78)
        case .sevenSegment:
            size = NSSize(width: 150, height: 190)
        case .shiftRegister:
            size = NSSize(width: 220, height: 110)
        case .oledDisplay:
            size = NSSize(width: 180, height: 110)
        case .motorDriver:
            size = NSSize(width: 220, height: 120)
        case .motor, .servo:
            size = NSSize(width: 170, height: 100)
        case .rgbLamp:
            size = NSSize(width: 170, height: 110)
        case .soilSensor, .lightSensor, .climateSensor, .lineSensor, .relay, .microphone, .speaker, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            size = NSSize(width: 160, height: 96)
        default:
            size = NSSize(width: 150, height: 90)
        }
        return NSRect(
            x: part.position.x - size.width * 0.5,
            y: part.position.y - size.height * 0.5,
            width: size.width,
            height: size.height
        )
    }

    private func pinReference(atViewPoint point: CGPoint) -> PinReference? {
        for part in project.parts {
            for pin in part.pins {
                let reference = PinReference(partID: part.id, pin: pin)
                guard let pinPoint = pinPoint(for: reference).map(viewPoint(fromCanvas:)) else { continue }
                let pinRect = NSRect(x: pinPoint.x - 9, y: pinPoint.y - 9, width: 18, height: 18)
                if pinRect.contains(point) {
                    return reference
                }
            }
        }
        return nil
    }

    private func drawPins(for part: PartDefinition) {
        let shouldShowPins = selectedPartID == part.id || hoveringPin?.partID == part.id || draggingWireStartPin != nil
        guard shouldShowPins else { return }

        for pin in part.pins {
            let reference = PinReference(partID: part.id, pin: pin)
            guard let pinPoint = pinPoint(for: reference).map(viewPoint(fromCanvas:)) else { continue }
            let isPending = draggingWireStartPin == reference
            let isHovered = hoveringPin == reference
            let radius: CGFloat = isHovered ? 7 : 5
            let pinRect = NSRect(x: pinPoint.x - radius, y: pinPoint.y - radius, width: radius * 2, height: radius * 2)
            let pinPath = NSBezierPath(ovalIn: pinRect)
            (isPending ? NSColor.systemOrange : (isHovered ? NSColor.systemYellow : NSColor.systemBlue)).setFill()
            pinPath.fill()

            let labelOriginX = pinLabelAlignment(for: reference) == .left ? pinPoint.x + 8 : pinPoint.x - 52
            drawText(
                pin,
                in: NSRect(x: labelOriginX, y: pinPoint.y - 8, width: 48, height: 14),
                font: .monospacedSystemFont(ofSize: 10, weight: .medium),
                color: part.kind == .board ? .white.withAlphaComponent(0.85) : .secondaryLabelColor
            )
        }
    }

    private func wireID(atViewPoint point: CGPoint) -> String? {
        for wire in project.diagram.wires.reversed() {
            let route = routePoints(for: wire).map(viewPoint(fromCanvas:))
            for index in 0..<(route.count - 1) {
                if distanceFrom(point: point, toSegmentFrom: route[index], to: route[index + 1]) <= 8 {
                    return wire.id
                }
            }
        }
        return nil
    }

    private func selectedWireHandle(atViewPoint point: CGPoint) -> String? {
        guard let selectedWireID,
              let wire = project.diagram.wires.first(where: { $0.id == selectedWireID }),
              let handlePoint = wireHandlePoint(for: wire).map(viewPoint(fromCanvas:))
        else {
            return nil
        }

        let rect = NSRect(x: handlePoint.x - 8, y: handlePoint.y - 8, width: 16, height: 16)
        return rect.contains(point) ? selectedWireID : nil
    }

    private func routePoints(for wire: WireDefinition) -> [CGPoint] {
        guard let from = pinPoint(for: wire.from), let to = pinPoint(for: wire.to) else { return [] }
        let midX = CGFloat(wire.midX ?? Double((from.x + to.x) * 0.5))
        return [
            from,
            CGPoint(x: midX, y: from.y),
            CGPoint(x: midX, y: to.y),
            to
        ]
    }

    private func wireHandlePoint(for wire: WireDefinition) -> CGPoint? {
        let route = routePoints(for: wire)
        guard route.count == 4 else { return nil }
        return CGPoint(x: route[1].x, y: (route[1].y + route[2].y) * 0.5)
    }

    private func distanceFrom(point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        guard lengthSquared > 0 else {
            return hypot(point.x - start.x, point.y - start.y)
        }

        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        let projection = CGPoint(x: start.x + t * dx, y: start.y + t * dy)
        return hypot(point.x - projection.x, point.y - projection.y)
    }

    private func pinPoint(for reference: PinReference) -> CGPoint? {
        guard let part = project.parts.first(where: { $0.id == reference.partID }) else { return nil }
        let rect = partRect(for: part)

        switch part.kind {
        case .board:
            return boardPinPoint(for: reference.pin, in: rect)
        case .led:
            return discretePinPoint(pin: reference.pin, positions: ["A": CGPoint(x: rect.minX, y: rect.midY - 18), "K": CGPoint(x: rect.minX, y: rect.midY + 18)])
        case .resistor:
            return discretePinPoint(pin: reference.pin, positions: ["1": CGPoint(x: rect.minX, y: rect.midY), "2": CGPoint(x: rect.maxX, y: rect.midY)])
        case .button:
            return discretePinPoint(
                pin: reference.pin,
                positions: [
                    "1": CGPoint(x: rect.minX, y: rect.midY - 16),
                    "2": CGPoint(x: rect.minX, y: rect.midY + 16),
                    "3": CGPoint(x: rect.maxX, y: rect.midY - 16),
                    "4": CGPoint(x: rect.maxX, y: rect.midY + 16)
                ]
            )
        case .buzzer:
            return discretePinPoint(pin: reference.pin, positions: ["+": CGPoint(x: rect.minX, y: rect.midY - 12), "-": CGPoint(x: rect.minX, y: rect.midY + 12)])
        case .sevenSegment:
            return discretePinPoint(
                pin: reference.pin,
                positions: [
                    "A": CGPoint(x: rect.minX, y: rect.minY + 28),
                    "F": CGPoint(x: rect.minX, y: rect.minY + 60),
                    "G": CGPoint(x: rect.minX, y: rect.midY),
                    "E": CGPoint(x: rect.minX, y: rect.maxY - 60),
                    "COM": CGPoint(x: rect.minX, y: rect.maxY - 28),
                    "B": CGPoint(x: rect.maxX, y: rect.minY + 28),
                    "C": CGPoint(x: rect.maxX, y: rect.midY - 16),
                    "D": CGPoint(x: rect.maxX, y: rect.maxY - 60),
                    "DP": CGPoint(x: rect.maxX, y: rect.maxY - 28)
                ]
            )
        case .potentiometer:
            return discretePinPoint(pin: reference.pin, positions: ["1": CGPoint(x: rect.minX, y: rect.midY + 18), "2": CGPoint(x: rect.midX, y: rect.minY), "3": CGPoint(x: rect.maxX, y: rect.midY + 18)])
        case .shiftRegister:
            return shiftRegisterPinPoint(pin: reference.pin, in: rect)
        case .soilSensor, .lightSensor, .microphone, .lineSensor, .digitalSensorModule:
            return discretePinPoint(pin: reference.pin, positions: ["OUT": CGPoint(x: rect.maxX, y: rect.midY), "VCC": CGPoint(x: rect.minX, y: rect.minY + 20), "GND": CGPoint(x: rect.minX, y: rect.maxY - 20)])
        case .analogSensorModule:
            return discretePinPoint(pin: reference.pin, positions: ["AOUT": CGPoint(x: rect.maxX, y: rect.midY - 16), "DOUT": CGPoint(x: rect.maxX, y: rect.midY + 16), "VCC": CGPoint(x: rect.minX, y: rect.minY + 20), "GND": CGPoint(x: rect.minX, y: rect.maxY - 20)])
        case .climateSensor:
            return discretePinPoint(pin: reference.pin, positions: ["DATA": CGPoint(x: rect.maxX, y: rect.midY), "VCC": CGPoint(x: rect.minX, y: rect.minY + 20), "GND": CGPoint(x: rect.minX, y: rect.maxY - 20)])
        case .relay:
            return discretePinPoint(pin: reference.pin, positions: ["IN": CGPoint(x: rect.minX, y: rect.midY), "VCC": CGPoint(x: rect.minX, y: rect.minY + 20), "GND": CGPoint(x: rect.minX, y: rect.maxY - 20), "NO": CGPoint(x: rect.maxX, y: rect.minY + 24), "COM": CGPoint(x: rect.maxX, y: rect.maxY - 24)])
        case .oledDisplay:
            return discretePinPoint(pin: reference.pin, positions: ["SDA": CGPoint(x: rect.minX, y: rect.midY - 16), "SCL": CGPoint(x: rect.minX, y: rect.midY + 16), "VCC": CGPoint(x: rect.maxX, y: rect.midY - 16), "GND": CGPoint(x: rect.maxX, y: rect.midY + 16)])
        case .i2cSensorModule:
            return discretePinPoint(pin: reference.pin, positions: ["SDA": CGPoint(x: rect.minX, y: rect.midY - 16), "SCL": CGPoint(x: rect.minX, y: rect.midY + 16), "VCC": CGPoint(x: rect.maxX, y: rect.midY - 16), "GND": CGPoint(x: rect.maxX, y: rect.midY + 16)])
        case .speaker:
            return discretePinPoint(pin: reference.pin, positions: ["SIG": CGPoint(x: rect.minX, y: rect.midY - 14), "GND": CGPoint(x: rect.minX, y: rect.midY + 14)])
        case .uartSensorModule, .visionSensorModule:
            return discretePinPoint(pin: reference.pin, positions: ["TX": CGPoint(x: rect.maxX, y: rect.midY - 16), "RX": CGPoint(x: rect.maxX, y: rect.midY + 16), "VCC": CGPoint(x: rect.minX, y: rect.minY + 20), "GND": CGPoint(x: rect.minX, y: rect.maxY - 20)])
        case .distanceSensorModule:
            return discretePinPoint(pin: reference.pin, positions: ["TRIG": CGPoint(x: rect.minX, y: rect.midY - 16), "ECHO": CGPoint(x: rect.maxX, y: rect.midY - 16), "VCC": CGPoint(x: rect.minX, y: rect.maxY - 20), "GND": CGPoint(x: rect.maxX, y: rect.maxY - 20)])
        case .rgbLamp:
            return discretePinPoint(pin: reference.pin, positions: ["R": CGPoint(x: rect.minX, y: rect.midY - 20), "G": CGPoint(x: rect.minX, y: rect.midY), "B": CGPoint(x: rect.minX, y: rect.midY + 20), "GND": CGPoint(x: rect.maxX, y: rect.midY)])
        case .motorDriver:
            return motorDriverPinPoint(pin: reference.pin, in: rect)
        case .motor:
            return discretePinPoint(pin: reference.pin, positions: ["+": CGPoint(x: rect.minX, y: rect.midY - 14), "-": CGPoint(x: rect.minX, y: rect.midY + 14)])
        case .servo:
            return discretePinPoint(pin: reference.pin, positions: ["SIG": CGPoint(x: rect.minX, y: rect.midY - 18), "VCC": CGPoint(x: rect.minX, y: rect.midY), "GND": CGPoint(x: rect.minX, y: rect.midY + 18)])
        }
    }

    private func boardPinPoint(for pin: String, in rect: NSRect) -> CGPoint? {
        let topPins = ["D13", "D12", "D11", "D10", "D9", "D8", "D7", "D6", "D5", "D4", "D3", "D2"]
        let bottomPins = ["A0", "A1", "A2", "A3", "A4", "A5", "5V", "GND"]

        if let index = topPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(topPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.minY)
        }

        if let index = bottomPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(bottomPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.maxY)
        }

        return nil
    }

    private func shiftRegisterPinPoint(pin: String, in rect: NSRect) -> CGPoint? {
        let topPins = ["DS", "SH_CP", "ST_CP", "OE", "MR", "VCC"]
        let bottomPins = ["Q0", "Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7", "GND"]

        if let index = topPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(topPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.minY)
        }

        if let index = bottomPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(bottomPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.maxY)
        }

        return nil
    }

    private func motorDriverPinPoint(pin: String, in rect: NSRect) -> CGPoint? {
        let topPins = ["ENA", "IN1", "IN2", "ENB", "IN3", "IN4", "VM"]
        let bottomPins = ["L+", "L-", "R+", "R-", "GND"]

        if let index = topPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(topPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.minY)
        }

        if let index = bottomPins.firstIndex(of: pin) {
            let step = rect.width / CGFloat(bottomPins.count + 1)
            return CGPoint(x: rect.minX + step * CGFloat(index + 1), y: rect.maxY)
        }

        return nil
    }

    private func discretePinPoint(pin: String, positions: [String: CGPoint]) -> CGPoint? {
        positions[pin]
    }

    private func pinLabelAlignment(for reference: PinReference) -> NSTextAlignment {
        guard let part = project.parts.first(where: { $0.id == reference.partID }) else { return .left }
        switch part.kind {
        case .board, .shiftRegister, .motorDriver:
            return .left
        case .resistor:
            return reference.pin == "1" ? .right : .left
        case .button:
            return reference.pin == "1" || reference.pin == "2" ? .right : .left
        case .led, .buzzer, .sevenSegment, .potentiometer, .soilSensor, .lightSensor, .climateSensor, .relay, .oledDisplay, .microphone, .speaker, .rgbLamp, .lineSensor, .motor, .servo, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            return .right
        }
    }

    private func wireColor(named name: String) -> NSColor {
        switch name {
        case "black":
            return .black.withAlphaComponent(0.72)
        case "green":
            return .systemGreen.withAlphaComponent(0.82)
        case "red":
            return .systemRed.withAlphaComponent(0.85)
        case "blue":
            return .systemBlue.withAlphaComponent(0.85)
        case "yellow":
            return .systemYellow.withAlphaComponent(0.85)
        default:
            return .systemGray
        }
    }

    private func partFill(_ part: PartDefinition, isActive: Bool) -> NSColor {
        switch part.kind {
        case .board:
            return NSColor(calibratedRed: 0.11, green: 0.39, blue: 0.30, alpha: 1)
        case .led:
            return isActive ? NSColor.systemOrange.withAlphaComponent(0.18) : NSColor.white.withAlphaComponent(0.96)
        case .sevenSegment:
            return NSColor(calibratedWhite: 0.95, alpha: 0.98)
        case .shiftRegister:
            return NSColor(calibratedWhite: 0.94, alpha: 0.98)
        case .motorDriver:
            return NSColor(calibratedWhite: 0.90, alpha: 0.98)
        case .oledDisplay:
            return NSColor(calibratedWhite: 0.92, alpha: 0.98)
        case .relay:
            return NSColor(calibratedWhite: 0.92, alpha: 0.98)
        case .soilSensor, .lightSensor, .climateSensor, .microphone, .speaker, .rgbLamp, .lineSensor, .motor, .servo, .resistor, .button, .buzzer, .potentiometer, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            return NSColor.white.withAlphaComponent(0.96)
        }
    }

    private func isPartActive(_ part: PartDefinition) -> Bool {
        CircuitGraph.partIsActive(part, in: project, pinStates: pinStates, activeButtons: activeButtonIDs)
    }

    private func snap(_ point: CGPoint) -> CGPoint {
        let step: CGFloat = 24
        return CGPoint(
            x: (point.x / step).rounded() * step,
            y: (point.y / step).rounded() * step
        )
    }

    private func canvasPoint(fromView point: CGPoint) -> CGPoint {
        CGPoint(
            x: (point.x - offset.x) / zoom,
            y: (point.y - offset.y) / zoom
        )
    }

    private func viewPoint(fromCanvas point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * zoom + offset.x,
            y: point.y * zoom + offset.y
        )
    }

    private func viewRect(fromCanvas rect: CGRect) -> CGRect {
        CGRect(
            x: rect.origin.x * zoom + offset.x,
            y: rect.origin.y * zoom + offset.y,
            width: rect.width * zoom,
            height: rect.height * zoom
        )
    }
}
