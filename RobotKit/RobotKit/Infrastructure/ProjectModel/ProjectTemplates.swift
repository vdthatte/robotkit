import Foundation

enum ProjectTemplateKind: String, CaseIterable, Identifiable {
    case plantMonitoring
    case deskAssistant
    case talkingLamp
    case lineFollower
    case roboticHand

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plantMonitoring:
            return "Plant Monitoring"
        case .deskAssistant:
            return "AI Speaker"
        case .talkingLamp:
            return "Talking Lamp"
        case .lineFollower:
            return "Line-Following Rover"
        case .roboticHand:
            return "Robotic Hand"
        }
    }

    var description: String {
        switch self {
        case .plantMonitoring:
            return "Soil, light, climate, relay pump, and OLED status"
        case .deskAssistant:
            return "Microphone trigger, speaker, lamp ring, and status display"
        case .talkingLamp:
            return "Voice-reactive RGB lamp with speaker output"
        case .lineFollower:
            return "Dual line sensors, driver, motors, and rover world"
        case .roboticHand:
            return "Servo, feedback input, and grip mechanism panel"
        }
    }
}

enum ProjectTemplateFactory {
    static func makeProject(for template: ProjectTemplateKind) -> (project: RobotProject, sourceFiles: [String: String]) {
        switch template {
        case .plantMonitoring:
            return plantMonitoringProject()
        case .deskAssistant:
            return deskAssistantProject()
        case .talkingLamp:
            return talkingLampProject()
        case .lineFollower:
            return lineFollowerProject()
        case .roboticHand:
            return roboticHandProject()
        }
    }

    private static func baseProject(named name: String, observedPins: [String]) -> RobotProject {
        RobotProject(
            schemaVersion: 1,
            name: name,
            runtime: .javaScriptCore,
            board: .arduinoUno,
            demo: DemoDefinition(
                id: name.lowercased().replacingOccurrences(of: " ", with: "-"),
                name: name,
                binary: "blink.hex",
                source: "sketch.ino",
                observedPins: observedPins
            ),
            files: [
                ProjectFile(name: "project.json", path: "project.json", kind: .manifest),
                ProjectFile(name: "diagram.robotkit.json", path: "diagram.robotkit.json", kind: .diagram),
                ProjectFile(name: "sketch.ino", path: "sketch.ino", kind: .source),
                ProjectFile(name: "helpers.h", path: "helpers.h", kind: .source),
                ProjectFile(name: "blink.hex", path: "blink.hex", kind: .firmware)
            ],
            diagram: RobotDiagram(
                parts: [
                    PartDefinition(
                        id: "board",
                        kind: .board,
                        label: "Arduino Uno",
                        pins: BoardDefinition.arduinoUno.canvasPins,
                        position: .init(x: 220, y: 260),
                        attributes: ["footprint": "uno"],
                        pinBindings: [:]
                    )
                ],
                wires: []
            )
        )
    }

