//
//  SettingsView.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    // Persistent settings backed by UserDefaults
    @AppStorage("autoStartClipboardMonitoring") private var autoStartClipboardMonitoring = true
    @AppStorage("fetchFavicons") private var fetchFavicons = true
    @AppStorage("autoStartScreenshotMonitoring") private var autoStartScreenshotMonitoring = true
    @AppStorage("enableOCR") private var enableOCR = true
    @AppStorage("screenshotFolderBookmark") private var screenshotFolderBookmark: Data?

    @State private var screenshotFolderPath: String?
    @State private var showingClearAlert = false

    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            advancedSettings
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }
        }
        .padding(20)
        .frame(width: 500, height: 380)
        .onAppear(perform: loadFolderPath)
    }

    private var generalSettings: some View {
        Form {
            Section(header: Text("Clipboard Monitoring").font(.headline)) {
                Toggle(isOn: $autoStartClipboardMonitoring) {
                    Label("Monitor Clipboard on Launch", systemImage: "clipboard")
                }
                Toggle(isOn: $fetchFavicons) {
                    Label("Fetch Website Favicons & Titles", systemImage: "network")
                }
            }

            Section(header: Text("Screenshot Monitoring").font(.headline)) {
                Toggle(isOn: $autoStartScreenshotMonitoring) {
                    Label("Monitor for New Screenshots", systemImage: "camera.on.rectangle")
                }
                Toggle(isOn: $enableOCR) {
                    Label("Recognize Text in Screenshots (OCR)", systemImage: "text.magnifyingglass")
                }
            }

            Section(header: Text("About").font(.headline)) {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.appVersion)
                }
                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.appBuild)
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private var advancedSettings: some View {
        Form {
            Section(header: Text("Screenshots Folder").font(.headline)) {
                HStack {
                    Label("Location", systemImage: "folder")
                    Spacer()
                    Text(screenshotFolderPath ?? "Default (Desktop)")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Select Folder...") {
                        selectScreenshotFolder()
                    }
                }
            }

            Section(header: Text("Data Management").font(.headline)) {
                HStack {
                    Spacer()
                    Button("Clear History", role: .destructive) {
                        showingClearAlert = true
                    }
                    .help("Deletes all clipboard and screenshot history permanently.")
                    
                    Button("Export History...") {
                        exportData()
                    }
                    .disabled(true) // Not yet implemented
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .alert("Clear All History?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                clearAllItems()
            }
        } message: {
            Text("Are you sure you want to delete all clipboard and screenshot history? This action cannot be undone.")
        }
    }
    
    private func loadFolderPath() {
        guard let bookmarkData = screenshotFolderBookmark else {
            screenshotFolderPath = nil
            return
        }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Try to refresh the bookmark
                let newBookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                self.screenshotFolderBookmark = newBookmarkData
                print("Refreshed stale bookmark for screenshot folder.")
            }
            
            screenshotFolderPath = url.path
        } catch {
            print("Error resolving bookmark data: \(error)")
            screenshotFolderPath = "Error - Please re-select folder"
        }
    }

    private func selectScreenshotFolder() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select"
        
        if openPanel.runModal() == .OK {
            if let url = openPanel.url {
                do {
                    let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    self.screenshotFolderBookmark = bookmarkData
                    loadFolderPath()
                    NotificationCenter.default.post(name: .shouldRestartScreenshotMonitoring, object: nil)
                } catch {
                    print("Error creating bookmark for screenshot folder: \(error)")
                }
            }
        }
    }
    
    private func clearAllItems() {
         Task { @MainActor in
            let modelContext = ModelContainerProvider.shared.mainContext
            do {
                try modelContext.delete(model: TextItem.self)
                try modelContext.delete(model: URLItem.self)
                try modelContext.delete(model: CodeItem.self)
                try modelContext.delete(model: ScreenshotItem.self)
                try modelContext.delete(model: ImageItem.self)
                print("All items cleared.")
            } catch {
                print("Failed to clear all items: \(error)")
            }
        }
    }
    
    private func exportData() {
        // This can be implemented later.
        print("Export data action triggered.")
    }
}

private extension Bundle {
    var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
    
    var appBuild: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }
}

extension Notification.Name {
    static let shouldRestartScreenshotMonitoring = Notification.Name("shouldRestartScreenshotMonitoring")
}

#Preview {
    SettingsView()
        .modelContainer(ModelContainerProvider.shared)
} 