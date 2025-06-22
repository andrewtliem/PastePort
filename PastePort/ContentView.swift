//
//  ContentView.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        VStack {
            Text("PastePort")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("This app runs in the menu bar")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Click the clipboard icon in your menu bar to access PastePort")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ContentView()
}
