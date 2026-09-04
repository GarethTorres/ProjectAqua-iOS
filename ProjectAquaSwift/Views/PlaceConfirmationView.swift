//
//  PlaceConfirmationView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct PlaceConfirmationView: View {
    let tripName: String
    let tripDestination: String
    let parsedItinerary: ParsedItinerary
    let tripStore: TripStore
    let onComplete: (UUID) -> Void
    let onCancel: () -> Void

    @State private var destinations: [ParsedDestination]
    @State private var resolvedPlaces: [Place] = []
    @State private var isResolving: Bool = false
    @State private var hasResolved: Bool = false
    @State private var isSaving: Bool = false

    private let placeSearchService = PlaceSearchService()

    init(
        tripName: String,
        tripDestination: String,
        parsedItinerary: ParsedItinerary,
        tripStore: TripStore,
        onComplete: @escaping (UUID) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.tripName = tripName
        self.tripDestination = tripDestination
        self.parsedItinerary = parsedItinerary
        self.tripStore = tripStore
        self.onComplete = onComplete
        self.onCancel = onCancel
        self._destinations = State(initialValue: parsedItinerary.destinations)
    }

    private var selectedCount: Int {
        destinations.filter(\.isSelected).count
    }

    private var resolvedCount: Int {
        resolvedPlaces.filter { $0.isConfidentlyResolved }.count
    }

    private var needsReviewCount: Int {
        resolvedPlaces.filter { $0.needsReview }.count
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if destinations.isEmpty {
                    emptyState
                } else if hasResolved {
                    resolutionSummaryHeader
                    resolvedPlacesList
                    saveButton
                } else {
                    summaryHeader
                    destinationList
                    continueButton
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(hasResolved ? "Resolution Results" : "Review Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(hasResolved ? "Back" : "Cancel") {
                        if hasResolved {
                            hasResolved = false
                            resolvedPlaces = []
                        } else {
                            onCancel()
                        }
                    }
                    .disabled(isResolving || isSaving)
                }
            }
            .overlay {
                if isResolving {
                    resolvingOverlay
                } else if isSaving {
                    savingOverlay
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "mappin.slash")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("No Places Found")
                .font(.title2)
                .fontWeight(.semibold)

            Text("We couldn't identify any destinations in your itinerary. Try adding more specific place names.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button("Go Back", action: onCancel)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.bottom)
        }
    }

    // MARK: - Summary Header

    private var summaryHeader: some View {
        VStack(spacing: 8) {
            Text("We found \(destinations.count) places")
                .font(.headline)

            HStack(spacing: 16) {
                if !parsedItinerary.contexts.isEmpty {
                    Label("\(parsedItinerary.contextCount) regions", systemImage: "map")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !parsedItinerary.detectedDays.isEmpty {
                    Label("\(parsedItinerary.detectedDays.count) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Resolution Summary Header

    private var resolutionSummaryHeader: some View {
        VStack(spacing: 8) {
            Text("Location Resolution Complete")
                .font(.headline)

            HStack(spacing: 16) {
                Label("\(resolvedCount) resolved", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.green)

                if needsReviewCount > 0 {
                    Label("\(needsReviewCount) need review", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Text("You can fix locations later from the trip detail screen.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Resolved Places List

    private var resolvedPlacesList: some View {
        List {
            ForEach(resolvedPlaces) { place in
                ResolvedPlaceRow(place: place)
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Destination List

    private var destinationList: some View {
        List {
            ForEach($destinations) { $destination in
                DestinationRow(destination: $destination)
            }
            .onDelete(perform: deleteDestinations)
        }
        .listStyle(.insetGrouped)
    }

    private func deleteDestinations(at offsets: IndexSet) {
        destinations.remove(atOffsets: offsets)
    }

    // MARK: - Continue Button

    private var continueButton: some View {
        VStack(spacing: 8) {
            if selectedCount < destinations.count {
                Text("\(selectedCount) of \(destinations.count) selected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button(action: resolvePlaces) {
                Label("Find Locations", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCount > 0 ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(selectedCount == 0 || isResolving)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Save Button

    private var saveButton: some View {
        VStack(spacing: 8) {
            Button(action: saveTrip) {
                Label("Save Trip", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(isSaving)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Resolving Overlay

    private var resolvingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Finding locations...")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("Searching Apple Maps for each place")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Saving Overlay

    private var savingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)

                Text("Saving trip...")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Resolve Places

    private func resolvePlaces() {
        isResolving = true

        let selectedDestinations = destinations.filter(\.isSelected)
        let places = selectedDestinations.map { Place.from($0) }

        Task {
            let resolved = await placeSearchService.resolvePlaces(
                places,
                tripDestination: tripDestination.isEmpty ? nil : tripDestination
            )

            await MainActor.run {
                resolvedPlaces = resolved
                isResolving = false
                hasResolved = true
            }
        }
    }

    // MARK: - Save Trip

    private func saveTrip() {
        isSaving = true

        let trip = Trip(
            name: tripName.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: tripDestination.trimmingCharacters(in: .whitespacesAndNewlines),
            places: resolvedPlaces
        )

        tripStore.addTrip(trip)
        isSaving = false
        onComplete(trip.id)
    }
}

// MARK: - Destination Row

struct DestinationRow: View {
    @Binding var destination: ParsedDestination

    var body: some View {
        HStack(spacing: 12) {
            Button {
                destination.isSelected.toggle()
            } label: {
                Image(systemName: destination.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(destination.isSelected ? Color.accentColor : Color.gray.opacity(0.4))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(destination.displayName)
                    .font(.body)
                    .foregroundStyle(destination.isSelected ? .primary : .secondary)

                if destination.day != nil || destination.geographicContext != nil {
                    HStack(spacing: 8) {
                        if let day = destination.day {
                            Text("Day \(day)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if let context = destination.geographicContext {
                            if destination.day != nil {
                                Text("·")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(context)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            destination.isSelected.toggle()
        }
    }
}

// MARK: - Resolved Place Row

struct ResolvedPlaceRow: View {
    let place: Place

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon

            VStack(alignment: .leading, spacing: 4) {
                // Place name
                HStack(spacing: 6) {
                    Text(place.displayName)
                        .font(.body)
                        .fontWeight(.medium)

                    confidenceIndicator
                }

                // Location info or status
                if place.isConfidentlyResolved, let summary = place.locationSummary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if place.needsReview {
                    Text("Needs review")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if place.hasCoordinates {
                    if let summary = place.locationSummary {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Day info
                if let day = place.day {
                    Text("Day \(day)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch place.resolutionConfidence {
        case .high, .manual:
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
        case .medium:
            Image(systemName: "questionmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        case .low:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
        case .unresolved:
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var confidenceIndicator: some View {
        switch place.resolutionConfidence {
        case .high:
            EmptyView()
        case .manual:
            Text("Manual")
                .font(.caption2)
                .foregroundStyle(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15))
                .clipShape(Capsule())
        case .medium:
            Text("Verify")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
        case .low:
            Text("Review")
                .font(.caption2)
                .foregroundStyle(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15))
                .clipShape(Capsule())
        case .unresolved:
            Text("Not Found")
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

#Preview("With Destinations") {
    let parser = ItineraryParser()
    let itinerary = parser.parse("""
        Santa Fe
        Santa Fe Plaza
        Georgia O'Keeffe Museum

        Day 2
        Bandelier National Monument
        White Sands National Park
        """)

    return PlaceConfirmationView(
        tripName: "New Mexico Trip",
        tripDestination: "New Mexico",
        parsedItinerary: itinerary,
        tripStore: TripStore(),
        onComplete: { _ in },
        onCancel: { }
    )
}

#Preview("Empty") {
    PlaceConfirmationView(
        tripName: "Empty Trip",
        tripDestination: "",
        parsedItinerary: .empty,
        tripStore: TripStore(),
        onComplete: { _ in },
        onCancel: { }
    )
}

#Preview("Resolved Place Row - High") {
    List {
        ResolvedPlaceRow(place: Place(
            originalText: "Santa Fe Plaza",
            displayName: "Santa Fe Plaza",
            resolvedName: "Santa Fe Plaza",
            latitude: 35.6869,
            longitude: -105.9378,
            locality: "Santa Fe",
            administrativeArea: "New Mexico",
            day: 1,
            resolutionConfidence: .high
        ))
    }
}

#Preview("Resolved Place Row - Low") {
    List {
        ResolvedPlaceRow(place: Place(
            originalText: "Canyon Road",
            displayName: "Canyon Road",
            day: 2,
            geographicContext: "Santa Fe",
            resolutionConfidence: .low
        ))
    }
}
