import SwiftUI

struct ProjectNavigatorView: View {
    @ObservedObject var projectStore: ProjectStore
    let onShowProjects: () -> Void
    let onShowParts: () -> Void

    private var sourceFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .source }
    }

    private var projectFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .manifest || $0.kind == .diagram || $0.kind == .physical }
    }

    private var artifactFiles: [ProjectFile] {
        projectStore.project.files.filter { $0.kind == .firmware || $0.kind == .cad }
    }

    var body: some View {
        VStack(spacing: 0) {
            navigatorHeader
            Divider()
            List {
                fileSection("Sources", files: sourceFiles)
                fileSection("Project Data", files: projectFiles)
                fileSection("Build Artifacts", files: artifactFiles)
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var navigatorHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text(projectStore.project.name)
                    .font(.title2.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 0)
                Menu {
                    Button("Projects", systemImage: "folder") {
                        onShowProjects()
                    }
                    Button("Parts", systemImage: "cpu") {
                        onShowParts()
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.white.opacity(0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            Text(projectStore.project.board.displayName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
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
        case .physical:
            return "cube.transparent"
        case .cad:
            return "cube"
        case .firmware:
            return "cpu"
        }
    }
}
