//
//  PlaceSearchService.swift
//  ProjectAquaSwift
//

import Foundation
import MapKit
import CoreLocation

// MARK: - Search Candidate

struct SearchCandidate: Identifiable {
    let id = UUID()
    let mapItem: MKMapItem
    let name: String
    let locality: String?
    let administrativeArea: String?
    let country: String?
    let countryCode: String?
    let coordinate: CLLocationCoordinate2D
    var score: Double = 0
    var disqualified: Bool = false
    var disqualificationReason: String?
}

// MARK: - Resolution Result

enum ResolutionResult {
    case resolved(SearchCandidate)
    case needsReview([SearchCandidate])
    case unresolved
}

// MARK: - Place Search Service

struct PlaceSearchService {

    // MARK: - Configuration

    private let maxCandidates = 10
    private let highConfidenceThreshold: Double = 0.80
    private let mediumConfidenceThreshold: Double = 0.60

    // Search region sizes (degrees latitude/longitude)
    private let citySearchSpan: Double = 0.5        // ~50km for city-level POIs
    private let regionSearchSpan: Double = 2.0      // ~200km for regional POIs
    private let stateSearchSpan: Double = 5.0       // ~500km for state-level search

    // Distance thresholds (in meters)
    private let localDistance: Double = 100_000        // 100 km - local area
    private let regionalDistance: Double = 300_000     // 300 km - same region
    private let stateDistance: Double = 800_000        // 800 km - same state

    // MARK: - Debug Logging

    private let debugEnabled = true

    private func log(_ message: String) {
        if debugEnabled {
            print("[PlaceSearch] \(message)")
        }
    }

    // MARK: - Public API

    func resolvePlaces(
        _ places: [Place],
        tripDestination: String?
    ) async -> [Place] {
        log("=== Starting resolution for \(places.count) places ===")
        log("Trip destination: \(tripDestination ?? "none")")

        // First, geocode the trip destination to get a broad anchor
        var tripRegionCenter: CLLocationCoordinate2D? = nil
        var tripExpectedState: String? = nil
        var tripExpectedCountry: String? = "United States" // Default assumption

        if let destination = tripDestination, !destination.isEmpty {
            if let geocoded = await geocodeLocation(destination) {
                tripRegionCenter = geocoded.coordinate
                tripExpectedState = geocoded.administrativeArea
                tripExpectedCountry = geocoded.country
                log("Trip region geocoded: \(geocoded.coordinate.latitude), \(geocoded.coordinate.longitude)")
                log("Expected state: \(tripExpectedState ?? "unknown")")
            }
        }

        var resolvedPlaces: [Place] = []

        for place in places {
            let resolved = await resolvePlace(
                place,
                tripDestination: tripDestination,
                tripRegionCenter: tripRegionCenter,
                tripExpectedState: tripExpectedState,
                tripExpectedCountry: tripExpectedCountry
            )
            resolvedPlaces.append(resolved)
        }

        log("=== Resolution complete ===")
        return resolvedPlaces
    }

