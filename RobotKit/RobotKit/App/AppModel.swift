import Combine
import Foundation
import SwiftData

@MainActor
final class AppModel: ObservableObject {
    @Published var projectStore = ProjectStore()
    @Published var simulator = SimulatorViewModel()
    @Published private(set) var projects: [ProjectRecord] = []
    @Published private(set) var customParts: [CustomPartRecord] = []
    @Published var isProjectLibraryPresented = false
    @Published private(set) var currentProjectIdentifier: String?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        bootstrapProjectLibrary()
    }

    convenience init() {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: ProjectRecord.self, CustomPartRecord.self, configurations: configuration)
        self.init(modelContext: ModelContext(container))
    }

    func startSimulation() {
        syncCurrentProjectRecord()
        simulator.rebuildAndStart(
            project: projectStore.project,
            workspaceURL: projectStore.lastSavedURL
        )
    }

    func resumeSimulation() {
        simulator.resume()
    }

    func stopSimulation() {
        simulator.stop()
    }

    func pauseSimulation() {
        simulator.pause()
    }

    func resetSimulation() {
        simulator.reset()
    }

    func stepSimulation() {
        simulator.step()
    }

    func newProject() {
        simulator.stop()

        let existingNames = projects.map(\.name)
        let name = ProjectLibraryService.suggestedUntitledName(existingNames: existingNames)
        let record = createRecord(name: name, template: nil)

        projectStore.newProject(named: name)
        projectStore.persist(to: record.bundleURL)
        touch(record)
        currentProjectIdentifier = record.projectIdentifier
        refreshProjects()
    }

    func showProjects() {
        syncProjectsFromDisk()
        refreshProjects()
        isProjectLibraryPresented = true
    }

    func hideProjects() {
        isProjectLibraryPresented = false
    }

    func openProject(_ record: ProjectRecord) {
        do {
            simulator.stop()
            try projectStore.openProject(at: record.bundleURL)
            currentProjectIdentifier = record.projectIdentifier
            touch(record)
            refreshProjects()
            isProjectLibraryPresented = false
            Task {
                await simulator.bootstrapIfNeeded()
            }
        } catch {
            projectStore.recordError(error.localizedDescription)
        }
    }

    func deleteSelection() {
        projectStore.deleteSelection()
        syncCurrentProjectRecord()
    }

    func duplicateSelection() {
        projectStore.duplicateSelection()
        syncCurrentProjectRecord()
    }

    func addSourceFile() {
        projectStore.addSourceFile()
        syncCurrentProjectRecord()
    }

    func loadTemplate(_ template: ProjectTemplateKind) {
        simulator.stop()

        let record = createRecord(name: template.displayName, template: template)
        projectStore.loadTemplate(template)
        projectStore.persist(to: record.bundleURL)
        currentProjectIdentifier = record.projectIdentifier
        touch(record)
        refreshProjects()
    }

    func saveCustomPart(_ draft: CustomPartDraft) throws {
        let entry = draft.makeEntry()
        try PartLibraryService.saveCustomPart(entry, modelContext: modelContext)
        PartCatalog.reload()
        refreshCustomParts()
    }

    private func bootstrapProjectLibrary() {
        PartLibraryService.syncCustomPartIndex(modelContext: modelContext)
        PartCatalog.reload()
        syncProjectsFromDisk()
        refreshProjects()
        refreshCustomParts()

        if let latestProject = projects.first {
            openProject(latestProject)
            return
        }

        newProject()
    }

    private func syncProjectsFromDisk() {
        let descriptor = FetchDescriptor<ProjectRecord>()
        let knownRecords = (try? modelContext.fetch(descriptor)) ?? []
        let recordsByPath = Dictionary(uniqueKeysWithValues: knownRecords.map { ($0.bundlePath, $0) })
        let existingPaths = Set((try? ProjectLibraryService.existingBundleURLs().map(\.path)) ?? [])

        for record in knownRecords where existingPaths.contains(record.bundlePath) == false {
            modelContext.delete(record)
        }

        let bundleURLs = (try? ProjectLibraryService.existingBundleURLs()) ?? []
        for bundleURL in bundleURLs {
            let modificationDate = (try? bundleURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .now

            if let record = recordsByPath[bundleURL.path] {
                record.updatedAt = modificationDate
                if let loadedProject = try? ProjectBundleLoader.loadProject(from: bundleURL) {
                    record.name = loadedProject.name
                }
                continue
            }

            let loadedProject = (try? ProjectBundleLoader.loadProject(from: bundleURL)) ?? .untitled()
            let record = ProjectRecord(
                projectIdentifier: bundleURL.deletingPathExtension().lastPathComponent,
                name: loadedProject.name,
                bundlePath: bundleURL.path,
                createdAt: modificationDate,
                updatedAt: modificationDate,
                lastOpenedAt: modificationDate
            )
            modelContext.insert(record)
        }

        try? modelContext.save()
    }

    private func refreshProjects() {
        let descriptor = FetchDescriptor<ProjectRecord>(
            sortBy: [
                SortDescriptor(\ProjectRecord.lastOpenedAt, order: .reverse),
                SortDescriptor(\ProjectRecord.updatedAt, order: .reverse)
            ]
        )
        projects = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func refreshCustomParts() {
        let descriptor = FetchDescriptor<CustomPartRecord>(
            sortBy: [
                SortDescriptor(\CustomPartRecord.updatedAt, order: .reverse),
                SortDescriptor(\CustomPartRecord.name, order: .forward)
            ]
        )
        customParts = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func createRecord(name: String, template: ProjectTemplateKind?) -> ProjectRecord {
        let projectIdentifier = UUID().uuidString.lowercased()
        let bundleURL = try! ProjectLibraryService.bundleURL(for: projectIdentifier)
        let record = ProjectRecord(
            projectIdentifier: projectIdentifier,
            name: name,
            bundlePath: bundleURL.path,
            templateRawValue: template?.rawValue
        )
        modelContext.insert(record)
        try? modelContext.save()
        return record
    }

    private func syncCurrentProjectRecord() {
        guard let record = currentRecord else { return }
        record.name = projectStore.project.name
        record.bundlePath = (projectStore.lastSavedURL ?? record.bundleURL).path
        record.updatedAt = .now
        try? modelContext.save()
        refreshProjects()
    }

    private func touch(_ record: ProjectRecord) {
        record.name = projectStore.project.name
        record.bundlePath = (projectStore.lastSavedURL ?? record.bundleURL).path
        record.updatedAt = .now
        record.lastOpenedAt = .now
        try? modelContext.save()
    }

    private var currentRecord: ProjectRecord? {
        guard let currentProjectIdentifier else { return nil }
        return projects.first(where: { $0.projectIdentifier == currentProjectIdentifier })
            ?? ((try? modelContext.fetch(FetchDescriptor<ProjectRecord>())) ?? []).first(where: { $0.projectIdentifier == currentProjectIdentifier })
    }
}