    private static func plantMonitoringProject() -> (RobotProject, [String: String]) {
        var project = baseProject(named: "Plant Monitoring", observedPins: ["D2", "D3", "D4", "D8", "D13"])
        project.diagram.parts.append(contentsOf: [
            PartDefinition(id: "soil1", kind: .soilSensor, label: "Soil Probe", pins: PartKind.soilSensor.defaultPins, position: .init(x: 480, y: 120), attributes: ["mode": "dry-alert"], pinBindings: [:]),
            PartDefinition(id: "light1", kind: .lightSensor, label: "Light Sensor", pins: PartKind.lightSensor.defaultPins, position: .init(x: 480, y: 260), attributes: ["mode": "dark-alert"], pinBindings: [:]),
            PartDefinition(id: "climate1", kind: .climateSensor, label: "Climate Sensor", pins: PartKind.climateSensor.defaultPins, position: .init(x: 480, y: 400), attributes: ["threshold": "28", "humidityThreshold": "0.70"], pinBindings: [:]),
            PartDefinition(id: "relay1", kind: .relay, label: "Pump Relay", pins: PartKind.relay.defaultPins, position: .init(x: 730, y: 200), attributes: ["load": "pump"], pinBindings: [:]),
            PartDefinition(id: "oled1", kind: .oledDisplay, label: "Status OLED", pins: PartKind.oledDisplay.defaultPins, position: .init(x: 730, y: 380), attributes: ["address": "0x3C"], pinBindings: [:])
        ])
        project.diagram.wires = [
            wire("board", "5V", "soil1", "VCC"), wire("board", "GND", "soil1", "GND"), wire("board", "D2", "soil1", "OUT"),
            wire("board", "5V", "light1", "VCC"), wire("board", "GND", "light1", "GND"), wire("board", "D3", "light1", "OUT"),
            wire("board", "5V", "climate1", "VCC"), wire("board", "GND", "climate1", "GND"), wire("board", "D4", "climate1", "DATA"),
            wire("board", "5V", "relay1", "VCC"), wire("board", "GND", "relay1", "GND"), wire("board", "D8", "relay1", "IN"),
            wire("board", "5V", "oled1", "VCC"), wire("board", "GND", "oled1", "GND"), wire("board", "A4", "oled1", "SDA"), wire("board", "A5", "oled1", "SCL")
        ]
        return (project, [
            "sketch.ino": """
            #include "helpers.h"

            const int SOIL_PIN = 2;
            const int LIGHT_PIN = 3;
            const int CLIMATE_PIN = 4;
            const int PUMP_RELAY = 8;

            void setup() {
              Serial.begin(115200);
              pinMode(SOIL_PIN, INPUT_PULLUP);
              pinMode(LIGHT_PIN, INPUT_PULLUP);
              pinMode(CLIMATE_PIN, INPUT_PULLUP);
              pinMode(PUMP_RELAY, OUTPUT);
            }

            void loop() {
              bool soilDry = digitalRead(SOIL_PIN) == HIGH;
              bool roomDark = digitalRead(LIGHT_PIN) == HIGH;
              bool roomHot = digitalRead(CLIMATE_PIN) == HIGH;

              digitalWrite(PUMP_RELAY, soilDry ? HIGH : LOW);
              Serial.println(formatPlantStatus(soilDry, roomDark, roomHot));
              delay(250);
            }
            """,
            "helpers.h": """
            #pragma once

            String formatPlantStatus(bool soilDry, bool roomDark, bool roomHot) {
              return String("plant dry=") + (soilDry ? "yes" : "no")
                + " dark=" + (roomDark ? "yes" : "no")
                + " hot=" + (roomHot ? "yes" : "no");
            }
            """
        ])
    }

