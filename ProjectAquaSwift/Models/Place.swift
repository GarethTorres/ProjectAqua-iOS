//
//  Place.swift
//  ProjectAquaSwift
//

import Foundation
import CoreLocation

// MARK: - Resolution Confidence

enum ResolutionConfidence: String, Codable, Equatable {
    case high       // Strong name + location match
    case medium     // Good match but some uncertainty
    case low        // Weak match, needs review
    case unresolved // Could not find or rejected
    case manual     // User manually selected/confirmed
}

// MARK: - Place Model

struct Place: Identifiable, Codable, Equatable {
    let id: UUID
    var originalText: String
    var displayName: String
    var resolvedName: String?
    var latitude: Double?
    var longitude: Double?
    var locality: String?           // City
    var administrativeArea: String? // State/Province
    var country: String?
    var formattedAddress: String?
    var isVisited: Bool
    var day: Int?
    var geographicContext: String?
    var resolutionConfidence: ResolutionConfidence

    init(
        id: UUID = UUID(),
        originalText: String,
        displayName: String? = nil,
        resolvedName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        locality: String? = nil,
        administrativeArea: String? = nil,
        country: String? = nil,
        formattedAddress: String? = nil,
        isVisited: Bool = false,
        day: Int? = nil,
        geographicContext: String? = nil,
        resolutionConfidence: ResolutionConfidence = .unresolved
    ) {
        self.id = id
        self.originalText = originalText
        self.displayName = displayName ?? originalText
        self.resolvedName = resolvedName
        self.latitude = latitude
        self.longitude = longitude
        self.locality = locality
        self.administrativeArea = administrativeArea
        self.country = country
        self.formattedAddress = formattedAddress
        self.isVisited = isVisited
        self.day = day
        self.geographicContext = geographicContext
        self.resolutionConfidence = resolutionConfidence
    }

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }

    var isConfidentlyResolved: Bool {
        hasCoordinates && (resolutionConfidence == .high || resolutionConfidence == .manual)
    }

    var needsReview: Bool {
        resolutionConfidence == .low || resolutionConfidence == .unresolved
    }

    var locationSummary: String? {
        var parts: [String] = []
        if let locality = locality { parts.append(locality) }
        if let state = administrativeArea { parts.append(state) }
        if parts.isEmpty, let country = country { parts.append(country) }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    static func from(_ parsedDestination: ParsedDestination) -> Place {
        Place(
            id: parsedDestination.id,
            originalText: parsedDestination.originalText,
            displayName: parsedDestination.displayName,
            day: parsedDestination.day,
            geographicContext: parsedDestination.geographicContext,
            resolutionConfidence: .unresolved
        )
    }
}
