import SwiftUI

struct RuntimeStatusView: View {
    @ObservedObject var simulator: SimulatorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusCard("Bootstrap", simulator.isBootstrapped ? "Ready" : "Pending")
            statusCard("Engine", simulator.engineName)
            statusCard("Loop", simulator.status.summary)
            statusCard("Frames", "\(simulator.frameCount)")
            statusCard("Cycles", "\(simulator.totalCycles)")
            statusCard("Serial", simulator.serialLines.last ?? "No serial output")
            statusCard("Build", simulator.buildDiagnostics.first ?? simulator.firmwareStatus)
            statusCard("Workspace", simulator.workspaceSummary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func statusCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
