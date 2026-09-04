//
//  ChangePlaceView.swift
//  ProjectAquaSwift
//

import SwiftUI
import MapKit
import CoreLocation

struct ChangePlaceView: View {
    let place: Place
    let tripDestination: String?
    let tripAnchor: CLLocation?
    let onSelect: (SearchCandidate) -> Void
    let onCancel: () -> Void

    @State private var searchQuery: String
    @State private var candidates: [SearchCandidate] = []
    @State private var isSearching: Bool = false
    @State private var hasSearched: Bool = false

    private let searchService = PlaceSearchService()

    init(
        place: Place,
        tripDestination: String?,
        tripAnchor: CLLocation?,
        onSelect: @escaping (SearchCandidate) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.place = place
        self.tripDestination = tripDestination
        self.tripAnchor = tripAnchor
        self.onSelect = onSelect
        self.onCancel = onCancel

        // Initialize search with display name and context
        var initialQuery = place.displayName
        if let context = place.geographicContext {
            initialQuery += ", \(context)"
        }
        if let dest = tripDestination, !dest.isEmpty {
            initialQuery += ", \(dest)"
        }
        self._searchQuery = State(initialValue: initialQuery)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                candidateList
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Change Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
            .onAppear {
                performSearch()
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search for place", text: $searchQuery)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .onSubmit {
                        performSearch()
                    }

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(action: performSearch) {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .disabled(searchQuery.isEmpty || isSearching)
        }
        .padding()
    }

    // MARK: - Candidate List

    private var candidateList: some View {
        Group {
            if isSearching {
                VStack(spacing: 16) {
                    Spacer()
                    ProgressView()
                    Text("Searching...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else if candidates.isEmpty && hasSearched {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "mappin.slash")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No results found")
                        .font(.headline)
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List {
                    Section {
                        ForEach(candidates) { candidate in
                            CandidateRow(candidate: candidate, tripAnchor: tripAnchor)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(candidate)
                                }
                        }
                    } header: {
                        if !candidates.isEmpty {
                            Text("Select the correct location")
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
    }

    // MARK: - Search

    private func performSearch() {
        guard !searchQuery.isEmpty else { return }

        isSearching = true
        hasSearched = true

        Task {
            let results = await searchService.searchForPlace(
                query: searchQuery,
                near: tripAnchor
            )

            await MainActor.run {
                candidates = results
                isSearching = false
            }
        }
    }
}

// MARK: - Candidate Row

struct CandidateRow: View {
    let candidate: SearchCandidate
    let tripAnchor: CLLocation?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.title2)
                .foregroundStyle(.red)

            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    if let locality = candidate.locality {
                        Text(locality)
                    }
                    if let state = candidate.administrativeArea {
                        if candidate.locality != nil {
                            Text("·")
                        }
                        Text(state)
                    }
                    if let country = candidate.country,
                       candidate.locality == nil && candidate.administrativeArea == nil {
                        Text(country)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if let distance = distanceText {
                    Text(distance)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var distanceText: String? {
        guard let anchor = tripAnchor else { return nil }

        let location = CLLocation(
            latitude: candidate.coordinate.latitude,
            longitude: candidate.coordinate.longitude
        )
        let distance = anchor.distance(from: location)

        if distance < 1000 {
            return "\(Int(distance)) m away"
        } else if distance < 100_000 {
            return String(format: "%.1f km away", distance / 1000)
        } else {
            return String(format: "%.0f km away", distance / 1000)
        }
    }
}

#Preview {
    ChangePlaceView(
        place: Place(
            originalText: "Canyon Road",
            displayName: "Canyon Road",
            geographicContext: "Santa Fe"
        ),
        tripDestination: "New Mexico",
        tripAnchor: CLLocation(latitude: 35.6869, longitude: -105.9378),
        onSelect: { _ in },
        onCancel: { }
    )
}
