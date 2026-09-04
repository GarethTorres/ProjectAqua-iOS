//
//  TripStore.swift
//  ProjectAquaSwift
//

import Foundation
import Observation

@Observable
final class TripStore {
    private(set) var trips: [Trip] = []

    private let storageKey = "savedTrips"

    init() {
        loadTrips()
    }

    // MARK: - CRUD Operations

    func addTrip(_ trip: Trip) {
        trips.insert(trip, at: 0)
        saveTrips()
    }

    func updateTrip(_ trip: Trip) {
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            saveTrips()
        }
    }

    func deleteTrip(_ trip: Trip) {
        trips.removeAll { $0.id == trip.id }
        saveTrips()
    }

    func trip(withId id: UUID) -> Trip? {
        trips.first { $0.id == id }
    }

    // MARK: - Place Operations

    func togglePlaceVisited(tripId: UUID, placeId: UUID) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripId }),
              let placeIndex = trips[tripIndex].places.firstIndex(where: { $0.id == placeId }) else {
            return
        }
        trips[tripIndex].places[placeIndex].isVisited.toggle()
        saveTrips()
    }

    func updatePlace(tripId: UUID, place: Place) {
        guard let tripIndex = trips.firstIndex(where: { $0.id == tripId }),
              let placeIndex = trips[tripIndex].places.firstIndex(where: { $0.id == place.id }) else {
            return
        }
        trips[tripIndex].places[placeIndex] = place
        saveTrips()
    }

    func refreshTrip(_ tripId: UUID) -> Trip? {
        return trip(withId: tripId)
    }

    // MARK: - Persistence

    private func saveTrips() {
        do {
            let data = try JSONEncoder().encode(trips)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to save trips: \(error)")
        }
    }

    private func loadTrips() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }
        do {
            trips = try JSONDecoder().decode([Trip].self, from: data)
        } catch {
            print("Failed to load trips: \(error)")
        }
    }
}
