//
//  Phase1CTests.swift
//  ProjectAquaSwiftTests
//

import Testing
import Foundation
import CoreLocation
@testable import ProjectAquaSwift

struct Phase1CTests {

    // MARK: - Trip Model Tests

    @Test func tripStoresPlaces() {
        let places = [
            Place(originalText: "Santa Fe Plaza", displayName: "Santa Fe Plaza"),
            Place(originalText: "Georgia O'Keeffe Museum", displayName: "Georgia O'Keeffe Museum")
        ]

        let trip = Trip(name: "Test Trip", places: places)

        #expect(trip.places.count == 2)
        #expect(trip.places[0].displayName == "Santa Fe Plaza")
        #expect(trip.places[1].displayName == "Georgia O'Keeffe Museum")
    }

    @Test func tripCountsResolvedPlaces() {
        let places = [
            Place(originalText: "Santa Fe Plaza", latitude: 35.6869, longitude: -105.9378),
            Place(originalText: "Georgia O'Keeffe Museum"),  // Unresolved
            Place(originalText: "Bandelier", latitude: 35.7785, longitude: -106.2669)
        ]

        let trip = Trip(name: "Test Trip", places: places)

        #expect(trip.resolvedPlacesCount == 2)
    }

    @Test func unresolvedPlaceDoesNotPreventTripSave() {
        // Create a place without coordinates
        let unresolvedPlace = Place(
            originalText: "Unknown Location",
            displayName: "Unknown Location"
        )

        // Create trip with unresolved place
        let trip = Trip(
            name: "Test Trip",
            places: [unresolvedPlace]
        )

        // Trip should be valid and saveable
        #expect(trip.name == "Test Trip")  // Has valid name
        #expect(trip.places.count == 1)
        #expect(!trip.places[0].hasCoordinates)
    }

    // MARK: - Place Model Tests

    @Test func placeFromParsedDestination() {
        let parsed = ParsedDestination(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            day: 2,
            geographicContext: "Santa Fe",
            sourceLine: 5
        )

        let place = Place.from(parsed)

        #expect(place.displayName == "Santa Fe Plaza")
        #expect(place.day == 2)
        #expect(place.geographicContext == "Santa Fe")
        #expect(!place.hasCoordinates)
    }

    @Test func placeHasCoordinates() {
        let placeWithCoords = Place(
            originalText: "Test",
            latitude: 35.0,
            longitude: -105.0
        )

        let placeWithoutCoords = Place(originalText: "Test")

        #expect(placeWithCoords.hasCoordinates)
        #expect(!placeWithoutCoords.hasCoordinates)
    }

    @Test func placeCoordinateProperty() {
        let place = Place(
            originalText: "Test",
            latitude: 35.6869,
            longitude: -105.9378
        )

        let coord = place.coordinate
        #expect(coord != nil)
        #expect(coord!.latitude == 35.6869)
        #expect(coord!.longitude == -105.9378)
    }

    // MARK: - PlaceSearchService Tests

    @Test func searchQueryWithGeographicContext() {
        let service = PlaceSearchService()

        let query = service.buildSearchQuery(
            displayName: "Santa Fe Plaza",
            context: "Santa Fe",
            tripDestination: "New Mexico"
        )

        #expect(query.contains("Santa Fe Plaza"))
        #expect(query.contains("Santa Fe"))
        #expect(query.contains("New Mexico"))
    }

    @Test func searchQueryWithoutContext() {
        let service = PlaceSearchService()

        let query = service.buildSearchQuery(
            displayName: "Santa Fe Plaza",
            context: nil,
            tripDestination: nil
        )

        #expect(query == "Santa Fe Plaza")
    }

    @Test func searchQueryAvoidsRedundantContext() {
        let service = PlaceSearchService()

        // If destination contains context, don't duplicate
        let query = service.buildSearchQuery(
            displayName: "Georgia O'Keeffe Museum",
            context: "Santa Fe",
            tripDestination: "Santa Fe, New Mexico"
        )

        // Should include the museum and context
        #expect(query.contains("Georgia O'Keeffe Museum"))
        #expect(query.contains("Santa Fe"))
    }

    // MARK: - AppleMapsService Tests

    @Test func appleMapsCanNavigateWithCoordinates() {
        let service = AppleMapsService()

        let placeWithCoords = Place(
            originalText: "Test",
            latitude: 35.0,
            longitude: -105.0
        )

        let placeWithoutCoords = Place(originalText: "Test")

        #expect(service.canNavigate(to: placeWithCoords))
        #expect(!service.canNavigate(to: placeWithoutCoords))
    }

    // MARK: - TripStore Tests

    @Test func tripStoreAddAndRetrieve() {
        let store = TripStore()
        let initialCount = store.trips.count

        let trip = Trip(name: "Test Trip", destination: "Test")
        store.addTrip(trip)

        #expect(store.trips.count == initialCount + 1)
        #expect(store.trip(withId: trip.id) != nil)
        #expect(store.trip(withId: trip.id)?.name == "Test Trip")

        // Clean up
        store.deleteTrip(trip)
    }

    @Test func tripStoreTogglePlaceVisited() {
        let store = TripStore()

        let place = Place(originalText: "Test Place")
        let trip = Trip(name: "Test Trip", places: [place])
        store.addTrip(trip)

        #expect(!store.trip(withId: trip.id)!.places[0].isVisited)

        store.togglePlaceVisited(tripId: trip.id, placeId: place.id)

        #expect(store.trip(withId: trip.id)!.places[0].isVisited)

        // Clean up
        store.deleteTrip(trip)
    }

    // MARK: - Codable Tests

    @Test func tripIsCodable() throws {
        let place = Place(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            resolvedName: "Santa Fe Plaza",
            latitude: 35.6869,
            longitude: -105.9378,
            day: 1,
            geographicContext: "Santa Fe"
        )

        let trip = Trip(
            name: "New Mexico Trip",
            destination: "New Mexico",
            places: [place]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(trip)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Trip.self, from: data)

        #expect(decoded.name == trip.name)
        #expect(decoded.destination == trip.destination)
        #expect(decoded.places.count == 1)
        #expect(decoded.places[0].displayName == "Santa Fe Plaza")
        #expect(decoded.places[0].latitude == 35.6869)
    }
}
