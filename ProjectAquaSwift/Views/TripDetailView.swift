//
//  TripDetailView.swift
//  ProjectAquaSwift
//

import SwiftUI
import MapKit

struct TripDetailView: View {
    @State private var trip: Trip
    let tripStore: TripStore
    @Binding var navigationPath: NavigationPath

    @State private var selectedPlaceId: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var placeToChange: Place?

    private let appleMapsService = AppleMapsService()

    // Only show confidently resolved places on map
    private var mappablePlaces: [Place] {
        trip.places.filter { $0.isConfidentlyResolved }
    }

    // Trip anchor for change place searches
    private var tripAnchor: CLLocation? {
        mappablePlaces.first?.clLocation
    }

    // Group places by day
    private var placesByDay: [(day: Int?, places: [Place])] {
        var groups: [Int?: [Place]] = [:]

        for place in trip.places {
            groups[place.day, default: []].append(place)
        }

        // Sort: numbered days first (ascending), then nil (Other Places)
        return groups.sorted { lhs, rhs in
            switch (lhs.key, rhs.key) {
            case (nil, nil): return false
            case (nil, _): return false
            case (_, nil): return true
            case (let a?, let b?): return a < b
            }
        }.map { (day: $0.key, places: $0.value) }
    }

    init(trip: Trip, tripStore: TripStore, navigationPath: Binding<NavigationPath>) {
        self._trip = State(initialValue: trip)
        self.tripStore = tripStore
        self._navigationPath = navigationPath
    }

