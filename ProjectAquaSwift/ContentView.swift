//
//  ContentView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct ContentView: View {
    @State private var tripStore = TripStore()
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeView(tripStore: tripStore, navigationPath: $navigationPath)
                .navigationDestination(for: AppDestination.self) { destination in
                    switch destination {
                    case .newTrip:
                        NewTripView(
                            tripStore: tripStore,
                            navigationPath: $navigationPath
                        )
                    case .tripDetail(let tripId):
                        if let trip = tripStore.trip(withId: tripId) {
                            TripDetailView(
                                trip: trip,
                                tripStore: tripStore,
                                navigationPath: $navigationPath
                            )
                        } else {
                            Text("Trip not found")
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
