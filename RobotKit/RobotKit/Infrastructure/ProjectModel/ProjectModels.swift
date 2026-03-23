import Foundation

struct RobotProject: Codable, Equatable {
    var schemaVersion: Int
    var name: String
    var runtime: RuntimeFlavor
    var board: BoardDefinition
    var demo: DemoDefinition
    var files: [ProjectFile]
    var diagram: RobotDiagram

    static let starter = RobotProject(
        schemaVersion: 1,
        name: "RobotKit",
        runtime: .javaScriptCore,
        board: .arduinoUno,
        demo: DemoDefinition(
            id: "uno-blink",
            name: "Uno Blink",
            binary: "blink.hex",
            source: "sketch.ino",
            observedPins: ["D13"]
        ),
        files: [
            ProjectFile(name: "project.json", path: "project.json", kind: .manifest),
            ProjectFile(name: "diagram.robotkit.json", path: "diagram.robotkit.json", kind: .diagram),
            ProjectFile(name: "sketch.ino", path: "sketch.ino", kind: .source),
            ProjectFile(name: "blink.hex", path: "blink.hex", kind: .firmware)
        ],
        diagram: RobotDiagram(
            parts: [
                PartDefinition(
                    id: "board",
                    kind: .board,
                    label: "Arduino Uno",
                    pins: BoardDefinition.arduinoUno.canvasPins,
                    position: .init(x: 180, y: 220),
                    attributes: ["footprint": "uno"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "r1",
                    kind: .resistor,
                    label: "220 ohm",
                    pins: ["1", "2"],
                    position: .init(x: 420, y: 160),
                    attributes: ["value": "220"],
                    pinBindings: [:]
                ),
                PartDefinition(
                    id: "led1",
                    kind: .led,
                    label: "Status LED",
                    pins: ["A", "K"],
                    position: .init(x: 620, y: 180),
                    attributes: ["color": "amber"],
                    pinBindings: ["A": "D13", "K": "GND"]
                )
            ],
            wires: [
                WireDefinition(
                    id: "wire-d13-r1",
                    from: .init(partID: "board", pin: "D13"),
                    to: .init(partID: "r1", pin: "1"),
                    color: "green",
                    midX: nil
                ),
                WireDefinition(
                    id: "wire-r1-led",
                    from: .init(partID: "r1", pin: "2"),
                    to: .init(partID: "led1", pin: "A"),
                    color: "green",
                    midX: nil
                ),
                WireDefinition(
                    id: "wire-led-gnd",
                    from: .init(partID: "led1", pin: "K"),
                    to: .init(partID: "board", pin: "GND"),
                    color: "black",
                    midX: nil
                )
            ]
        )
    )

    var parts: [PartDefinition] {
        diagram.parts
    }

    static func untitled(named name: String = "Untitled Project") -> RobotProject {
        var project = RobotProject.starter
        project.name = name
        project.demo = DemoDefinition(
            id: "uno-custom",
            name: "Uno Sketch",
            binary: "blink.hex",
            source: "sketch.ino",
            observedPins: ["D13"]
        )
        project.diagram.parts = [
            PartDefinition(
                id: "board",
                kind: .board,
                label: "Arduino Uno",
                pins: BoardDefinition.arduinoUno.canvasPins,
                position: .init(x: 200, y: 280),
                attributes: ["footprint": "uno"],
                pinBindings: [:]
            )
        ]
        project.diagram.wires = []
        return project
    }
}

enum RuntimeFlavor: String, Codable, Equatable {
    case javaScriptCore
    case nativeCore

    var displayName: String {
        switch self {
        case .javaScriptCore:
            return "JavaScriptCore"
        case .nativeCore:
            return "Native Core"
        }
    }
}

struct BoardDefinition: Codable, Equatable {
    let id: String
    let displayName: String
    let clockDescription: String

    static let arduinoUno = BoardDefinition(
        id: "arduino-uno",
        displayName: "Arduino Uno",
        clockDescription: "16 MHz AVR"
    )

    var canvasPins: [String] {
        switch id {
        case "arduino-uno":
            return [
                "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9", "D10", "D11", "D12", "D13",
                "A0", "A1", "A2", "A3", "A4", "A5",
                "5V", "GND"
            ]
        default:
            return ["D13", "GND", "5V"]
        }
    }
}

struct DemoDefinition: Codable, Equatable {
    let id: String
    let name: String
    let binary: String
    let source: String
    let observedPins: [String]
}

struct ProjectFile: Identifiable, Codable, Equatable {
    var id: String { path }
    let name: String
    let path: String
    let kind: ProjectFileKind
}

enum ProjectFileKind: String, Codable, Equatable {
    case manifest
    case diagram
    case source
    case firmware