    func resolvePlace(
        _ place: Place,
        tripDestination: String?,
        tripRegionCenter: CLLocationCoordinate2D?,
        tripExpectedState: String?,
        tripExpectedCountry: String?
    ) async -> Place {
        log("\n--- Resolving: \(place.displayName) ---")
        log("Geographic context: \(place.geographicContext ?? "none")")

        // Step 1: Determine the best search center
        let searchContext = await determineSearchContext(
            place: place,
            tripDestination: tripDestination,
            tripRegionCenter: tripRegionCenter
        )

        log("Search center: \(searchContext.center?.latitude ?? 0), \(searchContext.center?.longitude ?? 0)")
        log("Search query: \(searchContext.query)")
        log("Expected state: \(searchContext.expectedState ?? tripExpectedState ?? "any")")

        // Step 2: Search with geographic constraint
        let candidates = await searchWithRegion(
            query: searchContext.query,
            center: searchContext.center,
            span: searchContext.span
        )

        log("Found \(candidates.count) candidates")

        if candidates.isEmpty {
            log("No candidates found - marking as unresolved")
            return place
        }

        // Step 3: Validate and score candidates
        let expectedState = searchContext.expectedState ?? tripExpectedState
        let expectedCountry = tripExpectedCountry

        let validatedCandidates = validateCandidates(
            candidates,
            expectedState: expectedState,
            expectedCountry: expectedCountry,
            searchCenter: searchContext.center,
            placeName: place.displayName
        )

        // Log candidate details
        for (index, candidate) in validatedCandidates.prefix(5).enumerated() {
            let status = candidate.disqualified ? "DISQUALIFIED: \(candidate.disqualificationReason ?? "")" : "score: \(String(format: "%.2f", candidate.score))"
            log("  \(index + 1). \(candidate.name) - \(candidate.locality ?? "?"), \(candidate.administrativeArea ?? "?") - \(status)")
        }

        // Step 4: Select best valid candidate
        let eligibleCandidates = validatedCandidates.filter { !$0.disqualified }

        guard let best = eligibleCandidates.first else {
            log("All candidates disqualified - marking as needsReview")
            // Return place with low confidence so it shows "Needs Review"
            var unresolved = place
            unresolved.resolutionConfidence = .low
            return unresolved
        }

        log("Selected: \(best.name) - \(best.locality ?? "?"), \(best.administrativeArea ?? "?")")

        // Step 5: Determine confidence
        let confidence = determineConfidence(
            candidate: best,
            expectedState: expectedState,
            searchCenter: searchContext.center
        )

        log("Confidence: \(confidence)")

        // Step 6: Build resolved place
        var resolved = place
        resolved.latitude = best.coordinate.latitude
        resolved.longitude = best.coordinate.longitude
        resolved.resolvedName = best.name
        resolved.locality = best.locality
        resolved.administrativeArea = best.administrativeArea
        resolved.country = best.country
        resolved.resolutionConfidence = confidence

        var addressParts: [String] = []
        if let locality = best.locality { addressParts.append(locality) }
        if let state = best.administrativeArea { addressParts.append(state) }
        resolved.formattedAddress = addressParts.isEmpty ? nil : addressParts.joined(separator: ", ")

        return resolved
    }

    // MARK: - Manual Search (for Change Place)

    func searchForPlace(
        query: String,
        near anchor: CLLocation? = nil
    ) async -> [SearchCandidate] {
        let center = anchor?.coordinate
        let candidates = await searchWithRegion(
            query: query,
            center: center,
            span: stateSearchSpan // Use broader search for manual
        )

        // Sort by distance if we have an anchor
        if let anchor = anchor {
            return candidates.map { candidate in
                var c = candidate
                let location = CLLocation(
                    latitude: candidate.coordinate.latitude,
                    longitude: candidate.coordinate.longitude
                )
                let distance = anchor.distance(from: location)
                c.score = max(0, 1.0 - (distance / 1_000_000))
                return c
            }.sorted { $0.score > $1.score }
        }

        return candidates
    }

    // MARK: - Search Context Determination

    private struct SearchContext {
        let query: String
        let center: CLLocationCoordinate2D?
        let span: Double
        let expectedState: String?
    }

    private func determineSearchContext(
        place: Place,
        tripDestination: String?,
        tripRegionCenter: CLLocationCoordinate2D?
    ) async -> SearchContext {
        // Priority 1: Local geographic context (e.g., "Santa Fe")
        if let context = place.geographicContext, !context.isEmpty {
            // Build full context string for geocoding
            var contextString = context
            if let dest = tripDestination, !dest.isEmpty {
                // Append trip destination for better geocoding
                // e.g., "Santa Fe" + "New Mexico" = "Santa Fe, New Mexico"
                if !context.lowercased().contains(dest.lowercased()) {
                    contextString = "\(context), \(dest)"
                }
            }

            if let geocoded = await geocodeLocation(contextString) {
                let query = buildSearchQuery(
                    displayName: place.displayName,
                    context: context,
                    tripDestination: tripDestination
                )

                return SearchContext(
                    query: query,
                    center: geocoded.coordinate,
                    span: citySearchSpan,
                    expectedState: geocoded.administrativeArea
                )
            }
        }

        // Priority 2: Trip destination only
        if let dest = tripDestination, !dest.isEmpty {
            let query = "\(place.displayName), \(dest)"

            return SearchContext(
                query: query,
                center: tripRegionCenter,
                span: regionSearchSpan,
                expectedState: nil // Will use trip-level expected state
            )
        }

        // Priority 3: No context - global search (rare)
        return SearchContext(
            query: place.displayName,
            center: nil,
            span: 0,
            expectedState: nil
        )
    }

    // MARK: - Geocoding

    private struct GeocodedLocation {
        let coordinate: CLLocationCoordinate2D
        let administrativeArea: String?
        let country: String?
    }

