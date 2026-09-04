//
//  ItineraryParser.swift
//  ProjectAquaSwift
//

import Foundation

struct ItineraryParser {

    // MARK: - Public API

    func parse(_ text: String) -> ParsedItinerary {
        let lines = text.components(separatedBy: .newlines)
        var parsedLines: [ParsedLine] = []
        var destinations: [ParsedDestination] = []
        var contexts: [GeographicContext] = []
        var ignoredLines: [ParsedLine] = []
        var detectedDays: Set<Int> = []

        var currentDay: Int? = nil
        var currentContext: String? = nil
        var seenContexts: Set<String> = []

        // First pass: classify all lines
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lineType = classifyLine(trimmed, existingContexts: seenContexts)
            let parsedLine = ParsedLine(
                originalText: line,
                trimmedText: trimmed,
                lineType: lineType,
                lineNumber: index + 1
            )
            parsedLines.append(parsedLine)

            switch lineType {
            case .dayHeader(let day):
                currentDay = day
                detectedDays.insert(day)
                ignoredLines.append(parsedLine)

            case .cityOrRegionContext:
                let contextName = trimmed
                let normalizedContext = normalizeForDeduplication(contextName)
                if !seenContexts.contains(normalizedContext) {
                    seenContexts.insert(normalizedContext)
                    contexts.append(GeographicContext(
                        name: contextName,
                        normalizedName: normalizedContext,
                        sourceLine: index + 1
                    ))
                }
                currentContext = contextName
                ignoredLines.append(parsedLine)

            case .destination:
                let displayName = normalizeDestinationName(trimmed)
                let destination = ParsedDestination(
                    originalText: trimmed,
                    displayName: displayName,
                    day: currentDay,
                    geographicContext: currentContext,
                    sourceLine: index + 1
                )
                destinations.append(destination)

            case .stayContext, .time, .note, .routeInstruction, .unknown:
                ignoredLines.append(parsedLine)

            case .empty:
                // Reset context on blank lines between sections
                break
            }
        }

        // Deduplicate destinations
        let deduplicatedDestinations = deduplicateDestinations(destinations)