    private static func deskAssistantProject() -> (RobotProject, [String: String]) {
        var project = baseProject(named: "Desk Assistant", observedPins: ["D2", "D9", "D10", "D11", "D12", "D13"])
        project.diagram.parts.append(contentsOf: [
            PartDefinition(id: "mic1", kind: .microphone, label: "Desk Mic", pins: PartKind.microphone.defaultPins, position: .init(x: 500, y: 130), attributes: ["mode": "trigger"], pinBindings: [:]),
            PartDefinition(id: "spk1", kind: .speaker, label: "Desk Speaker", pins: PartKind.speaker.defaultPins, position: .init(x: 720, y: 140), attributes: ["voice": "default"], pinBindings: [:]),
            PartDefinition(id: "lamp1", kind: .rgbLamp, label: "Ring Lamp", pins: PartKind.rgbLamp.defaultPins, position: .init(x: 720, y: 300), attributes: ["style": "desk-ring"], pinBindings: [:]),
            PartDefinition(id: "oled1", kind: .oledDisplay, label: "Assistant OLED", pins: PartKind.oledDisplay.defaultPins, position: .init(x: 500, y: 340), attributes: ["address": "0x3C"], pinBindings: [:])
        ])
        project.diagram.wires = [
            wire("board", "5V", "mic1", "VCC"), wire("board", "GND", "mic1", "GND"), wire("board", "D2", "mic1", "OUT"),
            wire("board", "GND", "spk1", "GND"), wire("board", "D9", "spk1", "SIG"),
            wire("board", "D10", "lamp1", "R"), wire("board", "D11", "lamp1", "G"), wire("board", "D12", "lamp1", "B"), wire("board", "GND", "lamp1", "GND"),
            wire("board", "5V", "oled1", "VCC"), wire("board", "GND", "oled1", "GND"), wire("board", "A4", "oled1", "SDA"), wire("board", "A5", "oled1", "SCL")
        ]
        return (project, [
            "sketch.ino": """
            #include "helpers.h"

            const int MIC_PIN = 2;
            const int SPEAKER_PIN = 9;
            const int LAMP_R = 10;
            const int LAMP_G = 11;
            const int LAMP_B = 12;

            void setup() {
              Serial.begin(115200);
              pinMode(MIC_PIN, INPUT_PULLUP);
              pinMode(SPEAKER_PIN, OUTPUT);
              pinMode(LAMP_R, OUTPUT);
              pinMode(LAMP_G, OUTPUT);
              pinMode(LAMP_B, OUTPUT);
            }

            void loop() {
              bool heardTrigger = digitalRead(MIC_PIN) == HIGH;
              renderAssistantLamp(heardTrigger);
              digitalWrite(SPEAKER_PIN, heardTrigger ? HIGH : LOW);
              if (heardTrigger) {
                Serial.println("assistant:listening");
              } else {
                Serial.println("assistant:idle");
              }
              delay(200);
            }
            """,
            "helpers.h": """
            #pragma once

            void renderAssistantLamp(bool active) {
              digitalWrite(10, active ? HIGH : LOW);
              digitalWrite(11, active ? HIGH : LOW);
              digitalWrite(12, active ? LOW : HIGH);
            }
            """
        ])
    }

    private static func talkingLampProject() -> (RobotProject, [String: String]) {
        var project = baseProject(named: "Talking Lamp", observedPins: ["D2", "D6", "D7", "D8", "D9"])
        project.diagram.parts.append(contentsOf: [
            PartDefinition(id: "mic1", kind: .microphone, label: "Voice Sensor", pins: PartKind.microphone.defaultPins, position: .init(x: 480, y: 160), attributes: ["mode": "trigger"], pinBindings: [:]),
            PartDefinition(id: "lamp1", kind: .rgbLamp, label: "Talking Lamp", pins: PartKind.rgbLamp.defaultPins, position: .init(x: 720, y: 180), attributes: ["style": "lamp"], pinBindings: [:]),
            PartDefinition(id: "spk1", kind: .speaker, label: "Lamp Speaker", pins: PartKind.speaker.defaultPins, position: .init(x: 720, y: 340), attributes: ["voice": "soft"], pinBindings: [:])
        ])
        project.diagram.wires = [
            wire("board", "5V", "mic1", "VCC"), wire("board", "GND", "mic1", "GND"), wire("board", "D2", "mic1", "OUT"),
            wire("board", "D6", "lamp1", "R"), wire("board", "D7", "lamp1", "G"), wire("board", "D8", "lamp1", "B"), wire("board", "GND", "lamp1", "GND"),
            wire("board", "D9", "spk1", "SIG"), wire("board", "GND", "spk1", "GND")
        ]
        return (project, [
            "sketch.ino": """
            const int MIC_PIN = 2;
            const int LAMP_R = 6;
            const int LAMP_G = 7;
            const int LAMP_B = 8;
            const int SPEAKER_PIN = 9;

            void setup() {
              Serial.begin(115200);
              pinMode(MIC_PIN, INPUT_PULLUP);
              pinMode(LAMP_R, OUTPUT);
              pinMode(LAMP_G, OUTPUT);
              pinMode(LAMP_B, OUTPUT);
              pinMode(SPEAKER_PIN, OUTPUT);
            }

            void loop() {
              bool speaking = digitalRead(MIC_PIN) == HIGH;
              digitalWrite(LAMP_R, speaking ? HIGH : LOW);
              digitalWrite(LAMP_G, speaking ? LOW : HIGH);
              digitalWrite(LAMP_B, speaking ? HIGH : LOW);
              digitalWrite(SPEAKER_PIN, speaking ? HIGH : LOW);
              Serial.println(speaking ? "lamp:speaking" : "lamp:quiet");
              delay(180);
            }
            """,
            "helpers.h": "// Talking lamp template\n"
        ])
    }