    private func geocodeLocation(_ query: String) async -> GeocodedLocation? {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(query)

            guard let placemark = placemarks.first,
                  let location = placemark.location else {
                log("Geocoding failed for: \(query)")
                return nil
            }

            return GeocodedLocation(
                coordinate: location.coordinate,
                administrativeArea: placemark.administrativeArea,
                country: placemark.country
            )
        } catch {
            log("Geocoding error for '\(query)': \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Query Building

    func buildSearchQuery(
        displayName: String,
        context: String?,
        tripDestination: String?
    ) -> String {
        var components: [String] = [displayName]
        var added: Set<String> = [displayName.lowercased()]

        if let context = context, !context.isEmpty {
            let normalized = context.lowercased()
            if !added.contains(normalized) {
                components.append(context)
                added.insert(normalized)
            }
        }

        if let dest = tripDestination, !dest.isEmpty {
            let normalized = dest.lowercased()
            let alreadyIncluded = added.contains { $0.contains(normalized) || normalized.contains($0) }
            if !alreadyIncluded {
                components.append(dest)
            }
        }

        return components.joined(separator: ", ")
    }

    // MARK: - MapKit Search with Region

    private func searchWithRegion(
        query: String,
        center: CLLocationCoordinate2D?,
        span: Double
    ) async -> [SearchCandidate] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]

        // KEY FIX: Set the search region if we have a center
        if let center = center, span > 0 {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            request.region = region
            log("Search region set: center=(\(center.latitude), \(center.longitude)), span=\(span)")
        } else {
            log("No search region - using global search")
        }

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let items = Array(response.mapItems.prefix(maxCandidates))

            return items.compactMap { item -> SearchCandidate? in
                let coord = item.location.coordinate
                let placemark = item.placemark

                let countryName = placemark.countryCode.flatMap {
                    Locale.current.localizedString(forRegionCode: $0)
                }

                return SearchCandidate(
                    mapItem: item,
                    name: item.name ?? query,
                    locality: placemark.locality,
                    administrativeArea: placemark.administrativeArea,
                    country: countryName,
                    countryCode: placemark.countryCode,
                    coordinate: coord
                )
            }
        } catch {
            log("Search error: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Candidate Validation

    private func validateCandidates(
        _ candidates: [SearchCandidate],
        expectedState: String?,
        expectedCountry: String?,
        searchCenter: CLLocationCoordinate2D?,
        placeName: String
    ) -> [SearchCandidate] {
        var validated = candidates.map { candidate in
            var c = candidate

            // Calculate base score from name similarity
            c.score = calculateNameSimilarity(placeName, candidate.name)

            // Check for hard disqualifications

            // 1. Country mismatch (if we expect USA, reject non-USA)
            if let expected = expectedCountry?.lowercased(),
               expected.contains("united states") || expected.contains("usa") {
                if let candidateCountry = candidate.country?.lowercased(),
                   !candidateCountry.contains("united states") && candidateCountry != "usa" {
                    c.disqualified = true
                    c.disqualificationReason = "Wrong country: \(candidate.country ?? "unknown")"
                    return c
                }

                // Also check country code
                if let code = candidate.countryCode, code != "US" {
                    c.disqualified = true
                    c.disqualificationReason = "Wrong country code: \(code)"
                    return c
                }
            }

            // 2. State mismatch (hard rejection for different US states)
            if let expected = expectedState?.lowercased(),
               let candidateState = candidate.administrativeArea?.lowercased() {
                // Normalize state names
                let normalizedExpected = normalizeStateName(expected)
                let normalizedCandidate = normalizeStateName(candidateState)

                if !normalizedExpected.isEmpty && !normalizedCandidate.isEmpty {
                    if normalizedExpected != normalizedCandidate &&
                       !normalizedExpected.contains(normalizedCandidate) &&
                       !normalizedCandidate.contains(normalizedExpected) {
                        c.disqualified = true
                        c.disqualificationReason = "Wrong state: expected \(expectedState ?? ""), got \(candidate.administrativeArea ?? "")"
                        return c
                    }
                }
            }

            // 3. Distance check if we have a search center
            if let center = searchCenter {
                let candidateLocation = CLLocation(
                    latitude: candidate.coordinate.latitude,
                    longitude: candidate.coordinate.longitude
                )
                let centerLocation = CLLocation(
                    latitude: center.latitude,
                    longitude: center.longitude
                )
                let distance = centerLocation.distance(from: candidateLocation)

                // If very far from search center AND we had a specific expected state
                if distance > stateDistance && expectedState != nil {
                    c.disqualified = true
                    c.disqualificationReason = "Too far from search center: \(Int(distance / 1000))km"
                    return c
                }

                // Add distance bonus/penalty to score
                if distance < localDistance {
                    c.score += 0.3
                } else if distance < regionalDistance {
                    c.score += 0.1
                } else if distance > stateDistance {
                    c.score -= 0.3
                }
            }

            // 4. State match bonus
            if let expected = expectedState?.lowercased(),
               let candidateState = candidate.administrativeArea?.lowercased() {
                if normalizeStateName(expected) == normalizeStateName(candidateState) {
                    c.score += 0.3
                }
            }

            // 5. Locality match with context
            if let candidateLocality = candidate.locality?.lowercased() {
                // Check if locality matches what we expect
                if let expected = expectedState?.lowercased() {
                    if candidateLocality.contains(expected) || expected.contains(candidateLocality) {
                        c.score += 0.1
                    }
                }
            }

            c.score = max(0, min(1, c.score))
            return c
        }

        // Sort by score descending, with disqualified at the end
        validated.sort { lhs, rhs in
            if lhs.disqualified != rhs.disqualified {
                return !lhs.disqualified // Non-disqualified first
            }
            return lhs.score > rhs.score
        }

        return validated
    }

    // MARK: - State Name Normalization

    private func normalizeStateName(_ name: String) -> String {
        let stateAbbreviations: [String: String] = [
            "alabama": "al", "alaska": "ak", "arizona": "az", "arkansas": "ar",
            "california": "ca", "colorado": "co", "connecticut": "ct", "delaware": "de",
            "florida": "fl", "georgia": "ga", "hawaii": "hi", "idaho": "id",
            "illinois": "il", "indiana": "in", "iowa": "ia", "kansas": "ks",
            "kentucky": "ky", "louisiana": "la", "maine": "me", "maryland": "md",
            "massachusetts": "ma", "michigan": "mi", "minnesota": "mn", "mississippi": "ms",
            "missouri": "mo", "montana": "mt", "nebraska": "ne", "nevada": "nv",
            "new hampshire": "nh", "new jersey": "nj", "new mexico": "nm", "new york": "ny",
            "north carolina": "nc", "north dakota": "nd", "ohio": "oh", "oklahoma": "ok",
            "oregon": "or", "pennsylvania": "pa", "rhode island": "ri", "south carolina": "sc",
            "south dakota": "sd", "tennessee": "tn", "texas": "tx", "utah": "ut",
            "vermont": "vt", "virginia": "va", "washington": "wa", "west virginia": "wv",
            "wisconsin": "wi", "wyoming": "wy", "district of columbia": "dc"
        ]

        let lower = name.lowercased().trimmingCharacters(in: .whitespaces)

        // If it's already an abbreviation
        if lower.count == 2 {
            return lower
        }

        // Convert full name to abbreviation
        if let abbr = stateAbbreviations[lower] {
            return abbr
        }

        // Return as-is for matching
        return lower
    }

    // MARK: - Name Similarity

    private func calculateNameSimilarity(_ name1: String, _ name2: String) -> Double {
        let n1 = name1.lowercased()
        let n2 = name2.lowercased()

        if n1 == n2 { return 1.0 }
        if n1.contains(n2) || n2.contains(n1) { return 0.85 }

        // Word overlap
        let words1 = Set(n1.split(separator: " ").map(String.init))
        let words2 = Set(n2.split(separator: " ").map(String.init))
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)

        if union.isEmpty { return 0.3 }
        let jaccard = Double(intersection.count) / Double(union.count)

        return 0.3 + (jaccard * 0.5)
    }

    // MARK: - Confidence Determination

    private func determineConfidence(
        candidate: SearchCandidate,
        expectedState: String?,
        searchCenter: CLLocationCoordinate2D?
    ) -> ResolutionConfidence {
        // Already validated, so no hard contradictions

        var confidenceScore = candidate.score

        // State match is strong signal
        if let expected = expectedState,
           let candidateState = candidate.administrativeArea {
            if normalizeStateName(expected.lowercased()) == normalizeStateName(candidateState.lowercased()) {
                confidenceScore += 0.2
            }
        }

        // Distance from search center
        if let center = searchCenter {
            let location = CLLocation(latitude: candidate.coordinate.latitude, longitude: candidate.coordinate.longitude)
            let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
            let distance = centerLoc.distance(from: location)

            if distance < localDistance {
                confidenceScore += 0.1
            } else if distance > regionalDistance {
                confidenceScore -= 0.1
            }
        }

        // Has locality info
        if candidate.locality != nil {
            confidenceScore += 0.05
        }

        // Determine confidence level
        if confidenceScore >= highConfidenceThreshold {
            return .high
        } else if confidenceScore >= mediumConfidenceThreshold {
            return .medium
        } else {
            return .low
        }
    }
}
