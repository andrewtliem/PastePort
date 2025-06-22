//
//  PastePortApp.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import SwiftUI
import SwiftData

@main
struct PastePortApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(modelContext: ModelContainerProvider.shared.mainContext)
                .modelContainer(ModelContainerProvider.shared)
        } label: {
            Image("MenuBarIcon")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .modelContainer(ModelContainerProvider.shared)
        }
    }
}
