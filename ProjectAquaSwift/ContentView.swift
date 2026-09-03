//
//  ContentView.swift
//  ProjectAquaSwift
//

import SwiftUI

struct ContentView: View {
    @State private var trips: [Trip] = []

    var body: some View {
        HomeView(trips: $trips)
    }
}

#Preview {
    ContentView()
}
