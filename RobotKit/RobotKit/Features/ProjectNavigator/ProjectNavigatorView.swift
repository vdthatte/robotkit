import SwiftUI

struct ProjectNavigatorView: View {
    @ObservedObject var projectStore: ProjectStore

    private var sourceFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .source }
    }

    private var projectFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .manifest || $0.kind == .diagram }
    }

    private var artifactFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .firmware }
    }

    var body: some View {
        List {
            fileSection("Sources", files: sourceFiles)
            fileSection("Project Data", files: projectFiles)
            fileSection("Build Artifacts", files: artifactFiles)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private func fileSection(_ title: String, files: [ProjectFile]) -> some View {
        if files.isEmpty == false {
            Section(title) {
                ForEach(files) { file in
                    Button {
                        projectStore.selectFile(path: file.path)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: iconName(for: file))
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(file.name)
                                Text(file.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(projectStore.selectedFilePath == file.path ? Color.accentColor.opacity(0.16) : Color.clear)
                }
            }
        }
    }

    private func iconName(for file: ProjectFile) -> String {
        switch file.kind {
        case .source:
            return "chevron.left.forwardslash.chevron.right"
        case .manifest:
            return "shippingbox"
        case .diagram:
            return "point.3.connected.trianglepath.dotted"
        case .firmware:
            return "cpu"
        }
    }
}
