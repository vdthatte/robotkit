import SwiftUI

struct ProjectLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel

    @State private var searchQuery = ""
    @State private var selectedProjectIdentifier: String?

    private var filteredProjects: [ProjectRecord] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return appModel.projects }
        return appModel.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(query)
                || project.bundleURL.lastPathComponent.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider()
                content
                Divider()
                footer
            }
            .frame(width: 840, height: 520)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .onAppear {
            if selectedProjectIdentifier == nil {
                selectedProjectIdentifier = filteredProjects.first?.projectIdentifier
            }
        }
        .onChange(of: filteredProjects.map(\.projectIdentifier)) { _, identifiers in
            if let selectedProjectIdentifier, identifiers.contains(selectedProjectIdentifier) == false {
                self.selectedProjectIdentifier = identifiers.first
            }
        }
        .onExitCommand {
            dismiss()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Projects")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor))
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .frame(width: 220)
            }
        }
        .padding(22)
    }

    private var content: some View {
        HSplitView {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filteredProjects, id: \.projectIdentifier) { project in
                        projectRow(project)
                    }
                }
                .padding(18)
            }
            .frame(minWidth: 360)

            VStack(alignment: .leading, spacing: 14) {
                if let selectedProject {
                    Text(selectedProject.name)
                        .font(.title3.weight(.semibold))

                    detailRow("Last Opened", value: selectedProject.lastOpenedAt.formatted(date: .abbreviated, time: .shortened))
                    detailRow("Updated", value: selectedProject.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    detailRow("Location", value: selectedProject.bundleURL.lastPathComponent)
                    detailRow("Template", value: templateTitle(for: selectedProject))

                    Spacer()
                } else {
                    ContentUnavailableView("No Project Selected", systemImage: "folder")
                }
            }
            .padding(22)
            .frame(minWidth: 280)
            .background(Color.white.opacity(0.02))
        }
        .background(Color.white.opacity(0.015))
    }

    private var footer: some View {
        HStack {
            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("New Project") {
                appModel.newProject()
                dismiss()
            }
            .buttonStyle(.bordered)

            Button("Open Project") {
                guard let selectedProject else { return }
                appModel.openProject(selectedProject)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedProject == nil)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private func projectRow(_ project: ProjectRecord) -> some View {
        let isSelected = selectedProjectIdentifier == project.projectIdentifier

        return Button {
            selectedProjectIdentifier = project.projectIdentifier
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(project.bundleURL.lastPathComponent)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    Text(project.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.white.opacity(0.03))
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            selectedProjectIdentifier = project.projectIdentifier
            appModel.openProject(project)
            dismiss()
        }
    }

    private func detailRow(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func templateTitle(for project: ProjectRecord) -> String {
        guard let rawValue = project.templateRawValue,
              let template = ProjectTemplateKind(rawValue: rawValue) else {
            return "Blank Project"
        }
        return template.displayName
    }

    private var selectedProject: ProjectRecord? {
        filteredProjects.first(where: { $0.projectIdentifier == selectedProjectIdentifier })
    }
}