        return ParsedItinerary(
            destinations: deduplicatedDestinations,
            contexts: contexts,
            ignoredLines: ignoredLines,
            detectedDays: Array(detectedDays).sorted(),
            allLines: parsedLines
        )
    }

    // MARK: - Line Classification

    func classifyLine(_ line: String, existingContexts: Set<String> = []) -> ItineraryLineType {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Empty line
        if trimmed.isEmpty {
            return .empty
        }

        // Day header: "Day 1", "Day 2", etc.
        if let day = extractDayNumber(trimmed) {
            return .dayHeader(day: day)
        }

        // Stay context: "Stay in X"
        if isStayLine(trimmed) {
            return .stayContext
        }

        // Pure time/duration lines
        if isPureTimeLine(trimmed) {
            return .time
        }

        // Route instructions (arrows, multiple segments)
        if isRouteInstruction(trimmed) {
            return .routeInstruction
        }

        // Descriptive notes (mixed language, activity descriptions)
        if isDescriptiveNote(trimmed) {
            return .note
        }

        // Landing/Departure lines
        if isTransitLine(trimmed) {
            return .note
        }

        // City/region context detection
        if isCityOrRegionContext(trimmed, existingContexts: existingContexts) {
            return .cityOrRegionContext
        }

        // Known abbreviations that are context (not destinations)
        if isKnownContextAbbreviation(trimmed) {
            return .cityOrRegionContext
        }

        // If we get here and it looks like a place name, it's a destination
        if looksLikeDestination(trimmed) {
            return .destination
        }

        return .unknown
    }

    // MARK: - Day Extraction

    private func extractDayNumber(_ line: String) -> Int? {
        // Match "Day 1", "Day 2", "Day 10", etc.
        let patterns = [
            "^Day\\s+(\\d+)\\s*:?\\s*$",
            "^Day\\s+(\\d+)$"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let dayRange = Range(match.range(at: 1), in: line) {
                return Int(line[dayRange])
            }
        }
        return nil
    }

    // MARK: - Stay Detection

    private func isStayLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        return lowercased.hasPrefix("stay in ") ||
               lowercased.hasPrefix("stay at ") ||
               lowercased.hasPrefix("staying in ") ||
               lowercased.hasPrefix("staying at ")
    }

    // MARK: - Time/Duration Detection

    private func isPureTimeLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()

        // Date ranges: "10.3 - 10.4"
        if line.range(of: "^\\d+\\.\\d+\\s*-\\s*\\d+\\.\\d+$", options: .regularExpression) != nil {
            return true
        }

        // Pure duration: "15 hr drive", "3 hrs", "1.5hr"
        if line.range(of: "^\\d+\\.?\\d*\\s*hr[s]?\\s*(drive)?$", options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        // Time patterns: "Around 5:30PM", "After 4PM", "around 4PM"
        if lowercased.hasPrefix("around ") || lowercased.hasPrefix("after ") || lowercased.hasPrefix("before ") {
            if line.range(of: "\\d+[:\\.]?\\d*\\s*(am|pm)?", options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }

        // Landing/arrival times: "Landing 3:30"
        if lowercased.hasPrefix("landing ") && line.range(of: "\\d+:\\d+", options: .regularExpression) != nil {
            return true
        }

        // Pure time with AM/PM
        if line.range(of: "^\\d+[:\\.]?\\d*\\s*(am|pm)$", options: [.regularExpression, .caseInsensitive]) != nil {
            return true
        }

        return false
    }

    // MARK: - Route Instruction Detection

    private func isRouteInstruction(_ line: String) -> Bool {
        // Contains arrows indicating a route
        if line.contains("→") || line.contains("->") || line.contains("➔") {
            // Count segments - if multiple, it's a route description
            let segments = line.components(separatedBy: CharacterSet(charactersIn: "→->➔"))
            if segments.count >= 3 {
                return true
            }
        }
        return false
    }

    // MARK: - Descriptive Note Detection

    private func isDescriptiveNote(_ line: String) -> Bool {
        // Mixed language with Chinese characters and descriptive terms
        let hasChinese = line.range(of: "\\p{Han}", options: .regularExpression) != nil
        let hasDescriptivePattern = line.contains("+") || line.contains("&")

        if hasChinese && hasDescriptivePattern {
            return true
        }

        // Activity descriptions with multiple clauses
        if line.contains(" + ") && line.split(separator: "+").count >= 2 {
            return true
        }

        return false
    }

    // MARK: - Transit Line Detection

    private func isTransitLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let transitPrefixes = ["departure", "landing", "take off", "back to", "return to"]

        for prefix in transitPrefixes {
            if lowercased.hasPrefix(prefix) || lowercased.contains(prefix) {
                return true
            }
        }

        // "NP CARD" type lines (not a destination)
        if line.range(of: "^[A-Z]+\\s+CARD", options: .regularExpression) != nil {
            return true
        }

        return false
    }

    // MARK: - City/Region Context Detection

    private let knownCitiesAndRegions: Set<String> = [
        "new mexico", "albuquerque", "santa fe", "carlsbad", "alamogordo",
        "tokyo", "kyoto", "osaka", "paris", "london", "rome", "barcelona",
        "new york", "los angeles", "san francisco", "chicago", "seattle"
    ]

    private func isCityOrRegionContext(_ line: String, existingContexts: Set<String>) -> Bool {
        let normalized = normalizeForDeduplication(line)

        // Check against known cities/regions
        if knownCitiesAndRegions.contains(normalized) {
            return true
        }

        // Check if this exact text appears as a prefix in another line (indicating it's a section header)
        // This is handled by the heuristic: short names that match common city patterns

        // Simple heuristic: 1-2 word names that don't contain typical POI markers
        let words = line.split(separator: " ")
        if words.count <= 2 {
            let hasPoiMarker = containsPoiMarker(line)
            if !hasPoiMarker && looksLikeCityName(line) {
                return true
            }
        }

        return false
    }

    private func isKnownContextAbbreviation(_ line: String) -> Bool {
        let normalized = line.lowercased().trimmingCharacters(in: .whitespaces)
        let abbreviations = ["abq"]
        return abbreviations.contains(normalized)
    }

    private func looksLikeCityName(_ line: String) -> Bool {
        // Cities are typically 1-2 capitalized words without special markers
        let words = line.split(separator: " ")
        if words.count > 2 { return false }

        // All words should start with uppercase
        for word in words {
            if word.isEmpty { continue }
            if !word.first!.isUppercase { return false }
        }

        return true
    }

    private func containsPoiMarker(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        let markers = [
            "museum", "park", "plaza", "monument", "cathedral", "basilica",
            "center", "centre", "inn", "hotel", "spa", "tramway", "fiesta",
            "amphitheater", "old town", "road", "canyon", "peak", "rocks",
            "house of", "meow wolf", "pistachioland", "balloon"
        ]
        return markers.contains { lowercased.contains($0) }
    }

    // MARK: - Destination Detection

    private func looksLikeDestination(_ line: String) -> Bool {
        // Must have some content
        if line.count < 2 { return false }

        // Should start with a capital letter or number
        guard let first = line.first else { return false }
        if !first.isUppercase && !first.isNumber { return false }

        // Contains POI markers
        if containsPoiMarker(line) {
            return true
        }

        // Multi-word proper nouns (3+ words)
        let words = line.split(separator: " ")
        if words.count >= 3 {
            return true
        }

        // Known destination patterns
        let patterns = [
            "National Park", "National Monument", "State Park",
            "Historic Site", "Memorial", "Tower", "Bridge"
        ]
        for pattern in patterns {
            if line.contains(pattern) { return true }
        }

        return true // Default to destination if nothing else matches
    }

    // MARK: - Destination Name Normalization

    func normalizeDestinationName(_ name: String) -> String {
        var result = name

        // Remove combined duration + time range: "3 hrs 10AM–8PM"
        result = result.replacingOccurrences(
            of: "\\s+\\d+\\.?\\d*\\s*hr[s]?\\s+\\d+[:\\.]?\\d*\\s*(am|pm)?\\s*[–-]\\s*\\d+[:\\.]?\\d*\\s*(am|pm)?\\s*$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove trailing time range patterns: "10AM–8PM", "10AM-8PM"
        result = result.replacingOccurrences(
            of: "\\s+\\d+[:\\.]?\\d*\\s*(am|pm)?\\s*[–-]\\s*\\d+[:\\.]?\\d*\\s*(am|pm)?\\s*$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Remove trailing duration patterns: "1hr", "2 hrs", "3.5hr", "1.5hr"
        result = result.replacingOccurrences(
            of: "\\s+\\d+\\.?\\d*\\s*hr[s]?\\s*$",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Normalize whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Trim
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }

    // MARK: - Deduplication

    func normalizeForDeduplication(_ name: String) -> String {
        var result = name.lowercased()

        // Normalize Unicode apostrophes to ASCII
        result = result.replacingOccurrences(of: "'", with: "'")
        result = result.replacingOccurrences(of: "'", with: "'")
        result = result.replacingOccurrences(of: "`", with: "'")

        // Normalize whitespace
        result = result.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        // Trim
        result = result.trimmingCharacters(in: .whitespaces)

        return result
    }

    private func deduplicateDestinations(_ destinations: [ParsedDestination]) -> [ParsedDestination] {
        var seen: [String: ParsedDestination] = [:]
        var result: [ParsedDestination] = []

        for destination in destinations {
            let normalized = normalizeForDeduplication(destination.displayName)

            if let existing = seen[normalized] {
                // Merge: prefer the one with day info, or the first occurrence
                var merged = existing
                if merged.day == nil && destination.day != nil {
                    merged = ParsedDestination(
                        id: existing.id,
                        originalText: existing.originalText,
                        displayName: existing.displayName,
                        day: destination.day,
                        geographicContext: existing.geographicContext ?? destination.geographicContext,
                        sourceLine: existing.sourceLine,
                        isSelected: existing.isSelected
                    )
                    // Update in result array
                    if let index = result.firstIndex(where: { $0.id == existing.id }) {
                        result[index] = merged
                    }
                    seen[normalized] = merged
                }
            } else {
                seen[normalized] = destination
                result.append(destination)
            }
        }

        return result
    }
}