    var body: some View {
        VStack(spacing: 0) {
            mapSection
            placesList
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    // Navigate back to home by clearing the navigation path
                    navigationPath.removeLast(navigationPath.count)
                }
            }
        }
        .onAppear {
            refreshTrip()
            setupCamera()
        }
        .sheet(item: $placeToChange) { place in
            ChangePlaceView(
                place: place,
                tripDestination: trip.destination,
                tripAnchor: tripAnchor,
                onSelect: { candidate in
                    updatePlaceWithCandidate(place: place, candidate: candidate)
                    placeToChange = nil
                },
                onCancel: {
                    placeToChange = nil
                }
            )
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        Group {
            if mappablePlaces.isEmpty {
                emptyMapState
            } else {
                mapView
            }
        }
        .frame(height: 280)
    }

    private var emptyMapState: some View {
        VStack(spacing: 12) {
            Image(systemName: "map")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("No resolved locations")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Use 'Change Place' to manually find locations.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }

    private var mapView: some View {
        Map(position: $cameraPosition, selection: $selectedPlaceId) {
            ForEach(mappablePlaces) { place in
                Marker(
                    place.displayName,
                    coordinate: place.coordinate!
                )
                .tint(markerColor(for: place))
                .tag(place.id)
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    private func markerColor(for place: Place) -> Color {
        if place.isVisited {
            return .green
        }
        switch place.resolutionConfidence {
        case .high, .manual:
            return .red
        case .medium:
            return .orange
        case .low, .unresolved:
            return .gray
        }
    }

    private func setupCamera() {
        guard !mappablePlaces.isEmpty else { return }

        if mappablePlaces.count == 1, let coord = mappablePlaces.first?.coordinate {
            cameraPosition = .region(MKCoordinateRegion(
                center: coord,
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            ))
        } else {
            let coordinates = mappablePlaces.compactMap(\.coordinate)
            let region = regionThatFits(coordinates)
            cameraPosition = .region(region)
        }
    }

    private func regionThatFits(_ coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion()
        }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.4 + 0.02,
            longitudeDelta: (maxLon - minLon) * 1.4 + 0.02
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    // MARK: - Places List

    private var placesList: some View {
        List {
            if !trip.destination.isEmpty {
                Section {
                    Label(trip.destination, systemImage: "mappin.and.ellipse")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(placesByDay, id: \.day) { group in
                Section {
                    ForEach(group.places) { place in
                        PlaceDetailRow(
                            place: place,
                            isSelected: selectedPlaceId == place.id,
                            onNavigate: { navigateToPlace(place) },
                            onToggleVisited: { toggleVisited(place) },
                            onChangePlace: { placeToChange = place }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectPlace(place)
                        }
                    }
                } header: {
                    Text(sectionTitle(for: group.day))
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func sectionTitle(for day: Int?) -> String {
        if let day = day {
            return "Day \(day)"
        } else {
            return "Other Places"
        }
    }

    // MARK: - Actions

    private func refreshTrip() {
        if let updated = tripStore.refreshTrip(trip.id) {
            trip = updated
        }
    }

    private func selectPlace(_ place: Place) {
        selectedPlaceId = place.id
        if let coord = place.coordinate {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    private func navigateToPlace(_ place: Place) {
        _ = appleMapsService.openDirections(to: place)
    }

    private func toggleVisited(_ place: Place) {
        tripStore.togglePlaceVisited(tripId: trip.id, placeId: place.id)
        refreshTrip()
    }

    private func updatePlaceWithCandidate(place: Place, candidate: SearchCandidate) {
        var updated = place
        updated.latitude = candidate.coordinate.latitude
        updated.longitude = candidate.coordinate.longitude
        updated.resolvedName = candidate.name
        updated.locality = candidate.locality
        updated.administrativeArea = candidate.administrativeArea
        updated.country = candidate.country
        updated.resolutionConfidence = .manual

        var addressParts: [String] = []
        if let locality = candidate.locality { addressParts.append(locality) }
        if let state = candidate.administrativeArea { addressParts.append(state) }
        updated.formattedAddress = addressParts.isEmpty ? nil : addressParts.joined(separator: ", ")

        tripStore.updatePlace(tripId: trip.id, place: updated)
        refreshTrip()
        setupCamera()
    }
}

// MARK: - Place Detail Row

struct PlaceDetailRow: View {
    let place: Place
    let isSelected: Bool
    let onNavigate: () -> Void
    let onToggleVisited: () -> Void
    let onChangePlace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Visited toggle
                Button(action: onToggleVisited) {
                    Image(systemName: place.isVisited ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(place.isVisited ? .green : .gray.opacity(0.4))
                }
                .buttonStyle(.plain)

                // Place info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(place.displayName)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)
                            .strikethrough(place.isVisited)
                            .foregroundStyle(place.isVisited ? .secondary : .primary)

                        // Confidence indicator
                        confidenceIndicator
                    }

                    // Location summary
                    if let summary = place.locationSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if place.needsReview {
                        Text("Location needs review")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    // Context info
                    if let context = place.geographicContext, place.locationSummary == nil {
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }

            // Action buttons
            HStack(spacing: 12) {
                Spacer()

                Button(action: onChangePlace) {
                    Label("Change", systemImage: "pencil")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if place.isConfidentlyResolved {
                    Button(action: onNavigate) {
                        Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private var confidenceIndicator: some View {
        switch place.resolutionConfidence {
        case .high, .manual:
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .medium:
            Image(systemName: "questionmark.circle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .low:
            Image(systemName: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        case .unresolved:
            Image(systemName: "xmark.circle")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(
            trip: Trip(
                name: "New Mexico Trip",
                destination: "New Mexico",
                places: [
                    Place(
                        originalText: "Santa Fe Plaza",
                        displayName: "Santa Fe Plaza",
                        resolvedName: "Santa Fe Plaza",
                        latitude: 35.6869,
                        longitude: -105.9378,
                        locality: "Santa Fe",
                        administrativeArea: "New Mexico",
                        day: 1,
                        geographicContext: "Santa Fe",
                        resolutionConfidence: .high
                    ),
                    Place(
                        originalText: "Georgia O'Keeffe Museum",
                        displayName: "Georgia O'Keeffe Museum",
                        latitude: 35.6872,
                        longitude: -105.9400,
                        locality: "Santa Fe",
                        administrativeArea: "New Mexico",
                        day: 1,
                        geographicContext: "Santa Fe",
                        resolutionConfidence: .high
                    ),
                    Place(
                        originalText: "Canyon Road",
                        displayName: "Canyon Road",
                        day: 2,
                        geographicContext: "Santa Fe",
                        resolutionConfidence: .low
                    ),
                    Place(
                        originalText: "White Sands",
                        displayName: "White Sands National Park",
                        latitude: 32.7872,
                        longitude: -106.3257,
                        locality: "Alamogordo",
                        administrativeArea: "New Mexico",
                        day: 3,
                        resolutionConfidence: .high
                    )
                ]
            ),
            tripStore: TripStore(),
            navigationPath: .constant(NavigationPath())
        )
    }
}
