import SwiftUI

struct ProjectLibraryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case recent
        case create

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent:
                return "Recent"
            case .create:
                return "New"
            }
        }
    }

    enum TemplateScope: String, CaseIterable, Identifiable {
        case all
        case sensing
        case interactive
        case motion

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:
                return "All"
            case .sensing:
                return "Sensing"
            case .interactive:
                return "Interactive"
            case .motion:
                return "Motion"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel

    @State private var searchQuery = ""
    @State private var selectedProjectIdentifier: String?
    @State private var mode: Mode = .recent
    @State private var selectedTemplateScope: TemplateScope = .all
    @State private var selectedTemplate: ProjectTemplateKind?
    @State private var createBlankProject = true

    private var filteredProjects: [ProjectRecord] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return appModel.projects }
        return appModel.projects.filter { project in
            project.name.localizedCaseInsensitiveContains(query)
                || project.bundleURL.lastPathComponent.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredTemplates: [ProjectTemplateKind] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return ProjectTemplateKind.allCases.filter { template in
            let matchesScope = selectedTemplateScope.matches(template)
            let matchesQuery = query.isEmpty
                || template.displayName.localizedCaseInsensitiveContains(query)
                || template.description.localizedCaseInsensitiveContains(query)
            return matchesScope && matchesQuery
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
            if selectedTemplate == nil {
                selectedTemplate = filteredTemplates.first
            }
        }
        .onChange(of: filteredProjects.map(\.projectIdentifier)) { _, identifiers in
            if let selectedProjectIdentifier, identifiers.contains(selectedProjectIdentifier) == false {
                self.selectedProjectIdentifier = identifiers.first
            }
        }
        .onChange(of: filteredTemplates) { _, templates in
            if let selectedTemplate, templates.contains(selectedTemplate) == false {
                self.selectedTemplate = templates.first
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
                ForEach(Mode.allCases) { mode in
                    modePill(mode)
                }
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField(mode == .recent ? "Filter projects" : "Filter templates", text: $searchQuery)
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
        Group {
            switch mode {
            case .recent:
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
            case .create:
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ForEach(TemplateScope.allCases) { scope in
                            templateScopePill(scope)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            chooserSectionTitle("Start From Scratch")
                            blankProjectCard

                            chooserSectionTitle("Templates")
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 16)], spacing: 16) {
                                ForEach(filteredTemplates) { template in
                                    templateCard(template)
                                }
                            }

                            if let selectedTemplate, createBlankProject == false {
                                chooserSectionTitle("Description")
                                Text(selectedTemplate.description)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.white.opacity(0.03))
                                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            }
                        }
                        .padding(18)
                    }
                }
            }
        }
        .background(Color.white.opacity(0.015))
    }

    private var footer: some View {
        HStack {
            if mode == .create {
                Button("Back") {
                    mode = .recent
                    searchQuery = ""
                }
            } else {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            Spacer()

            if mode == .recent {
                Button("New") {
                    mode = .create
                    searchQuery = ""
                    createBlankProject = true
                    selectedTemplate = filteredTemplates.first
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
            } else {
                Button(createBlankProject ? "Create Blank Project" : "Create From Template") {
                    if createBlankProject {
                        appModel.newProject()
                    } else if let selectedTemplate {
                        appModel.loadTemplate(selectedTemplate)
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(createBlankProject == false && selectedTemplate == nil)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
    }

    private var blankProjectCard: some View {
        let isSelected = createBlankProject

        return Button {
            createBlankProject = true
        } label: {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.04))
                        .frame(width: 64, height: 64)
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Blank Project")
                        .font(.headline)
                    Text("Start from scratch with an empty Uno workspace.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.white.opacity(0.03))
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            createBlankProject = true
            appModel.newProject()
            dismiss()
        }
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

    private func modePill(_ mode: Mode) -> some View {
        let isActive = self.mode == mode

        return Button {
            self.mode = mode
            searchQuery = ""
        } label: {
            Text(mode.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(isActive ? Color.accentColor : Color.white.opacity(0.05)))
                .foregroundStyle(isActive ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func templateScopePill(_ scope: TemplateScope) -> some View {
        let isActive = selectedTemplateScope == scope

        return Button {
            selectedTemplateScope = scope
        } label: {
            Text(scope.title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(isActive ? Color.accentColor : Color.white.opacity(0.05)))
                .foregroundStyle(isActive ? .white : .secondary)
        }
        .buttonStyle(.plain)
    }

    private func chooserSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func templateCard(_ template: ProjectTemplateKind) -> some View {
        let isSelected = selectedTemplate == template && createBlankProject == false

        return Button {
            selectedTemplate = template
            createBlankProject = false
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.04))
                        .frame(width: 74, height: 74)
                    Image(systemName: template.projectLibrarySymbolName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isSelected ? Color.accentColor : Color.blue)
                }

                Text(template.displayName)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .onTapGesture(count: 2) {
            selectedTemplate = template
            createBlankProject = false
            appModel.loadTemplate(template)
            dismiss()
        }
    }
}

private extension ProjectLibraryView.TemplateScope {
    func matches(_ template: ProjectTemplateKind) -> Bool {
        switch self {
        case .all:
            return true
        case .sensing:
            return template == .plantMonitoring
        case .interactive:
            return template == .deskAssistant || template == .talkingLamp
        case .motion:
            return template == .lineFollower || template == .roboticHand
        }
    }
}

private extension ProjectTemplateKind {
    var projectLibrarySymbolName: String {
        switch self {
        case .plantMonitoring:
            return "leaf"
        case .deskAssistant:
            return "waveform.and.mic"
        case .talkingLamp:
            return "lamp.table"
        case .lineFollower:
            return "car.rear.road.lane.dashed"
        case .roboticHand:
            return "hand.raised"
        }
    }
}
