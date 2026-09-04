//
//  AppleMapsService.swift
//  ProjectAquaSwift
//

import Foundation
import MapKit
import CoreLocation

struct AppleMapsService {

    // MARK: - Navigation

    func openDirections(to place: Place) -> Bool {
        guard let coordinate = place.coordinate else {
            return false
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = place.resolvedName ?? place.displayName

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        mapItem.openInMaps(launchOptions: launchOptions)
        return true
    }

    func openLocation(_ place: Place) -> Bool {
        guard let coordinate = place.coordinate else {
            return false
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = place.resolvedName ?? place.displayName

        mapItem.openInMaps()
        return true
    }

    // MARK: - Coordinate Check

    func canNavigate(to place: Place) -> Bool {
        place.hasCoordinates
    }
}
