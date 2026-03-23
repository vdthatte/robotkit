import Foundation

enum CircuitGraph {
    static func boardInputOverrides(
        in project: RobotProject,
        activeButtons: Set<String>,
        environment: SimulationEnvironmentState,
        roverOffset: Double
    ) -> [String: Int] {
        var overrides = boardInputOverrides(in: project, activeButtons: activeButtons)

        for part in project.parts {
            switch part.kind {
            case .soilSensor:
                applyDigitalSensorOverride(for: part, level: environment.soilMoisture < 0.4 ? 1 : 0, in: project, overrides: &overrides)
            case .lightSensor:
                applyDigitalSensorOverride(for: part, level: environment.ambientLight < 0.45 ? 1 : 0, in: project, overrides: &overrides)
            case .climateSensor:
                let temperatureThreshold = part.attributes["threshold"].flatMap(Double.init) ?? 28
                let humidityThreshold = part.attributes["humidityThreshold"].flatMap(Double.init) ?? 0.7
                let climateAlert = environment.temperatureC >= temperatureThreshold || environment.humidity >= humidityThreshold
                applyDigitalSensorOverride(for: part, outputPin: "DATA", level: climateAlert ? 1 : 0, in: project, overrides: &overrides)
            case .microphone:
                applyDigitalSensorOverride(for: part, level: environment.voiceTriggerLevel > 0.6 ? 1 : 0, in: project, overrides: &overrides)
            case .lineSensor:
                let side = part.attributes["side"] ?? "left"
                let lineDetected = lineSensorSeesTrack(side: side, roverOffset: roverOffset + environment.baseLineOffset)
                applyDigitalSensorOverride(for: part, level: lineDetected ? 0 : 1, in: project, overrides: &overrides)
            case .potentiometer:
                applyDigitalSensorOverride(for: part, outputPin: "2", level: environment.handTarget > 0.5 ? 1 : 0, in: project, overrides: &overrides)
            case .analogSensorModule:
                let threshold = part.attributes["threshold"].flatMap(Double.init) ?? 0.5
                applyDigitalSensorOverride(for: part, outputPin: "DOUT", level: environment.soilMoisture < threshold ? 1 : 0, in: project, overrides: &overrides)
            case .digitalSensorModule:
                let family = part.attributes["family"] ?? "gravity-digital"
                let level = family == "pir" ? (environment.voiceTriggerLevel > 0.4 ? 1 : 0) : (environment.ambientLight < 0.5 ? 1 : 0)
                applyDigitalSensorOverride(for: part, outputPin: "SIG", level: level, in: project, overrides: &overrides)
            case .distanceSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule:
                break
            default:
                break
            }
        }

        return overrides
    }

    static func reachablePins(
        from start: PinReference,
        in project: RobotProject,
        activeButtons: Set<String> = []
    ) -> Set<PinReference> {
        let adjacency = adjacencyMap(for: project, activeButtons: activeButtons)
        var visited: Set<PinReference> = [start]
        var queue: [PinReference] = [start]

        while let current = queue.first {
            queue.removeFirst()
            for neighbor in adjacency[current, default: []] where visited.contains(neighbor) == false {
                visited.insert(neighbor)
                queue.append(neighbor)
            }
        }

        return visited
    }

    static func boardInputOverrides(
        in project: RobotProject,
        activeButtons: Set<String>
    ) -> [String: Int] {
        var overrides: [String: Int] = [:]

        for buttonID in activeButtons {
            let origin = PinReference(partID: buttonID, pin: "1")
            let reachable = reachablePins(from: origin, in: project, activeButtons: activeButtons)
            let boardPins = reachable
                .filter { $0.partID == "board" && isDriveableBoardPin($0.pin) }
                .map(\.pin)

            let drivesLow = reachable.contains(PinReference(partID: "board", pin: "GND"))
            let drivesHigh = reachable.contains(PinReference(partID: "board", pin: "5V"))

            for pin in boardPins {
                if drivesLow {
                    overrides[pin] = 0
                } else if drivesHigh, overrides[pin] != 0 {
                    overrides[pin] = 1
                }
            }
        }

        return overrides
    }

