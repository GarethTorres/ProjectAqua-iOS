//
//  Place.swift
//  ProjectAquaSwift
//

import Foundation

struct Place: Identifiable {
    let id: UUID
    var originalText: String
    var displayName: String
    var resolvedName: String?
    var latitude: Double?
    var longitude: Double?
    var isVisited: Bool
    var day: Int?

    init(
        id: UUID = UUID(),
        originalText: String,
        displayName: String? = nil,
        resolvedName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isVisited: Bool = false,
        day: Int? = nil
    ) {
        self.id = id
        self.originalText = originalText
        self.displayName = displayName ?? originalText
        self.resolvedName = resolvedName
        self.latitude = latitude
        self.longitude = longitude
        self.isVisited = isVisited
        self.day = day
    }
}

extension Place {
    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }
}
