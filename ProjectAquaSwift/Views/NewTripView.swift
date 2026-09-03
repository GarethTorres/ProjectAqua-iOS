//
//  NewTripView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var trips: [Trip]

    @State private var tripName: String = ""
    @State private var destination: String = ""
    @State private var itineraryText: String = ""
    @State private var showingPlaceholder: Bool = false

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            tripDetailsSection
            itinerarySection
        }
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingPlaceholder) {
            PlaceholderResultView(tripName: tripName, onDismiss: {
                showingPlaceholder = false
                saveTrip()
                dismiss()
            })
        }
    }

    // MARK: - Trip Details Section

    private var tripDetailsSection: some View {
        Section {
            TextField("Trip Name", text: $tripName)
                .textContentType(.name)

            TextField("Destination (optional)", text: $destination)
                .textContentType(.location)
        } header: {
            Text("Trip Details")
        } footer: {
            Text("Give your trip a name to get started.")
        }
    }

    // MARK: - Itinerary Section

    private var itinerarySection: some View {
        Section {
            TextEditor(text: $itineraryText)
                .frame(minHeight: 200)
                .overlay(alignment: .topLeading) {
                    if itineraryText.isEmpty {
                        Text("Paste your itinerary here...\n\nExample:\nDay 1: Arrive in Tokyo, check into hotel\nDay 2: Visit Senso-ji Temple, explore Asakusa\nDay 3: Day trip to Mount Fuji")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                }

            Button(action: findPlaces) {
                HStack {
                    Spacer()
                    Label("Find Places", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(!isValid)
        } header: {
            Text("Itinerary")
        } footer: {
            Text("Paste your travel itinerary and we'll extract the destinations for you.")
        }
    }

    // MARK: - Actions

    private func findPlaces() {
        showingPlaceholder = true
    }

    private func saveTrip() {
        let trip = Trip(
            name: tripName.trimmingCharacters(in: .whitespacesAndNewlines),
            destination: destination.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        trips.insert(trip, at: 0)
    }
}

// MARK: - Placeholder Result View

struct PlaceholderResultView: View {
    let tripName: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)

                Text("Coming Soon")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Place extraction will analyze your itinerary and find all the destinations mentioned.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer()

                Button(action: onDismiss) {
                    Text("Save Trip")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle(tripName)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    NavigationStack {
        NewTripView(trips: .constant([]))
    }
}
