import SwiftUI

struct WorkspaceView: View {
    @ObservedObject var projectStore: ProjectStore
    @ObservedObject var simulator: SimulatorViewModel
    @ObservedObject var appModel: AppModel
    @State private var isTemplatePickerPresented = false

    var body: some View {
        HSplitView {
            ProjectNavigatorView(projectStore: projectStore)
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 300)

            VStack(spacing: 0) {
                SimulatorToolbarView(
                    projectStore: projectStore,
                    simulator: simulator,
                    appModel: appModel,
                    onShowProjects: { appModel.showProjects() },
                    onShowTemplates: { isTemplatePickerPresented = true },
                    onShowParts: { projectStore.isPartPalettePresented = true }
                )
                Divider()
                HSplitView {
                    SchematicCanvasView(projectStore: projectStore, simulator: simulator)
                        .frame(minWidth: 520, idealWidth: 760)
                    CodeEditorView(projectStore: projectStore, simulator: simulator, appModel: appModel)
                        .frame(minWidth: 420, idealWidth: 560)
                    UtilitySidebarView(projectStore: projectStore, simulator: simulator)
                        .frame(minWidth: 300, idealWidth: 340, maxWidth: 420)
                }
            }
        }
        .sheet(isPresented: $projectStore.isPartPalettePresented) {
            AddPartPaletteView(projectStore: projectStore, appModel: appModel)
        }
        .sheet(isPresented: $appModel.isProjectLibraryPresented) {
            ProjectLibraryView(appModel: appModel)
        }
        .sheet(isPresented: $isTemplatePickerPresented) {
            TemplatePickerView(appModel: appModel)
        }
    }
}