    static func partIsActive(
        _ part: PartDefinition,
        in project: RobotProject,
        pinStates: [String: Int],
        activeButtons: Set<String> = []
    ) -> Bool {
        switch part.kind {
        case .board:
            return pinStates.contains(where: { $0.value == 1 })
        case .button:
            return activeButtons.contains(part.id)
        case .led:
            return netContainsPoweredAnodeCathode(
                part: part,
                anodePin: "A",
                cathodePin: "K",
                project: project,
                pinStates: pinStates,
                activeButtons: activeButtons
            )
        case .buzzer:
            return netContainsPoweredAnodeCathode(
                part: part,
                anodePin: "+",
                cathodePin: "-",
                project: project,
                pinStates: pinStates,
                activeButtons: activeButtons
            )
        case .sevenSegment:
            return litSegments(for: part, in: project, pinStates: pinStates, activeButtons: activeButtons).isEmpty == false
        case .relay:
            return relayIsActive(part, in: project, pinStates: pinStates)
        case .speaker:
            return speakerIsActive(part, in: project, pinStates: pinStates)
        case .rgbLamp:
            let lamp = rgbLampState(part, in: project, pinStates: pinStates)
            return lamp.0 || lamp.1 || lamp.2
        case .motor:
            return motorPower(for: part, in: project, pinStates: pinStates) != 0
        case .servo:
            return servoAngle(for: part, in: project, pinStates: pinStates, fallback: 0.5) > 0
        case .soilSensor, .lightSensor, .climateSensor, .oledDisplay, .microphone, .lineSensor, .motorDriver, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
            return false
        case .resistor, .potentiometer, .shiftRegister:
            return false
        }
    }

    static func litSegments(
        for part: PartDefinition,
        in project: RobotProject,
        pinStates: [String: Int],
        activeButtons: Set<String> = []
    ) -> Set<String> {
        guard part.kind == .sevenSegment else { return [] }
        let commonNet = reachablePins(
            from: PinReference(partID: part.id, pin: "COM"),
            in: project,
            activeButtons: activeButtons
        )
        guard commonNet.contains(PinReference(partID: "board", pin: "GND")) else { return [] }

        let segmentPins = ["A", "B", "C", "D", "E", "F", "G", "DP"]
        return Set(segmentPins.filter { pin in
            let net = reachablePins(
                from: PinReference(partID: part.id, pin: pin),
                in: project,
                activeButtons: activeButtons
            )
            return net.contains { reference in
                reference.partID == "board" && pinStates[reference.pin, default: 0] == 1
            }
        })
    }

    static func relayIsActive(_ part: PartDefinition, in project: RobotProject, pinStates: [String: Int]) -> Bool {
        guard part.kind == .relay else { return false }
        return drivingBoardPins(for: part, pin: "IN", in: project)
            .contains { pinStates[$0, default: 0] == 1 }
    }

    static func rgbLampState(_ part: PartDefinition, in project: RobotProject, pinStates: [String: Int]) -> (Bool, Bool, Bool) {
        guard part.kind == .rgbLamp else { return (false, false, false) }
        return (
            drivingBoardPins(for: part, pin: "R", in: project).contains { pinStates[$0, default: 0] == 1 },
            drivingBoardPins(for: part, pin: "G", in: project).contains { pinStates[$0, default: 0] == 1 },
            drivingBoardPins(for: part, pin: "B", in: project).contains { pinStates[$0, default: 0] == 1 }
        )
    }

    static func speakerIsActive(_ part: PartDefinition, in project: RobotProject, pinStates: [String: Int]) -> Bool {
        guard part.kind == .speaker || part.kind == .buzzer else { return false }
        let inputPin = part.kind == .speaker ? "SIG" : "+"
        return drivingBoardPins(for: part, pin: inputPin, in: project)
            .contains { pinStates[$0, default: 0] == 1 }
    }

    static func motorPower(for part: PartDefinition, in project: RobotProject, pinStates: [String: Int]) -> Double {
        guard part.kind == .motor else { return 0 }

        for driver in project.parts where driver.kind == .motorDriver {
            let leftPower = driverChannelPower(driver: driver, enable: "ENA", forward: "IN1", reverse: "IN2", pinStates: pinStates, project: project)
            let rightPower = driverChannelPower(driver: driver, enable: "ENB", forward: "IN3", reverse: "IN4", pinStates: pinStates, project: project)

            if motorConnected(part, toDriver: driver, positivePin: "L+", negativePin: "L-", in: project) {
                return leftPower
            }
            if motorConnected(part, toDriver: driver, positivePin: "R+", negativePin: "R-", in: project) {
                return rightPower
            }
        }
        return 0
    }

    static func servoAngle(for part: PartDefinition, in project: RobotProject, pinStates: [String: Int], fallback: Double) -> Double {
        guard part.kind == .servo else { return 0 }
        let active = drivingBoardPins(for: part, pin: "SIG", in: project)
            .contains { pinStates[$0, default: 0] == 1 }
        return active ? max(20, fallback * 180) : 0
    }

    static func drivingBoardPins(for part: PartDefinition, pin: String, in project: RobotProject) -> [String] {
        boardPinsReachable(from: PinReference(partID: part.id, pin: pin), in: project)
    }

    private static func netContainsPoweredAnodeCathode(
        part: PartDefinition,
        anodePin: String,
        cathodePin: String,
        project: RobotProject,
        pinStates: [String: Int],
        activeButtons: Set<String>
    ) -> Bool {
        let anodeNet = reachablePins(
            from: PinReference(partID: part.id, pin: anodePin),
            in: project,
            activeButtons: activeButtons
        )
        let cathodeNet = reachablePins(
            from: PinReference(partID: part.id, pin: cathodePin),
            in: project,
            activeButtons: activeButtons
        )

        let hasHighBoardPin = anodeNet.contains { reference in
            reference.partID == "board" && pinStates[reference.pin, default: 0] == 1
        }
        let hasGround = cathodeNet.contains(PinReference(partID: "board", pin: "GND"))
        return hasHighBoardPin && hasGround
    }

