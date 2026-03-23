import SwiftUI
import AppKit

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

            ConsoleTextView(
                text: activeLines.isEmpty ? emptyStateText : activeLines.joined(separator: "\n"),
                textColor: nsPanelColor
            )
            .background(.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))

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

    private var nsPanelColor: NSColor {
        switch selectedPanel {
        case 1:
            return .systemCyan
        case 2:
            return .systemOrange
        default:
            return .systemGreen
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

private struct ConsoleTextView: NSViewRepresentable {
    let text: String
    let textColor: NSColor

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 1)

        guard let textView = scrollView.documentView as? NSTextView else {
            return scrollView
        }

        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.backgroundColor = NSColor(calibratedWhite: 0.03, alpha: 1)
        textView.textColor = textColor
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.isHorizontallyResizable = true
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let documentMaxY = (scrollView.documentView?.bounds.maxY) ?? 0
            let isNearBottom = scrollView.contentView.bounds.maxY >= (documentMaxY - 40)
            textView.string = text
            textView.textColor = textColor
            if isNearBottom {
                textView.scrollToEndOfDocument(nil)
            }
        } else {
            textView.textColor = textColor
        }
    }
}
