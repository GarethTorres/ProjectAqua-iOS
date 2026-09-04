//
//  ParsedItinerary.swift
//  ProjectAquaSwift
//

import Foundation

// MARK: - Line Classification

enum ItineraryLineType: Equatable {
    case dayHeader(day: Int)
    case cityOrRegionContext
    case destination
    case stayContext
    case time
    case note
    case routeInstruction
    case empty
    case unknown
}

// MARK: - Parsed Line

struct ParsedLine: Identifiable {
    let id: UUID
    let originalText: String
    let trimmedText: String
    let lineType: ItineraryLineType
    let lineNumber: Int

    init(
        id: UUID = UUID(),
        originalText: String,
        trimmedText: String,
        lineType: ItineraryLineType,
        lineNumber: Int
    ) {
        self.id = id
        self.originalText = originalText
        self.trimmedText = trimmedText
        self.lineType = lineType
        self.lineNumber = lineNumber
    }
}

// MARK: - Parsed Destination

struct ParsedDestination: Identifiable, Equatable {
    let id: UUID
    let originalText: String
    var displayName: String
    var day: Int?
    var geographicContext: String?
    let sourceLine: Int
    var isSelected: Bool

    init(
        id: UUID = UUID(),
        originalText: String,
        displayName: String? = nil,
        day: Int? = nil,
        geographicContext: String? = nil,
        sourceLine: Int,
        isSelected: Bool = true
    ) {
        self.id = id
        self.originalText = originalText
        self.displayName = displayName ?? originalText
        self.day = day
        self.geographicContext = geographicContext
        self.sourceLine = sourceLine
        self.isSelected = isSelected
    }

    static func == (lhs: ParsedDestination, rhs: ParsedDestination) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Geographic Context

struct GeographicContext: Identifiable, Equatable {
    let id: UUID
    let name: String
    let normalizedName: String
    let sourceLine: Int

    init(
        id: UUID = UUID(),
        name: String,
        normalizedName: String? = nil,
        sourceLine: Int
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName ?? name.lowercased()
        self.sourceLine = sourceLine
    }
}

// MARK: - Parsed Itinerary

struct ParsedItinerary: Identifiable {
    let id: UUID
    let destinations: [ParsedDestination]
    let contexts: [GeographicContext]
    let ignoredLines: [ParsedLine]
    let detectedDays: [Int]
    let allLines: [ParsedLine]

    var destinationCount: Int { destinations.count }
    var contextCount: Int { contexts.count }
    var ignoredCount: Int { ignoredLines.count }

    init(
        id: UUID = UUID(),
        destinations: [ParsedDestination] = [],
        contexts: [GeographicContext] = [],
        ignoredLines: [ParsedLine] = [],
        detectedDays: [Int] = [],
        allLines: [ParsedLine] = []
    ) {
        self.id = id
        self.destinations = destinations
        self.contexts = contexts
        self.ignoredLines = ignoredLines
        self.detectedDays = detectedDays
        self.allLines = allLines
    }

    static let empty = ParsedItinerary()
}