    private static func adjacencyMap(
        for project: RobotProject,
        activeButtons: Set<String>
    ) -> [PinReference: Set<PinReference>] {
        var adjacency: [PinReference: Set<PinReference>] = [:]

        for wire in project.diagram.wires {
            link(wire.from, wire.to, in: &adjacency)
        }

        for part in project.parts {
            switch part.kind {
            case .resistor:
                link(
                    PinReference(partID: part.id, pin: "1"),
                    PinReference(partID: part.id, pin: "2"),
                    in: &adjacency
                )
            case .button:
                let sideA = [
                    PinReference(partID: part.id, pin: "1"),
                    PinReference(partID: part.id, pin: "2")
                ]
                let sideB = [
                    PinReference(partID: part.id, pin: "3"),
                    PinReference(partID: part.id, pin: "4")
                ]
                link(sideA[0], sideA[1], in: &adjacency)
                link(sideB[0], sideB[1], in: &adjacency)
                if activeButtons.contains(part.id) {
                    for a in sideA {
                        for b in sideB {
                            link(a, b, in: &adjacency)
                        }
                    }
                }
            case .potentiometer:
                link(
                    PinReference(partID: part.id, pin: "1"),
                    PinReference(partID: part.id, pin: "2"),
                    in: &adjacency
                )
                link(
                    PinReference(partID: part.id, pin: "2"),
                    PinReference(partID: part.id, pin: "3"),
                    in: &adjacency
                )
            case .board, .led, .buzzer, .sevenSegment, .shiftRegister, .soilSensor, .lightSensor, .climateSensor, .relay, .oledDisplay, .microphone, .speaker, .rgbLamp, .lineSensor, .motorDriver, .motor, .servo, .digitalSensorModule, .analogSensorModule, .i2cSensorModule, .uartSensorModule, .visionSensorModule, .distanceSensorModule:
                break
            }
        }

        return adjacency
    }

    private static func link(
        _ lhs: PinReference,
        _ rhs: PinReference,
        in adjacency: inout [PinReference: Set<PinReference>]
    ) {
        adjacency[lhs, default: []].insert(rhs)
        adjacency[rhs, default: []].insert(lhs)
    }

    private static func isDriveableBoardPin(_ pin: String) -> Bool {
        pin.hasPrefix("D") || pin.hasPrefix("A")
    }

    private static func boardPinsReachable(from reference: PinReference, in project: RobotProject) -> [String] {
        reachablePins(from: reference, in: project)
            .filter { $0.partID == "board" && isDriveableBoardPin($0.pin) }
            .map(\.pin)
    }

    private static func applyDigitalSensorOverride(
        for part: PartDefinition,
        outputPin: String = "OUT",
        level: Int,
        in project: RobotProject,
        overrides: inout [String: Int]
    ) {
        for boardPin in boardPinsReachable(from: PinReference(partID: part.id, pin: outputPin), in: project) {
            overrides[boardPin] = level
        }
    }

    private static func lineSensorSeesTrack(side: String, roverOffset: Double) -> Bool {
        let sensorOffset = side == "right" ? 0.18 : -0.18
        return abs(roverOffset + sensorOffset) < 0.12
    }

    private static func driverChannelPower(
        driver: PartDefinition,
        enable: String,
        forward: String,
        reverse: String,
        pinStates: [String: Int],
        project: RobotProject
    ) -> Double {
        let enabled = boardPinsReachable(from: PinReference(partID: driver.id, pin: enable), in: project).contains { pinStates[$0, default: 0] == 1 }
        guard enabled else { return 0 }
        let forwardActive = boardPinsReachable(from: PinReference(partID: driver.id, pin: forward), in: project).contains { pinStates[$0, default: 0] == 1 }
        let reverseActive = boardPinsReachable(from: PinReference(partID: driver.id, pin: reverse), in: project).contains { pinStates[$0, default: 0] == 1 }
        if forwardActive == reverseActive { return 0 }
        return forwardActive ? 1 : -1
    }

    private static func motorConnected(
        _ motor: PartDefinition,
        toDriver driver: PartDefinition,
        positivePin: String,
        negativePin: String,
        in project: RobotProject
    ) -> Bool {
        let plusNet = reachablePins(from: PinReference(partID: motor.id, pin: "+"), in: project)
        let minusNet = reachablePins(from: PinReference(partID: motor.id, pin: "-"), in: project)
        return plusNet.contains(PinReference(partID: driver.id, pin: positivePin))
            && minusNet.contains(PinReference(partID: driver.id, pin: negativePin))
    }
}