    var displayName: String {
        rawValue.capitalized
    }
}

struct RobotDiagram: Codable, Equatable {
    var parts: [PartDefinition]
    var wires: [WireDefinition]
}

struct PartDefinition: Identifiable, Codable, Equatable {
    let id: String
    let kind: PartKind
    var label: String
    let pins: [String]
    var position: CanvasPoint
    var attributes: [String: String]
    var pinBindings: [String: String]
}

enum PartKind: String, Codable, Equatable, CaseIterable, Identifiable {
    case board
    case led
    case resistor
    case button
    case buzzer
    case sevenSegment
    case potentiometer
    case shiftRegister
    case soilSensor
    case lightSensor
    case climateSensor
    case relay
    case oledDisplay
    case microphone
    case speaker
    case rgbLamp
    case lineSensor
    case motorDriver
    case motor
    case servo
    case digitalSensorModule
    case analogSensorModule
    case i2cSensorModule
    case uartSensorModule
    case visionSensorModule
    case distanceSensorModule

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .board:
            return "Board"
        case .led:
            return "LED"
        case .resistor:
            return "Resistor"
        case .button:
            return "Pushbutton"
        case .buzzer:
            return "Buzzer"
        case .sevenSegment:
            return "7-Segment"
        case .potentiometer:
            return "Potentiometer"
        case .shiftRegister:
            return "Shift Register"
        case .soilSensor:
            return "Soil Sensor"
        case .lightSensor:
            return "Light Sensor"
        case .climateSensor:
            return "Climate Sensor"
        case .relay:
            return "Relay"
        case .oledDisplay:
            return "OLED"
        case .microphone:
            return "Microphone"
        case .speaker:
            return "Speaker"
        case .rgbLamp:
            return "RGB Lamp"
        case .lineSensor:
            return "Line Sensor"
        case .motorDriver:
            return "Motor Driver"
        case .motor:
            return "DC Motor"
        case .servo:
            return "Servo"
        case .digitalSensorModule:
            return "Digital Sensor"
        case .analogSensorModule:
            return "Analog Sensor"
        case .i2cSensorModule:
            return "I2C Module"
        case .uartSensorModule:
            return "UART Module"
        case .visionSensorModule:
            return "Vision Module"
        case .distanceSensorModule:
            return "Distance Sensor"
        }
    }

    var defaultLabel: String {
        switch self {
        case .board:
            return "Arduino Uno"
        case .led:
            return "LED"
        case .resistor:
            return "220 ohm"
        case .button:
            return "Button"
        case .buzzer:
            return "Piezo Buzzer"
        case .sevenSegment:
            return "7-Segment Display"
        case .potentiometer:
            return "10k Pot"
        case .shiftRegister:
            return "74HC595"
        case .soilSensor:
            return "Soil Probe"
        case .lightSensor:
            return "LDR Sensor"
        case .climateSensor:
            return "DHT Sensor"
        case .relay:
            return "Relay Module"
        case .oledDisplay:
            return "OLED Display"
        case .microphone:
            return "Microphone"
        case .speaker:
            return "Speaker"
        case .rgbLamp:
            return "RGB Lamp"
        case .lineSensor:
            return "Line Sensor"
        case .motorDriver:
            return "Motor Driver"
        case .motor:
            return "DC Motor"
        case .servo:
            return "Servo"
        case .digitalSensorModule:
            return "Digital Sensor Module"
        case .analogSensorModule:
            return "Analog Sensor Module"
        case .i2cSensorModule:
            return "I2C Module"
        case .uartSensorModule:
            return "UART Module"
        case .visionSensorModule:
            return "Vision Sensor"
        case .distanceSensorModule:
            return "Distance Sensor"
        }
    }

    var paletteDescription: String {
        switch self {
        case .board:
            return "Main MCU board and pin source"
        case .led:
            return "Indicator output component"
        case .resistor:
            return "Inline passive component"
        case .button:
            return "Momentary digital input"
        case .buzzer:
            return "Simple tone output"
        case .sevenSegment:
            return "Common-cathode segment display"
        case .potentiometer:
            return "Three-pin analog divider"
        case .shiftRegister:
            return "Serial-in, parallel-out logic IC"
        case .soilSensor:
            return "Digital plant moisture indicator"
        case .lightSensor:
            return "Ambient light threshold sensor"
        case .climateSensor:
            return "Temperature and humidity threshold sensor"
        case .relay:
            return "Switches pumps and lamps"
        case .oledDisplay:
            return "Compact I2C status display"
        case .microphone:
            return "Voice/activity trigger sensor"
        case .speaker:
            return "Audio output sink"
        case .rgbLamp:
            return "Three-channel lamp output"
        case .lineSensor:
            return "Reflectance sensor for rover tracking"
        case .motorDriver:
            return "Dual H-bridge driver"
        case .motor:
            return "Wheel or pump motor"
        case .servo:
            return "PWM position servo"
        case .digitalSensorModule:
            return "Generic digital sensor breakout"
        case .analogSensorModule:
            return "Generic analog sensor breakout"
        case .i2cSensorModule:
            return "Generic I2C sensor or peripheral"
        case .uartSensorModule:
            return "Generic UART-connected module"
        case .visionSensorModule:
            return "Camera or AI vision coprocessor module"
        case .distanceSensorModule:
            return "Distance and ranging sensor module"
        }
    }

    var defaultPins: [String] {
        switch self {
        case .board:
            return BoardDefinition.arduinoUno.canvasPins
        case .led:
            return ["A", "K"]
        case .resistor:
            return ["1", "2"]
        case .button:
            return ["1", "2", "3", "4"]
        case .buzzer:
            return ["+", "-"]
        case .sevenSegment:
            return ["A", "B", "C", "D", "E", "F", "G", "DP", "COM"]
        case .potentiometer:
            return ["1", "2", "3"]
        case .shiftRegister:
            return ["VCC", "GND", "DS", "SH_CP", "ST_CP", "OE", "MR", "Q0", "Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7"]
        case .soilSensor, .lightSensor, .microphone, .lineSensor:
            return ["OUT", "VCC", "GND"]
        case .climateSensor:
            return ["DATA", "VCC", "GND"]
        case .relay:
            return ["IN", "VCC", "GND", "NO", "COM"]
        case .oledDisplay:
            return ["SDA", "SCL", "VCC", "GND"]
        case .speaker:
            return ["SIG", "GND"]
        case .rgbLamp:
            return ["R", "G", "B", "GND"]
        case .motorDriver:
            return ["ENA", "IN1", "IN2", "ENB", "IN3", "IN4", "VM", "GND", "L+", "L-", "R+", "R-"]
        case .motor:
            return ["+", "-"]
        case .servo:
            return ["SIG", "VCC", "GND"]
        case .digitalSensorModule:
            return ["SIG", "VCC", "GND"]
        case .analogSensorModule:
            return ["AOUT", "DOUT", "VCC", "GND"]
        case .i2cSensorModule:
            return ["SDA", "SCL", "VCC", "GND"]
        case .uartSensorModule:
            return ["TX", "RX", "VCC", "GND"]
        case .visionSensorModule:
            return ["TX", "RX", "VCC", "GND"]
        case .distanceSensorModule:
            return ["TRIG", "ECHO", "VCC", "GND"]
        }
    }

    var defaultAttributes: [String: String] {
        switch self {
        case .board:
            return ["footprint": "uno"]
        case .led:
            return ["color": "amber"]
        case .resistor:
            return ["value": "220"]
        case .button:
            return ["style": "momentary"]
        case .buzzer:
            return ["type": "piezo"]
        case .sevenSegment:
            return ["variant": "common-cathode", "color": "red"]
        case .potentiometer:
            return ["value": "10000"]
        case .shiftRegister:
            return ["family": "74HC595"]
        case .soilSensor:
            return ["mode": "dry-alert"]
        case .lightSensor:
            return ["mode": "dark-alert"]
        case .climateSensor:
            return ["threshold": "28", "humidityThreshold": "0.70"]
        case .relay:
            return ["load": "generic"]
        case .oledDisplay:
            return ["address": "0x3C"]
        case .microphone:
            return ["mode": "trigger"]
        case .speaker:
            return ["voice": "default"]
        case .rgbLamp:
            return ["style": "lamp"]
        case .lineSensor:
            return ["side": "left"]
        case .motorDriver:
            return ["family": "tb6612"]
        case .motor:
            return ["side": "left"]
        case .servo:
            return ["channel": "grip"]
        case .digitalSensorModule:
            return ["family": "gravity-digital", "catalog": "dfrobot.gravity.digital.generic"]
        case .analogSensorModule:
            return ["family": "gravity-analog", "catalog": "dfrobot.gravity.analog.generic"]
        case .i2cSensorModule:
            return ["family": "gravity-i2c", "catalog": "dfrobot.gravity.i2c.generic", "address": "0x00"]
        case .uartSensorModule:
            return ["family": "gravity-uart", "catalog": "dfrobot.gravity.uart.generic", "baud": "9600"]
        case .visionSensorModule:
            return ["family": "gravity-vision", "catalog": "dfrobot.gravity.vision.generic", "protocol": "uart"]
        case .distanceSensorModule:
            return ["family": "gravity-distance", "catalog": "dfrobot.gravity.ultrasonic", "rangeM": "4.0"]
        }
    }
}

struct WireDefinition: Identifiable, Codable, Equatable {
    let id: String
    let from: PinReference
    let to: PinReference
    var color: String
    var midX: Double?
}

struct PinReference: Codable, Equatable, Hashable {
    let partID: String
    let pin: String

    enum CodingKeys: String, CodingKey {
        case partID = "partId"
        case pin
    }
}

struct CanvasPoint: Codable, Equatable, Hashable {
    var x: Double
    var y: Double
}
