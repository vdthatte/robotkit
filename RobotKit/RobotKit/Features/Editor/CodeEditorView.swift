import SwiftUI

struct CodeEditorView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(projectStore.selectedFilePath)
                        .font(.headline)
                    if let file = projectStore.project.files.first(where: { $0.path == projectStore.selectedFilePath }) {
                        Text(file.kind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button("New Source File") {
                    appModel.addSourceFile()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            if let file = projectStore.project.files.first(where: { $0.path == projectStore.selectedFilePath }) {
                if file.kind == .source {
                    VStack(spacing: 0) {
                        TextEditor(text: Binding(
                            get: { projectStore.sourceFiles[file.path] ?? "" },
                            set: { projectStore.selectFile(path: file.path); projectStore.updateSourceCode($0) }
                        ))
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(Color.black.opacity(0.92))
                        .foregroundStyle(.white)

                        if simulator.buildDiagnostics.isEmpty == false {
                            Divider()
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Build Diagnostics")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(Array(simulator.buildDiagnostics.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(.caption, design: .monospaced))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(12)
                            .background(Color.black.opacity(0.84))
                            .foregroundStyle(.orange)
                        }
                    }
                } else {
                    ScrollView {
                        Text(projectStore.fileContents(for: file))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                    }
                    .background(Color.black.opacity(0.92))
                    .foregroundStyle(.white.opacity(0.92))
                }
            } else {
                ContentUnavailableView("No File Selected", systemImage: "doc")
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
