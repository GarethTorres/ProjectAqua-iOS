//
//  NewTripView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct NewTripView: View {
    @Environment(\.dismiss) private var dismiss
    let tripStore: TripStore
    @Binding var navigationPath: NavigationPath

    @State private var tripName: String = ""
    @State private var destination: String = ""
    @State private var itineraryText: String = ""
    @State private var parsedItinerary: ParsedItinerary?
    @FocusState private var isTextEditorFocused: Bool

    private let parser = ItineraryParser()

    private var isValid: Bool {
        !tripName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                tripDetailsSection
                itinerarySection
            }
            .padding(.bottom, 100) // Space for sticky button
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaInset(edge: .bottom) {
            findPlacesButton
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("New Trip")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button("Done") {
                        isTextEditorFocused = false
                    }
                }
            }
        }
        .sheet(item: $parsedItinerary) { itinerary in
            PlaceConfirmationView(
                tripName: tripName,
                tripDestination: destination,
                parsedItinerary: itinerary,
                tripStore: tripStore,
                onComplete: { tripId in
                    parsedItinerary = nil
                    // Navigate directly to trip detail
                    navigationPath.removeLast(navigationPath.count)
                    navigationPath.append(AppDestination.tripDetail(tripId))
                },
                onCancel: {
                    parsedItinerary = nil
                }
            )
        }
    }

    // MARK: - Trip Details Section

    private var tripDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trip Details")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 20)

            VStack(spacing: 0) {
                TextField("Trip Name", text: $tripName)
                    .textContentType(.name)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))

                Divider()
                    .padding(.leading)

                TextField("Destination (e.g., New Mexico)", text: $destination)
                    .textContentType(.location)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal)

            Text("Give your trip a name and destination to get started.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Itinerary Section

    private var itinerarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Itinerary")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 20)

            ZStack(alignment: .topLeading) {
                // TextEditor with fixed height - internally scrollable
                TextEditor(text: $itineraryText)
                    .focused($isTextEditorFocused)
                    .frame(height: 300) // Fixed height, scrollable inside
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                // Placeholder
                if itineraryText.isEmpty {
                    Text("Paste your itinerary here...\n\nExample:\nDay 1\nSanta Fe Plaza\nGeorgia O'Keeffe Museum\n\nDay 2\nMeow Wolf\nCanyon Road")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 20)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal)

            Text("Paste your travel itinerary and we'll extract the destinations for you.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
        }
    }

    // MARK: - Find Places Button (Sticky)

    private var findPlacesButton: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: findPlaces) {
                HStack {
                    Spacer()
                    Label("Find Places", systemImage: "mappin.and.ellipse")
                        .font(.headline)
                    Spacer()
                }
                .padding()
                .background(isValid ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
            .padding()
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Actions

    private func findPlaces() {
        isTextEditorFocused = false
        parsedItinerary = parser.parse(itineraryText)
    }
}

#Preview {
    NavigationStack {
        NewTripView(tripStore: TripStore(), navigationPath: .constant(NavigationPath()))
    }
}
