//
//  HomeView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct HomeView: View {
    let tripStore: TripStore
    @Binding var navigationPath: NavigationPath

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                headerSection
                newTripButton
                upcomingTripsSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Project Aqua")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("Plan anywhere.")
                .font(.title2)
                .fontWeight(.medium)
            Text("Travel with us.")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - New Trip Button

    private var newTripButton: some View {
        NavigationLink(value: AppDestination.newTrip) {
            Label("New Trip", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Upcoming Trips Section

    private var upcomingTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Trips")
                .font(.headline)
                .foregroundStyle(.secondary)

            if tripStore.trips.isEmpty {
                emptyState
            } else {
                tripsList
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("No trips yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Tap New Trip to start planning your next adventure.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var tripsList: some View {
        VStack(spacing: 8) {
            ForEach(tripStore.trips) { trip in
                NavigationLink(value: AppDestination.tripDetail(trip.id)) {
                    TripRowContent(trip: trip)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Trip Row Content

struct TripRowContent: View {
    let trip: Trip

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                if !trip.destination.isEmpty {
                    Text(trip.destination)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Text(trip.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if !trip.places.isEmpty {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("\(trip.places.count) places")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Navigation Destination

enum AppDestination: Hashable {
    case newTrip
    case tripDetail(UUID)
}

#Preview {
    NavigationStack {
        HomeView(tripStore: TripStore(), navigationPath: .constant(NavigationPath()))
    }
}
