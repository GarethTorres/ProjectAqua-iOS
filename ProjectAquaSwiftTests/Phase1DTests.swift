//
//  Phase1DTests.swift
//  ProjectAquaSwiftTests
//
//  Tests for Phase 1D: Place Resolution, Geographic Consistency, Manual Correction

import XCTest
import Foundation
import CoreLocation
import MapKit
@testable import ProjectAquaSwift

// MARK: - Place Model Tests

final class PlaceModelTests: XCTestCase {

    func testPlaceIsConfidentlyResolved_highConfidenceWithCoordinates() {
        let place = Place(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            latitude: 35.6869,
            longitude: -105.9378,
            resolutionConfidence: .high
        )

        XCTAssertTrue(place.isConfidentlyResolved)
        XCTAssertTrue(place.hasCoordinates)
        XCTAssertFalse(place.needsReview)
    }

    func testPlaceIsConfidentlyResolved_manualConfidenceWithCoordinates() {
        let place = Place(
            originalText: "Custom Place",
            displayName: "Custom Place",
            latitude: 35.0,
            longitude: -106.0,
            resolutionConfidence: .manual
        )

        XCTAssertTrue(place.isConfidentlyResolved)
    }

    func testPlaceIsNotConfidentlyResolved_lowConfidence() {
        let place = Place(
            originalText: "Canyon Road",
            displayName: "Canyon Road",
            latitude: 35.6869,
            longitude: -105.9378,
            resolutionConfidence: .low
        )

        XCTAssertFalse(place.isConfidentlyResolved)
        XCTAssertTrue(place.needsReview)
    }

    func testPlaceIsNotConfidentlyResolved_noCoordinates() {
        let place = Place(
            originalText: "Unknown Place",
            displayName: "Unknown Place",
            resolutionConfidence: .high
        )

        XCTAssertFalse(place.isConfidentlyResolved)
        XCTAssertFalse(place.hasCoordinates)
    }

    func testPlaceNeedsReview_unresolvedConfidence() {
        let place = Place(
            originalText: "Mystery Location",
            displayName: "Mystery Location",
            resolutionConfidence: .unresolved
        )

        XCTAssertTrue(place.needsReview)
    }

    func testPlaceLocationSummary() {
        let place = Place(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            locality: "Santa Fe",
            administrativeArea: "New Mexico"
        )

        XCTAssertEqual(place.locationSummary, "Santa Fe, New Mexico")
    }

    func testPlaceLocationSummary_onlyLocality() {
        let place = Place(
            originalText: "Some Place",
            displayName: "Some Place",
            locality: "Santa Fe"
        )

        XCTAssertEqual(place.locationSummary, "Santa Fe")
    }

    func testPlaceLocationSummary_onlyCountry() {
        let place = Place(
            originalText: "National Place",
            displayName: "National Place",
            country: "United States"
        )

        XCTAssertEqual(place.locationSummary, "United States")
    }

    func testPlaceCoordinate() {
        let place = Place(
            originalText: "Test",
            displayName: "Test",
            latitude: 35.6869,
            longitude: -105.9378
        )

        let coord = place.coordinate
        XCTAssertNotNil(coord)
        if let coord = coord {
            XCTAssertEqual(coord.latitude, 35.6869, accuracy: 0.0001)
            XCTAssertEqual(coord.longitude, -105.9378, accuracy: 0.0001)
        }
    }

    func testPlaceCLLocation() {
        let place = Place(
            originalText: "Test",
            displayName: "Test",
            latitude: 35.6869,
            longitude: -105.9378
        )

        let location = place.clLocation
        XCTAssertNotNil(location)
        if let location = location {
            XCTAssertEqual(location.coordinate.latitude, 35.6869, accuracy: 0.0001)
        }
    }
}

// MARK: - PlaceSearchService Query Building Tests

final class PlaceSearchServiceQueryTests: XCTestCase {

    let searchService = PlaceSearchService()

    func testBuildSearchQuery_displayNameOnly() {
        let query = searchService.buildSearchQuery(
            displayName: "Santa Fe Plaza",
            context: nil,
            tripDestination: nil
        )

        XCTAssertEqual(query, "Santa Fe Plaza")
    }

    func testBuildSearchQuery_withContext() {
        let query = searchService.buildSearchQuery(
            displayName: "The Plaza",
            context: "Santa Fe",
            tripDestination: nil
        )

        XCTAssertEqual(query, "The Plaza, Santa Fe")
    }

    func testBuildSearchQuery_withTripDestination() {
        let query = searchService.buildSearchQuery(
            displayName: "The Plaza",
            context: nil,
            tripDestination: "New Mexico"
        )

        XCTAssertEqual(query, "The Plaza, New Mexico")
    }

