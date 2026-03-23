import SwiftUI

struct TemplatePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appModel: AppModel

    @State private var searchQuery = ""
    @State private var selectedTemplate: ProjectTemplateKind? = .plantMonitoring

    private var filteredTemplates: [ProjectTemplateKind] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return ProjectTemplateKind.allCases }
        return ProjectTemplateKind.allCases.filter { template in
            template.displayName.localizedCaseInsensitiveContains(query)
                || template.description.localizedCaseInsensitiveContains(query)
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
            .frame(width: 860, height: 560)
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
        .onExitCommand {
            dismiss()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Choose a template for your new project:")
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
                chooserScopePill("RobotKit", isActive: true)
                chooserScopePill("Templates", isActive: false)
                chooserScopePill("Internal", isActive: false)
                Spacer()
                HStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $searchQuery)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color.black.opacity(0.18))
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .frame(width: 220)
            }
        }
        .padding(22)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                chooserSectionTitle("Robot Projects")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 16)], spacing: 16) {
                    ForEach(filteredTemplates) { template in
                        templateCard(template)
                    }
                }

                if let selectedTemplate {
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
            .padding(22)
        }
        .background(Color.white.opacity(0.015))
    }

    private var footer: some View {
        HStack {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Choose Template") {
                guard let selectedTemplate else { return }
                appModel.loadTemplate(selectedTemplate)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedTemplate == nil)
            .keyboardShortcut(.defaultAction)
        }
        .padding(18)
    }

    private func templateCard(_ template: ProjectTemplateKind) -> some View {
        let isSelected = selectedTemplate == template

        return Button {
            selectedTemplate = template
        } label: {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.white.opacity(0.04))
                        .frame(width: 74, height: 74)
                    Image(systemName: template.symbolName)
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
            appModel.loadTemplate(template)
            dismiss()
        }
    }

    private func chooserScopePill(_ title: String, isActive: Bool) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isActive ? Color.accentColor : Color.white.opacity(0.05))
            )
            .foregroundStyle(isActive ? Color.white : Color.secondary)
    }

    private func chooserSectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct UtilitySidebarView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $projectStore.selectedUtilitySidebarTab) {
                ForEach(ProjectStore.UtilitySidebarTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)
            .background(.bar)

            Group {
                switch projectStore.selectedUtilitySidebarTab {
                case .inspector:
                    InspectorView(projectStore: projectStore, simulator: simulator)
                case .runtime:
                    RuntimeStatusView(simulator: simulator)
                case .world:
                    SimulationWorldView(projectStore: projectStore, simulator: simulator)
                case .physical:
                    PhysicalInspectorView(projectStore: projectStore)
                }
            }
        }
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private extension ProjectTemplateKind {
    var symbolName: String {
        switch self {
        case .plantMonitoring:
            return "leaf.circle"
        case .deskAssistant:
            return "speaker.wave.3"
        case .talkingLamp:
            return "lamp.desk"
        case .lineFollower:
            return "car.side"
        case .roboticHand:
            return "figure.and.child.holdinghands"
        }
    }
}
