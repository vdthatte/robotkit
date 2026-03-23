import SwiftUI

struct SimulatorToolbarView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 14) {
            simulationControls
            if projectStore.isConsoleVisible == false {
                toolbarDivider
                consoleControls
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var simulationControls: some View {
        HStack(spacing: 8) {
            toolbarIconButton(
                systemName: simulator.isRunning ? "stop.fill" : "play.fill",
                accessibilityLabel: simulator.isRunning ? "Stop Simulation" : "Build and Run",
                isPrimary: !simulator.isRunning
            ) {
                if simulator.isRunning {
                    appModel.stopSimulation()
                } else {
                    appModel.startSimulation()
                }
            }

            toolbarIconButton(
                systemName: simulator.isRunning ? "pause.fill" : "playpause.fill",
                accessibilityLabel: simulator.isRunning ? "Pause Simulation" : "Resume Simulation"
            ) {
                if simulator.isRunning {
                    appModel.pauseSimulation()
                } else {
                    appModel.resumeSimulation()
                }
            }
            .disabled(!simulator.isBootstrapped)

            toolbarIconButton(
                systemName: "forward.frame.fill",
                accessibilityLabel: "Step Frame"
            ) {
                appModel.stepSimulation()
            }
            .disabled(!simulator.isBootstrapped)

            toolbarIconButton(
                systemName: "arrow.clockwise",
                accessibilityLabel: "Reset Simulation"
            ) {
                appModel.resetSimulation()
            }
            .disabled(!simulator.isBootstrapped)
        }
    }

    private var consoleControls: some View {
        HStack(spacing: 8) {
            toolbarCapsuleButton("Show Console", systemName: "terminal") {
                projectStore.isConsoleVisible = true
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 24)
    }

    private func toolbarCapsuleButton(_ title: String, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemName)
                .font(.subheadline.weight(.medium))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func toolbarIconButton(
        systemName: String,
        accessibilityLabel: String,
        isPrimary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isPrimary ? Color.accentColor : Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isPrimary ? Color.accentColor.opacity(0.95) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .help(accessibilityLabel)
    }

}
