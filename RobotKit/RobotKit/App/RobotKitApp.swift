import SwiftData
import SwiftUI

@main
struct RobotKitApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appModel: AppModel

    init() {
        let container = try! ModelContainer(for: ProjectRecord.self, CustomPartRecord.self)
        self.modelContainer = container
        _appModel = StateObject(wrappedValue: AppModel(modelContext: ModelContext(container)))
    }

    var body: some Scene {
        WindowGroup("RobotKit") {
            RootView()
                .environmentObject(appModel)
                .modelContainer(modelContainer)
                .frame(minWidth: 1200, minHeight: 780)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") {
                    appModel.showProjects()
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Projects…") {
                    appModel.showProjects()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }

            CommandMenu("Simulation") {
                Button("Build and Run") {
                    appModel.startSimulation()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Pause Simulation") {
                    appModel.pauseSimulation()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!appModel.simulator.isRunning)

                Button("Resume Simulation") {
                    appModel.resumeSimulation()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Reset Simulation") {
                    appModel.resetSimulation()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Step Frame") {
                    appModel.stepSimulation()
                }
                .keyboardShortcut("]", modifiers: [.command])

                Button("Stop Simulation") {
                    appModel.stopSimulation()
                }
                .keyboardShortcut(",", modifiers: [.command, .shift])
                .disabled(!appModel.simulator.isRunning)
            }

            CommandMenu("Selection") {
                Button("Delete Selection") {
                    appModel.deleteSelection()
                }
                .keyboardShortcut(.delete, modifiers: [])

                Button("Duplicate Selection") {
                    appModel.duplicateSelection()
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}
