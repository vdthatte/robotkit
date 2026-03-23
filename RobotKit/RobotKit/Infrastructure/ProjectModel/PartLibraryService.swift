import Foundation
import SwiftData

enum PartLibraryService {
    private static let bundledCatalogSubdirectory = "PartCatalog"
    private static let customPartFileExtension = "json"

    static func customPartsRootURL() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ProjectPersistenceError.appSupportUnavailable
        }

        let rootURL = appSupportURL
            .appendingPathComponent("RobotKit", isDirectory: true)
            .appendingPathComponent("Parts", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    static func customPartURL(for identifier: String) throws -> URL {
        try customPartsRootURL()
            .appendingPathComponent(identifier, isDirectory: false)
            .appendingPathExtension(customPartFileExtension)
    }

    static func loadPartCatalogEntries() -> [PartCatalogEntry] {
        let bundledEntries = bundledCatalogURLs().flatMap(loadEntries(from:))
        let customEntries = customCatalogURLs().flatMap(loadEntries(from:))
        let combined = bundledEntries + customEntries

        return deduplicatedEntries(combined).sorted { lhs, rhs in
            if lhs.vendor == rhs.vendor {
                if lhs.groupTitle == rhs.groupTitle {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.groupTitle.localizedCaseInsensitiveCompare(rhs.groupTitle) == .orderedAscending
            }

            return vendorSortOrder(lhs.vendor) < vendorSortOrder(rhs.vendor)
        }
    }

    static func saveCustomPart(_ entry: PartCatalogEntry, modelContext: ModelContext) throws {
        let destinationURL = try customPartURL(for: entry.id)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(PartCatalogDocument(entries: [entry]))
        try data.write(to: destinationURL, options: .atomic)

        let descriptor = FetchDescriptor<CustomPartRecord>()
        let existingRecords = try modelContext.fetch(descriptor)
        if let existing = existingRecords.first(where: { $0.partIdentifier == entry.id }) {
            existing.name = entry.displayName
            existing.groupTitle = entry.groupTitle
            existing.kindRawValue = entry.kind.rawValue
            existing.vendorRawValue = entry.vendor.rawValue
            existing.definitionPath = destinationURL.path
            existing.updatedAt = .now
        } else {
            modelContext.insert(
                CustomPartRecord(
                    partIdentifier: entry.id,
                    name: entry.displayName,
                    groupTitle: entry.groupTitle,
                    kindRawValue: entry.kind.rawValue,
                    vendorRawValue: entry.vendor.rawValue,
                    definitionPath: destinationURL.path
                )
            )
        }

        try modelContext.save()
    }

    static func syncCustomPartIndex(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<CustomPartRecord>()
        let existingRecords = (try? modelContext.fetch(descriptor)) ?? []
        let urls = customCatalogURLs()
        let definitions = urls.flatMap(loadEntries(from:))
        let recordsByIdentifier = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.partIdentifier, $0) })
        let definitionIDs = Set(definitions.map(\.id))

        for record in existingRecords where definitionIDs.contains(record.partIdentifier) == false {
            modelContext.delete(record)
        }

        for entry in definitions {
            guard let url = try? customPartURL(for: entry.id) else { continue }
            if let existing = recordsByIdentifier[entry.id] {
                existing.name = entry.displayName
                existing.groupTitle = entry.groupTitle
                existing.kindRawValue = entry.kind.rawValue
                existing.vendorRawValue = entry.vendor.rawValue
                existing.definitionPath = url.path
                existing.updatedAt = .now
            } else {
                modelContext.insert(
                    CustomPartRecord(
                        partIdentifier: entry.id,
                        name: entry.displayName,
                        groupTitle: entry.groupTitle,
                        kindRawValue: entry.kind.rawValue,
                        vendorRawValue: entry.vendor.rawValue,
                        definitionPath: url.path
                    )
                )
            }
        }

        try? modelContext.save()
    }

    private static func bundledCatalogURLs() -> [URL] {
        for bundle in [Bundle.main] + Bundle.allBundles + Bundle.allFrameworks {
            let urls = bundle.urls(forResourcesWithExtension: customPartFileExtension, subdirectory: bundledCatalogSubdirectory) ?? []
            if urls.isEmpty == false {
                return urls
            }
        }

        let sourceTreeURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent(bundledCatalogSubdirectory, isDirectory: true)

        let sourceURLs = ((try? FileManager.default.contentsOfDirectory(
            at: sourceTreeURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []).filter { $0.pathExtension == customPartFileExtension }
        if sourceURLs.isEmpty == false {
            return sourceURLs
        }

        return []
    }

    private static func customCatalogURLs() -> [URL] {
        guard let rootURL = try? customPartsRootURL() else { return [] }
        return ((try? FileManager.default.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? [])
        .filter { $0.pathExtension == customPartFileExtension }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private static func loadEntries(from url: URL) -> [PartCatalogEntry] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()

        if let document = try? decoder.decode(PartCatalogDocument.self, from: data) {
            return document.entries
        }

        if let entry = try? decoder.decode(PartCatalogEntry.self, from: data) {
            return [entry]
        }

        return []
    }

    private static func deduplicatedEntries(_ entries: [PartCatalogEntry]) -> [PartCatalogEntry] {
        var seenIDs = Set<String>()
        var deduplicated: [PartCatalogEntry] = []

        for entry in entries.reversed() where seenIDs.insert(entry.id).inserted {
            deduplicated.append(entry)
        }

        return deduplicated.reversed()
    }

    private static func vendorSortOrder(_ vendor: PartVendor) -> Int {
        switch vendor {
        case .robotKit:
            return 0
        case .dfrobot:
            return 1
        case .custom:
            return 2
        }
    }
}
