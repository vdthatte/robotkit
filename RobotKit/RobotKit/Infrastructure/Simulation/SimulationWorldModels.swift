import Foundation
import SwiftUI

struct SimulationEnvironmentState: Equatable {
    var soilMoisture: Double = 0.35
    var ambientLight: Double = 0.55
    var temperatureC: Double = 24
    var humidity: Double = 0.55
    var voiceTriggerLevel: Double = 0
    var handTarget: Double = 0.5
    var baseLineOffset: Double = 0
    var assistantPrompt: String = "what's on my desk today?"
}

struct PlantMonitorOutputs: Equatable {
    var soilAlert = false
    var lightAlert = false
    var climateAlert = false
    var relayActive = false
    var soilPercent: Double = 0.35
    var lightPercent: Double = 0.55
    var temperatureC: Double = 24
    var humidity: Double = 0.55
}

struct LampOutputs: Equatable {
    var red = false
    var green = false
    var blue = false
    var speakerActive = false
    var redLevel: Double = 0
    var greenLevel: Double = 0
    var blueLevel: Double = 0
    var speakerLevel: Double = 0
    var assistantReply = "Awaiting prompt"
}

struct RoverOutputs: Equatable {
    var leftSensorOnLine = false
    var rightSensorOnLine = false
    var leftMotorPower: Double = 0
    var rightMotorPower: Double = 0
    var lateralOffset: Double = 0
    var heading: Double = 0
}

struct MechanismOutputs: Equatable {
    var servoAngle: Double = 0
    var handClosed = false
    var gripCommand: Double = 0
}

struct DisplayOutputs: Equatable {
    var oledSummary = "No bus activity"
    var protocolActivity = "Idle"
}

struct SimulationWorldSnapshot: Equatable {
    var plant = PlantMonitorOutputs()
    var lamp = LampOutputs()
    var rover = RoverOutputs()
    var mechanism = MechanismOutputs()
    var display = DisplayOutputs()
}

extension Color {
    static func robotLamp(red: Bool, green: Bool, blue: Bool) -> Color {
        Color(
            red: red ? 1 : 0.12,
            green: green ? 1 : 0.12,
            blue: blue ? 1 : 0.12
        )
    }
}
