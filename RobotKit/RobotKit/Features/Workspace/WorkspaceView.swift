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
                        SchematicCanvasView(projectStore: projectStore, simulator: simulator)
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