    private static func lineFollowerProject() -> (RobotProject, [String: String]) {
        var project = baseProject(named: "Line Follower", observedPins: ["D2", "D3", "D5", "D6", "D7", "D8"])
        project.diagram.parts.append(contentsOf: [
            PartDefinition(id: "lineL", kind: .lineSensor, label: "Left Sensor", pins: PartKind.lineSensor.defaultPins, position: .init(x: 470, y: 120), attributes: ["side": "left"], pinBindings: [:]),
            PartDefinition(id: "lineR", kind: .lineSensor, label: "Right Sensor", pins: PartKind.lineSensor.defaultPins, position: .init(x: 470, y: 260), attributes: ["side": "right"], pinBindings: [:]),
            PartDefinition(id: "driver1", kind: .motorDriver, label: "TB6612", pins: PartKind.motorDriver.defaultPins, position: .init(x: 720, y: 180), attributes: ["family": "tb6612"], pinBindings: [:]),
            PartDefinition(id: "motorL", kind: .motor, label: "Left Motor", pins: PartKind.motor.defaultPins, position: .init(x: 970, y: 120), attributes: ["side": "left"], pinBindings: [:]),
            PartDefinition(id: "motorR", kind: .motor, label: "Right Motor", pins: PartKind.motor.defaultPins, position: .init(x: 970, y: 260), attributes: ["side": "right"], pinBindings: [:])
        ])
        project.diagram.wires = [
            wire("board", "5V", "lineL", "VCC"), wire("board", "GND", "lineL", "GND"), wire("board", "D2", "lineL", "OUT"),
            wire("board", "5V", "lineR", "VCC"), wire("board", "GND", "lineR", "GND"), wire("board", "D3", "lineR", "OUT"),
            wire("board", "D5", "driver1", "ENA"), wire("board", "D6", "driver1", "IN1"), wire("board", "D7", "driver1", "IN2"),
            wire("board", "D5", "driver1", "ENB"), wire("board", "D8", "driver1", "IN3"), wire("board", "D7", "driver1", "IN4"),
            wire("board", "5V", "driver1", "VM"), wire("board", "GND", "driver1", "GND"),
            wire("driver1", "L+", "motorL", "+"), wire("driver1", "L-", "motorL", "-"),
            wire("driver1", "R+", "motorR", "+"), wire("driver1", "R-", "motorR", "-")
        ]
        return (project, [
            "sketch.ino": """
            const int LEFT_SENSOR = 2;
            const int RIGHT_SENSOR = 3;
            const int ENA = 5;
            const int IN1 = 6;
            const int IN2 = 7;
            const int ENB = 5;
            const int IN3 = 8;
            const int IN4 = 7;

            void setup() {
              Serial.begin(115200);
              pinMode(LEFT_SENSOR, INPUT_PULLUP);
              pinMode(RIGHT_SENSOR, INPUT_PULLUP);
              pinMode(ENA, OUTPUT);
              pinMode(IN1, OUTPUT);
              pinMode(IN2, OUTPUT);
              pinMode(ENB, OUTPUT);
              pinMode(IN3, OUTPUT);
              pinMode(IN4, OUTPUT);
            }

            void loop() {
              bool leftOnLine = digitalRead(LEFT_SENSOR) == LOW;
              bool rightOnLine = digitalRead(RIGHT_SENSOR) == LOW;

              digitalWrite(ENA, HIGH);
              digitalWrite(ENB, HIGH);

              if (leftOnLine && rightOnLine) {
                digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
                digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
                Serial.println("rover:forward");
              } else if (leftOnLine) {
                digitalWrite(IN1, LOW); digitalWrite(IN2, HIGH);
                digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
                Serial.println("rover:turn-left");
              } else if (rightOnLine) {
                digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
                digitalWrite(IN3, LOW); digitalWrite(IN4, HIGH);
                Serial.println("rover:turn-right");
              } else {
                digitalWrite(IN1, LOW); digitalWrite(IN2, LOW);
                digitalWrite(IN3, LOW); digitalWrite(IN4, LOW);
                Serial.println("rover:search");
              }
              delay(100);
            }
            """,
            "helpers.h": "// Line follower template\n"
        ])
    }

