//
//  Trip.swift
//  ProjectAquaSwift
//

import Foundation

struct Trip: Identifiable, Codable {
    let id: UUID
    var name: String
    var destination: String
    let createdAt: Date
    var places: [Place]

    init(
        id: UUID = UUID(),
        name: String,
        destination: String = "",
        createdAt: Date = Date(),
        places: [Place] = []
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.createdAt = createdAt
        self.places = places
    }

    var resolvedPlacesCount: Int {
        places.filter(\.hasCoordinates).count
    }

    var visitedPlacesCount: Int {
        places.filter(\.isVisited).count
    }
}