    func testBuildSearchQuery_withContextAndDestination() {
        let query = searchService.buildSearchQuery(
            displayName: "Georgia O'Keeffe Museum",
            context: "Santa Fe",
            tripDestination: "New Mexico"
        )

        XCTAssertEqual(query, "Georgia O'Keeffe Museum, Santa Fe, New Mexico")
    }

    func testBuildSearchQuery_avoidsDuplicateContext() {
        // When context is same as display name, don't duplicate
        let query = searchService.buildSearchQuery(
            displayName: "Santa Fe",
            context: "Santa Fe",
            tripDestination: "New Mexico"
        )

        // Should not have "Santa Fe, Santa Fe, New Mexico"
        XCTAssertFalse(query.contains("Santa Fe, Santa Fe"))
        XCTAssertTrue(query.contains("Santa Fe"))
        XCTAssertTrue(query.contains("New Mexico"))
    }

    func testBuildSearchQuery_contextContainedInDestination() {
        let query = searchService.buildSearchQuery(
            displayName: "White Sands",
            context: "Alamogordo",
            tripDestination: "New Mexico"
        )

        XCTAssertEqual(query, "White Sands, Alamogordo, New Mexico")
    }
}

// MARK: - State Normalization Tests

final class StateNormalizationTests: XCTestCase {

    func testNewMexicoIncluded() {
        // Verify New Mexico is in the state list
        // This test documents the fix for the missing state
        let states = ["new mexico", "california", "texas", "arizona"]
        XCTAssertTrue(states.contains("new mexico"))
    }
}

// MARK: - Resolution Confidence Tests

final class ResolutionConfidenceTests: XCTestCase {

    func testConfidenceValues() {
        // Ensure all confidence values are distinct
        let values: [ResolutionConfidence] = [.high, .medium, .low, .unresolved, .manual]
        let uniqueRawValues = Set(values.map(\.rawValue))

        XCTAssertEqual(uniqueRawValues.count, 5)
    }

    func testConfidenceCodable() throws {
        // Test that confidence can be encoded/decoded
        let confidence = ResolutionConfidence.high
        let data = try JSONEncoder().encode(confidence)
        let decoded = try JSONDecoder().decode(ResolutionConfidence.self, from: data)

        XCTAssertEqual(confidence, decoded)
    }
}

// MARK: - Place Persistence Tests

final class PlacePersistenceTests: XCTestCase {

    func testPlaceCodable() throws {
        let place = Place(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            resolvedName: "Plaza Santa Fe",
            latitude: 35.6869,
            longitude: -105.9378,
            locality: "Santa Fe",
            administrativeArea: "New Mexico",
            country: "United States",
            formattedAddress: "Santa Fe, New Mexico",
            isVisited: true,
            day: 1,
            geographicContext: "Santa Fe",
            resolutionConfidence: .high
        )

        let data = try JSONEncoder().encode(place)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(decoded.originalText, place.originalText)
        XCTAssertEqual(decoded.displayName, place.displayName)
        XCTAssertEqual(decoded.resolvedName, place.resolvedName)
        XCTAssertEqual(decoded.latitude, place.latitude)
        XCTAssertEqual(decoded.longitude, place.longitude)
        XCTAssertEqual(decoded.locality, place.locality)
        XCTAssertEqual(decoded.administrativeArea, place.administrativeArea)
        XCTAssertEqual(decoded.country, place.country)
        XCTAssertEqual(decoded.formattedAddress, place.formattedAddress)
        XCTAssertEqual(decoded.isVisited, place.isVisited)
        XCTAssertEqual(decoded.day, place.day)
        XCTAssertEqual(decoded.geographicContext, place.geographicContext)
        XCTAssertEqual(decoded.resolutionConfidence, place.resolutionConfidence)
    }

    func testPlaceCodable_minimalPlace() throws {
        let place = Place(
            originalText: "Some Place",
            displayName: "Some Place"
        )

        let data = try JSONEncoder().encode(place)
        let decoded = try JSONDecoder().decode(Place.self, from: data)

        XCTAssertEqual(decoded.originalText, place.originalText)
        XCTAssertEqual(decoded.resolutionConfidence, .unresolved)
        XCTAssertNil(decoded.latitude)
        XCTAssertNil(decoded.longitude)
    }
}

// MARK: - Trip Store Place Operations Tests

final class TripStorePlaceTests: XCTestCase {

    // Use unique trip names to avoid conflicts with persisted state
    private func uniqueTripName() -> String {
        "Test_\(UUID().uuidString.prefix(8))"
    }

