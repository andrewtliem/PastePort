//
//  ModelContainerProvider.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import Foundation
import SwiftData

struct ModelContainerProvider {
    static let shared: ModelContainer = {
        let schema = Schema([
            TextItem.self,
            URLItem.self,
            CodeItem.self,
            ScreenshotItem.self,
            ImageItem.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
} 