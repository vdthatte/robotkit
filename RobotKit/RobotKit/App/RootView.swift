import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appModel: AppModel

    var body: some View {
        WorkspaceView(
            projectStore: appModel.projectStore,
            simulator: appModel.simulator,
            appModel: appModel
        )
        .task {
            await appModel.simulator.bootstrapIfNeeded()
        }
    }
}
