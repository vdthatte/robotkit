import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @ObservedObject var appModel: AppModel

    var body: some View {
        HSplitView {
            ProjectNavigatorView(
                projectStore: projectStore,
                onShowProjects: { appModel.showProjects() },
                onShowParts: { projectStore.isPartPalettePresented = true }
            )
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

            VStack(spacing: 0) {
                SimulatorToolbarView(
                    projectStore: projectStore,
                    simulator: simulator,
                    appModel: appModel
                )
                Divider()
                VSplitView {
                    HSplitView {
                        Group {
                            if projectStore.isPhysicalModeActive {
                                PhysicalCanvasView(projectStore: projectStore, simulator: simulator)
                            } else {
                                SchematicCanvasView(projectStore: projectStore, simulator: simulator)
                            }
                        }
                        .frame(minWidth: 520, idealWidth: 760)
                        if projectStore.isCodeEditorVisible {
                            CodeEditorView(projectStore: projectStore, simulator: simulator, appModel: appModel)
                                .frame(minWidth: 420, idealWidth: 560)
                        }
                        UtilitySidebarView(projectStore: projectStore, simulator: simulator)
                            .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                    }
                    if projectStore.isConsoleVisible {
                        ConsoleView(projectStore: projectStore, simulator: simulator)
                            .frame(minHeight: 180, idealHeight: 240, maxHeight: 320)
                    }
                }
            }
        }
        .sheet(isPresented: $projectStore.isPartPalettePresented) {
            AddPartPaletteView(projectStore: projectStore, appModel: appModel)
        }
        .sheet(isPresented: $appModel.isProjectLibraryPresented) {
            ProjectLibraryView(appModel: appModel)
        }
    }
}

struct CanvasModePicker: View {
    @ObservedObject var projectStore: ProjectStore
    var showsBackground = true

    var body: some View {
        HStack {
            Picker(
                "Canvas Mode",
                selection: Binding(
                    get: { projectStore.selectedCanvasMode },
                    set: { projectStore.selectCanvasMode($0) }
                )
            ) {
                ForEach(ProjectStore.CanvasMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: showsBackground ? 140 : 120)

            if showsBackground {
                Spacer()
            }
        }
        .padding(.horizontal, showsBackground ? 12 : 0)
        .padding(.vertical, showsBackground ? 10 : 0)
        .background {
            if showsBackground {
                Rectangle().fill(.bar)
            }
        }
    }
}