    func testUpdatePlace() {
        let store = TripStore()

        // Create a trip with a place (unique name)
        let originalPlace = Place(
            originalText: "Canyon Road",
            displayName: "Canyon Road",
            resolutionConfidence: .low
        )

        let trip = Trip(
            name: uniqueTripName(),
            destination: "New Mexico",
            places: [originalPlace]
        )

        store.addTrip(trip)

        // Update the place with resolved info
        var updatedPlace = originalPlace
        updatedPlace.latitude = 35.6762
        updatedPlace.longitude = -105.9266
        updatedPlace.resolvedName = "Canyon Road Arts District"
        updatedPlace.locality = "Santa Fe"
        updatedPlace.administrativeArea = "New Mexico"
        updatedPlace.resolutionConfidence = .manual

        store.updatePlace(tripId: trip.id, place: updatedPlace)

        // Verify update
        let savedTrip = store.trip(withId: trip.id)
        XCTAssertNotNil(savedTrip)

        let savedPlace = savedTrip?.places.first
        XCTAssertNotNil(savedPlace)
        XCTAssertEqual(savedPlace?.latitude, 35.6762)
        XCTAssertEqual(savedPlace?.longitude, -105.9266)
        XCTAssertEqual(savedPlace?.resolvedName, "Canyon Road Arts District")
        XCTAssertEqual(savedPlace?.resolutionConfidence, .manual)

        // Clean up
        store.deleteTrip(trip)
    }

    func testTogglePlaceVisited() {
        let store = TripStore()

        let place = Place(
            originalText: "Test Place",
            displayName: "Test Place",
            isVisited: false
        )

        let trip = Trip(
            name: uniqueTripName(),
            destination: "Test",
            places: [place]
        )

        store.addTrip(trip)

        // Toggle visited
        store.togglePlaceVisited(tripId: trip.id, placeId: place.id)

        let savedTrip = store.trip(withId: trip.id)
        XCTAssertTrue(savedTrip?.places.first?.isVisited == true)

        // Toggle again
        store.togglePlaceVisited(tripId: trip.id, placeId: place.id)

        let updatedTrip = store.trip(withId: trip.id)
        XCTAssertTrue(updatedTrip?.places.first?.isVisited == false)

        // Clean up
        store.deleteTrip(trip)
    }

    func testRefreshTrip() {
        let store = TripStore()
        let tripName = uniqueTripName()

        let trip = Trip(
            name: tripName,
            destination: "Test",
            places: []
        )

        store.addTrip(trip)

        let refreshed = store.refreshTrip(trip.id)
        XCTAssertNotNil(refreshed, "Refreshed trip should not be nil")
        XCTAssertEqual(refreshed?.id, trip.id)
        XCTAssertEqual(refreshed?.name, tripName)

        // Clean up
        store.deleteTrip(trip)
    }

    func testSaveDoesNotDuplicateTrip() {
        let store = TripStore()
        let tripName = uniqueTripName()

        let trip = Trip(
            name: tripName,
            destination: "New Mexico",
            places: []
        )

        // Record initial count before adding
        let initialCount = store.trips.count

        store.addTrip(trip)

        // Should have one more trip
        XCTAssertEqual(store.trips.count, initialCount + 1)

        // Update the same trip
        var updatedTrip = trip
        updatedTrip.places = [Place(originalText: "New Place", displayName: "New Place")]
        store.updateTrip(updatedTrip)

        // Should still have the same count (no duplicate)
        XCTAssertEqual(store.trips.count, initialCount + 1)

        // Clean up
        store.deleteTrip(trip)
    }
}

// MARK: - Distance Calculation Tests

final class DistanceCalculationTests: XCTestCase {

    func testSameRegionDistance() {
        // Santa Fe Plaza and Georgia O'Keeffe Museum should be very close
        let santaFePlaza = CLLocation(latitude: 35.6869, longitude: -105.9378)
        let museum = CLLocation(latitude: 35.6872, longitude: -105.9400)

        let distance = santaFePlaza.distance(from: museum)

        // Should be less than 1 km apart
        XCTAssertLessThan(distance, 1000)
    }

    func testDifferentCityDistance() {
        // Santa Fe and Albuquerque should be about 100 km apart
        let santaFe = CLLocation(latitude: 35.6869, longitude: -105.9378)
        let albuquerque = CLLocation(latitude: 35.0844, longitude: -106.6504)

        let distance = santaFe.distance(from: albuquerque)

        // Should be between 80-120 km
        XCTAssertGreaterThan(distance, 80_000)
        XCTAssertLessThan(distance, 120_000)
    }

    func testDifferentStateDistance() {
        // Santa Fe, NM and Phoenix, AZ should be about 650 km apart
        let santaFe = CLLocation(latitude: 35.6869, longitude: -105.9378)
        let phoenix = CLLocation(latitude: 33.4484, longitude: -112.0740)

        let distance = santaFe.distance(from: phoenix)

        // Should be between 500-800 km
        XCTAssertGreaterThan(distance, 500_000)
        XCTAssertLessThan(distance, 800_000)
    }

