import SwiftUI

struct SimulationWorldView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Environment") {
                    sliderRow("Soil Moisture", value: simulator.environment.soilMoisture, range: 0...1, formatter: percent) {
                        value in simulator.updateEnvironment { state in state.soilMoisture = value.clamped(to: 0...1) }
                    }
                    sliderRow("Ambient Light", value: simulator.environment.ambientLight, range: 0...1, formatter: percent) {
                        value in simulator.updateEnvironment { state in state.ambientLight = value.clamped(to: 0...1) }
                    }
                    sliderRow("Temperature", value: simulator.environment.temperatureC, range: 10...40, formatter: { String(format: "%.0f C", $0) }) {
                        value in simulator.updateEnvironment { state in state.temperatureC = value.clamped(to: 10...40) }
                    }
                    sliderRow("Humidity", value: simulator.environment.humidity, range: 0...1, formatter: percent) {
                        value in simulator.updateEnvironment { state in state.humidity = value.clamped(to: 0...1) }
                    }
                    sliderRow("Voice Trigger", value: simulator.environment.voiceTriggerLevel, range: 0...1, formatter: percent) {
                        value in simulator.updateEnvironment { state in state.voiceTriggerLevel = value.clamped(to: 0...1) }
                    }
                    sliderRow("Hand Target", value: simulator.environment.handTarget, range: 0...1, formatter: percent) {
                        value in simulator.updateEnvironment { state in state.handTarget = value.clamped(to: 0...1) }
                    }
                    sliderRow("Track Offset", value: simulator.environment.baseLineOffset, range: -1...1, formatter: { String(format: "%.2f", $0) }) {
                        value in simulator.updateEnvironment { state in state.baseLineOffset = value.clamped(to: -1...1) }
                    }
                }

                if hasAny([.soilSensor, .lightSensor, .climateSensor, .relay, .oledDisplay]) {
                    GroupBox("Plant System") {
                        stateRow("Soil Alert", simulator.worldSnapshot.plant.soilAlert ? "Dry" : "Healthy")
                        stateRow("Light Alert", simulator.worldSnapshot.plant.lightAlert ? "Dark" : "Bright")
                        stateRow("Climate Alert", simulator.worldSnapshot.plant.climateAlert ? "Hot" : "Stable")
                        stateRow("Soil Level", percent(simulator.worldSnapshot.plant.soilPercent))
                        stateRow("Light Level", percent(simulator.worldSnapshot.plant.lightPercent))
                        stateRow("Climate", String(format: "%.0f C / %.0f%%", simulator.worldSnapshot.plant.temperatureC, simulator.worldSnapshot.plant.humidity * 100))
                        stateRow("Pump Relay", simulator.worldSnapshot.plant.relayActive ? "On" : "Off")
                        stateRow("OLED", simulator.worldSnapshot.display.oledSummary)
                        stateRow("Bus", simulator.worldSnapshot.display.protocolActivity)
                    }
                }

                if hasAny([.microphone, .speaker, .rgbLamp]) {
                    GroupBox("Assistant / Lamp") {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Assistant prompt", text: Binding(
                                get: { simulator.environment.assistantPrompt },
                                set: { value in simulator.updateEnvironment { $0.assistantPrompt = value } }
                            ))
                            .textFieldStyle(.roundedBorder)

                            Button("Send Prompt") {
                                simulator.triggerAssistantReply()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        stateRow("Reply", simulator.worldSnapshot.lamp.assistantReply)
                        stateRow("Speaker", simulator.worldSnapshot.lamp.speakerActive ? "Speaking" : "Idle")
                        levelRow("Speaker Level", simulator.worldSnapshot.lamp.speakerLevel)
                        levelRow("Lamp Red", simulator.worldSnapshot.lamp.redLevel)
                        levelRow("Lamp Green", simulator.worldSnapshot.lamp.greenLevel)
                        levelRow("Lamp Blue", simulator.worldSnapshot.lamp.blueLevel)
                        HStack {
                            Text("Lamp")
                                .foregroundStyle(.secondary)
                            Spacer()
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.robotLamp(red: simulator.worldSnapshot.lamp.red, green: simulator.worldSnapshot.lamp.green, blue: simulator.worldSnapshot.lamp.blue))
                                .frame(width: 56, height: 24)
                        }
                    }
                }

                if hasAny([.lineSensor, .motorDriver, .motor]) {
                    GroupBox("Rover World") {
                        stateRow("Left Sensor", simulator.worldSnapshot.rover.leftSensorOnLine ? "On line" : "Off line")
                        stateRow("Right Sensor", simulator.worldSnapshot.rover.rightSensorOnLine ? "On line" : "Off line")
                        stateRow("Left Motor", String(format: "%.1f", simulator.worldSnapshot.rover.leftMotorPower))
                        stateRow("Right Motor", String(format: "%.1f", simulator.worldSnapshot.rover.rightMotorPower))
                        stateRow("Lateral Offset", String(format: "%.2f", simulator.worldSnapshot.rover.lateralOffset))
                        stateRow("Heading", String(format: "%.1f deg", simulator.worldSnapshot.rover.heading))
                        RoverTrackPreview(snapshot: simulator.worldSnapshot)
                            .frame(height: 140)
                    }
                }

                if hasAny([.servo, .potentiometer]) {
                    GroupBox("Mechanism") {
                        stateRow("Servo Angle", String(format: "%.0f deg", simulator.worldSnapshot.mechanism.servoAngle))
                        stateRow("Hand State", simulator.worldSnapshot.mechanism.handClosed ? "Closed" : "Open")
                        stateRow("Grip Command", percent(simulator.worldSnapshot.mechanism.gripCommand))
                        HandPreview(snapshot: simulator.worldSnapshot)
                            .frame(height: 140)
                    }
                }
            }
            .padding()
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func hasAny(_ kinds: [PartKind]) -> Bool {
        projectStore.project.parts.contains { kinds.contains($0.kind) }
    }

    private func sliderRow(
        _ title: String,
        value: Double,
        range: ClosedRange<Double>,
        formatter: @escaping (Double) -> String,
        onSet: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatter(value))
                    .font(.caption.monospaced())
            }
            Slider(value: Binding(get: { value }, set: onSet), in: range)
        }
    }

    private func stateRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func levelRow(_ label: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(percent(value.clamped(to: 0...1)))
                    .font(.caption.monospaced())
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: proxy.size.width * value.clamped(to: 0...1))
                }
            }
            .frame(height: 8)
        }
    }

    private func percent(_ value: Double) -> String {
        "\(Int(value * 100))%"
    }
}

