import Foundation
import SwiftData

@Model
final class ProjectRecord {
    @Attribute(.unique) var projectIdentifier: String
    var name: String
    var bundlePath: String
    var createdAt: Date
    var updatedAt: Date
    var lastOpenedAt: Date
    var templateRawValue: String?

    init(
        projectIdentifier: String = UUID().uuidString,
        name: String,
        bundlePath: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastOpenedAt: Date = .now,
        templateRawValue: String? = nil
    ) {
        self.projectIdentifier = projectIdentifier
        self.name = name
        self.bundlePath = bundlePath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
        self.templateRawValue = templateRawValue
    }

    var bundleURL: URL {
        URL(fileURLWithPath: bundlePath, isDirectory: true)
    }
}

@Model
final class CustomPartRecord {
    @Attribute(.unique) var partIdentifier: String
    var name: String
    var groupTitle: String
    var kindRawValue: String
    var vendorRawValue: String
    var definitionPath: String
    var createdAt: Date
    var updatedAt: Date

    init(
        partIdentifier: String,
        name: String,
        groupTitle: String,
        kindRawValue: String,
        vendorRawValue: String,
        definitionPath: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.partIdentifier = partIdentifier
        self.name = name
        self.groupTitle = groupTitle
        self.kindRawValue = kindRawValue
        self.vendorRawValue = vendorRawValue
        self.definitionPath = definitionPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var definitionURL: URL {
        URL(fileURLWithPath: definitionPath)
    }
}