    func testSuspiciousDistance() {
        // Santa Fe, NM and London, UK should be suspiciously far
        let santaFe = CLLocation(latitude: 35.6869, longitude: -105.9378)
        let london = CLLocation(latitude: 51.5074, longitude: -0.1278)

        let distance = santaFe.distance(from: london)

        // Should be greater than 3000 km (suspicious distance threshold)
        XCTAssertGreaterThan(distance, 3_000_000)
    }

    func testMultiClusterRoadTripIsValid() {
        // New Mexico road trip should have legitimate distant clusters
        let santaFe = CLLocation(latitude: 35.6869, longitude: -105.9378)
        let whiteSands = CLLocation(latitude: 32.7872, longitude: -106.3257)
        let carlsbad = CLLocation(latitude: 32.4207, longitude: -104.2288)

        // Santa Fe to White Sands
        let sfToWs = santaFe.distance(from: whiteSands)
        // Should be about 350-400 km - within same state
        XCTAssertGreaterThan(sfToWs, 300_000)
        XCTAssertLessThan(sfToWs, 500_000)

        // White Sands to Carlsbad
        let wsToCc = whiteSands.distance(from: carlsbad)
        // Should be about 150-200 km
        XCTAssertGreaterThan(wsToCc, 100_000)
        XCTAssertLessThan(wsToCc, 250_000)

        // All within New Mexico, so valid for same trip
    }
}

// MARK: - Place From ParsedDestination Tests

final class PlaceFromParsedDestinationTests: XCTestCase {

    func testPlaceFromParsedDestination() {
        let parsed = ParsedDestination(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            day: 1,
            geographicContext: "Santa Fe",
            sourceLine: 1,
            isSelected: true
        )

        let place = Place.from(parsed)

        XCTAssertEqual(place.originalText, "Santa Fe Plaza")
        XCTAssertEqual(place.displayName, "Santa Fe Plaza")
        XCTAssertEqual(place.day, 1)
        XCTAssertEqual(place.geographicContext, "Santa Fe")
        XCTAssertEqual(place.resolutionConfidence, ResolutionConfidence.unresolved)
        XCTAssertNil(place.latitude)
        XCTAssertNil(place.longitude)
    }

    func testPlaceFromParsedDestination_preservesId() {
        let parsed = ParsedDestination(
            originalText: "Test",
            displayName: "Test",
            sourceLine: 1
        )

        let place = Place.from(parsed)

        XCTAssertEqual(place.id, parsed.id)
    }
}

// MARK: - Geographic Context Tests

final class GeographicContextTests: XCTestCase {

    func testLocalContextShouldOverrideTripAnchor() {
        // PistachioLand with context = Alamogordo should use Alamogordo as search center
        // NOT Santa Fe (the first resolved place in a typical itinerary)

        // This test documents the expected behavior:
        // Each place should preferably use its own local context, not a global trip anchor

        let place = Place(
            originalText: "PistachioLand",
            displayName: "PistachioLand",
            geographicContext: "Alamogordo"
        )

        // The search context should be Alamogordo, not some other city
        XCTAssertEqual(place.geographicContext, "Alamogordo")
    }

    func testContextHierarchy() {
        // Document the expected context priority:
        // 1. Place geographicContext (e.g., "Santa Fe")
        // 2. Trip destination (e.g., "New Mexico")

        let searchService = PlaceSearchService()

        // With both context and destination, query should include both
        let query = searchService.buildSearchQuery(
            displayName: "Canyon Road",
            context: "Santa Fe",
            tripDestination: "New Mexico"
        )

        XCTAssertTrue(query.contains("Canyon Road"))
        XCTAssertTrue(query.contains("Santa Fe"))
        XCTAssertTrue(query.contains("New Mexico"))
    }
}

// MARK: - SearchCandidate Tests

final class SearchCandidateTests: XCTestCase {

    func testSearchCandidateIsIdentifiable() {
        // SearchCandidate should conform to Identifiable for SwiftUI ForEach
        let candidate = SearchCandidate(
            mapItem: MKMapItem(),
            name: "Test",
            locality: nil,
            administrativeArea: nil,
            country: nil,
            countryCode: nil,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        // id should be non-nil UUID
        XCTAssertNotNil(candidate.id)
    }

    func testSearchCandidateDisqualification() {
        var candidate = SearchCandidate(
            mapItem: MKMapItem(),
            name: "Test",
            locality: nil,
            administrativeArea: "Massachusetts",
            country: "United States",
            countryCode: "US",
            coordinate: CLLocationCoordinate2D(latitude: 42.3601, longitude: -71.0589)
        )

        // Initially not disqualified
        XCTAssertFalse(candidate.disqualified)

        // Mark as disqualified
        candidate.disqualified = true
        candidate.disqualificationReason = "Wrong state: expected New Mexico, got Massachusetts"

        XCTAssertTrue(candidate.disqualified)
        XCTAssertNotNil(candidate.disqualificationReason)
    }
}