private struct RoverTrackPreview: View {
    let snapshot: SimulationWorldSnapshot

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.72))
                Rectangle()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: 18)
                    .offset(x: 0)
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 72, height: 34)
                    .overlay(
                        HStack(spacing: 20) {
                            Circle().fill(snapshot.rover.leftSensorOnLine ? Color.orange : Color.black.opacity(0.6)).frame(width: 10, height: 10)
                            Circle().fill(snapshot.rover.rightSensorOnLine ? Color.orange : Color.black.opacity(0.6)).frame(width: 10, height: 10)
                        }
                        .offset(y: -8)
                    )
                    .rotationEffect(.degrees(snapshot.rover.heading * 0.18))
                    .offset(x: snapshot.rover.lateralOffset * proxy.size.width * 0.28)
            }
        }
    }
}

private struct HandPreview: View {
    let snapshot: SimulationWorldSnapshot

    var body: some View {
        GeometryReader { _ in
            let closure = snapshot.mechanism.servoAngle / 180
            let angle = Angle(degrees: 18 - (closure * 44))
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.72))
                Capsule()
                    .fill(Color.gray.opacity(0.7))
                    .frame(width: 28, height: 78)
                HStack(spacing: 58) {
                    Rectangle()
                        .fill(Color.orange.opacity(0.9))
                        .frame(width: 14, height: 72)
                        .rotationEffect(angle, anchor: .bottom)
                    Rectangle()
                        .fill(Color.orange.opacity(0.9))
                        .frame(width: 14, height: 72)
                        .rotationEffect(.degrees(-angle.degrees), anchor: .bottom)
                }
                .offset(y: -8)
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