    private static func roboticHandProject() -> (RobotProject, [String: String]) {
        var project = baseProject(named: "Robotic Hand", observedPins: ["D2", "D9", "D13"])
        project.diagram.parts.append(contentsOf: [
            PartDefinition(id: "pot1", kind: .potentiometer, label: "Grip Input", pins: PartKind.potentiometer.defaultPins, position: .init(x: 480, y: 150), attributes: ["value": "10000"], pinBindings: [:]),
            PartDefinition(id: "servo1", kind: .servo, label: "Grip Servo", pins: PartKind.servo.defaultPins, position: .init(x: 740, y: 180), attributes: ["channel": "grip"], pinBindings: [:]),
            PartDefinition(id: "led1", kind: .led, label: "Grip LED", pins: PartKind.led.defaultPins, position: .init(x: 740, y: 340), attributes: ["color": "blue"], pinBindings: [:])
        ])
        project.diagram.wires = [
            wire("board", "5V", "pot1", "1"), wire("board", "GND", "pot1", "3"), wire("board", "D2", "pot1", "2"),
            wire("board", "5V", "servo1", "VCC"), wire("board", "GND", "servo1", "GND"), wire("board", "D9", "servo1", "SIG"),
            wire("board", "D13", "led1", "A"), wire("board", "GND", "led1", "K")
        ]
        return (project, [
            "sketch.ino": """
            const int GRIP_PIN = 2;
            const int SERVO_PIN = 9;
            const int LED_PIN = 13;

            void setup() {
              Serial.begin(115200);
              pinMode(GRIP_PIN, INPUT_PULLUP);
              pinMode(SERVO_PIN, OUTPUT);
              pinMode(LED_PIN, OUTPUT);
            }

            void loop() {
              bool closing = digitalRead(GRIP_PIN) == HIGH;
              digitalWrite(SERVO_PIN, closing ? HIGH : LOW);
              digitalWrite(LED_PIN, closing ? HIGH : LOW);
              Serial.println(closing ? "hand:close" : "hand:open");
              delay(120);
            }
            """,
            "helpers.h": "// Robotic hand template\n"
        ])
    }

    private static func wire(_ fromPart: String, _ fromPin: String, _ toPart: String, _ toPin: String) -> WireDefinition {
        WireDefinition(
            id: "wire-\(fromPart)-\(fromPin.lowercased())-\(toPart)-\(toPin.lowercased())",
            from: PinReference(partID: fromPart, pin: fromPin),
            to: PinReference(partID: toPart, pin: toPin),
            color: [fromPin, toPin].contains("GND") ? "black" : ([fromPin, toPin].contains("5V") ? "red" : "green"),
            midX: nil
        )
    }
}
