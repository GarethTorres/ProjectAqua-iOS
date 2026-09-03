//
//  Trip.swift
//  ProjectAquaSwift
//

import Foundation

struct Trip: Identifiable {
    let id: UUID
    var name: String
    var destination: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, destination: String = "", createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.destination = destination
        self.createdAt = createdAt
    }
}
