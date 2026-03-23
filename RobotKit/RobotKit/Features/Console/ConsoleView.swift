import SwiftUI

struct ConsoleView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @State private var selectedPanel = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Console")
                    .font(.headline)
                Picker("", selection: $selectedPanel) {
                    Text("Runtime Log").tag(0)
                    Text("Serial").tag(1)
                    Text("Build").tag(2)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 420)
                Spacer()
                Button {
                    projectStore.isConsoleVisible = false
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .help("Hide Console")
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if activeLines.isEmpty {
                        Text(emptyStateText)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(activeLines.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(panelColor)

            if simulator.pinStates.isEmpty == false {
                HStack(spacing: 12) {
                    ForEach(simulator.pinStates.keys.sorted(), id: \.self) { pin in
                        Text("\(pin)=\(simulator.pinValue(for: pin))")
                            .font(.caption.monospaced())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.08), in: Capsule())
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var emptyStateText: String {
        switch selectedPanel {
        case 1:
            return "No serial output yet"
        case 2:
            return "No build diagnostics"
        default:
            return "No runtime log output yet"
        }
    }

    private var panelColor: Color {
        switch selectedPanel {
        case 1:
            return .cyan
        case 2:
            return .orange
        default:
            return .green
        }
    }

    private var activeLines: [String] {
        switch selectedPanel {
        case 1:
            return simulator.serialLines
        case 2:
            return simulator.buildDiagnostics
        default:
            return simulator.logs
        }
    }
}
