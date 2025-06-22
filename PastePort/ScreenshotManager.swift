//
//  ScreenshotManager.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import Foundation
import AppKit
import SwiftData
import Vision
import VisionKit

@MainActor
class ScreenshotManager: ObservableObject {
    private let modelContext: ModelContext
    private var fileWatcher: DispatchSourceFileSystemObject?
    
    @Published var isMonitoring = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        
        // Listen for the notification to restart monitoring
        NotificationCenter.default.addObserver(self, selector: #selector(restartMonitoring), name: .shouldRestartScreenshotMonitoring, object: nil)
        
        startMonitoring()
    }
    
    @objc func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        guard let screenshotFolderURL = getScreenshotSaveLocation() else {
            print("Could not determine screenshot save location.")
            isMonitoring = false
            return
        }
        
        isMonitoring = true
        
        let fileDescriptor = open(screenshotFolderURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open directory for monitoring: \(screenshotFolderURL.path)")
            isMonitoring = false
            return
        }
        
        fileWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global(qos: .background)
        )
        
        fileWatcher?.setEventHandler { [weak self] in
            DispatchQueue.main.async {
                self?.checkForNewScreenshots()
            }
        }
        
        fileWatcher?.setCancelHandler {
            close(fileDescriptor)
        }
        
        fileWatcher?.resume()
        
        // Also check for existing screenshots on startup
        checkForNewScreenshots()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        fileWatcher?.cancel()
        fileWatcher = nil
    }
    
    private func getScreenshotSaveLocation() -> URL? {
        // 1. Check for user-selected custom path via security-scoped bookmark
        if let bookmarkData = UserDefaults.standard.data(forKey: "screenshotFolderBookmark") {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    print("Screenshot folder bookmark is stale.")
                    // In a production app, you might want to re-prompt the user here.
                    // For now, we'll fall back to the default.
                } else if url.startAccessingSecurityScopedResource() {
                    return url
                }
            } catch {
                print("Error resolving screenshot folder bookmark: \(error)")
            }
        }
        
        // 2. Check system-wide screencapture settings
        let screencaptureDefaults = UserDefaults.standard.persistentDomain(forName: "com.apple.screencapture")
        
        if let location = screencaptureDefaults?["location"] as? String {
            let expandedPath = (location as NSString).expandingTildeInPath
            return URL(fileURLWithPath: expandedPath)
        }
        
        // 3. Default to desktop if no custom location is set
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }
    
    private func checkForNewScreenshots() {
        guard let screenshotFolderURL = getScreenshotSaveLocation() else {
            return
        }
        // Ensure we release access to the folder when we are done.
        defer { screenshotFolderURL.stopAccessingSecurityScopedResource() }

        do {
            let files = try FileManager.default.contentsOfDirectory(at: screenshotFolderURL, includingPropertiesForKeys: [.creationDateKey])
            
            for file in files {
                if isScreenshotFile(file) {
                    processScreenshot(file)
                }
            }
        } catch {
            print("Error checking for screenshots: \(error)")
        }
    }
    
    private func isScreenshotFile(_ url: URL) -> Bool {
        let filename = url.lastPathComponent.lowercased()
        return filename.hasPrefix("screenshot") && 
               (filename.hasSuffix(".png") || filename.hasSuffix(".jpg") || filename.hasSuffix(".jpeg"))
    }
    
    private func processScreenshot(_ fileURL: URL) {
        // Check if we already have this screenshot
        let fileName = fileURL.lastPathComponent
        let existingScreenshots = try? modelContext.fetch(FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate<ScreenshotItem> { $0.fileName == fileName }
        ))
        
        guard existingScreenshots?.isEmpty ?? true else { return }
        
        let screenshotItem = ScreenshotItem(
            filePath: fileURL.path,
            fileName: fileName
        )
        
        modelContext.insert(screenshotItem)
        
        // Generate thumbnail
        generateThumbnail(for: screenshotItem, from: fileURL)
        
        // Perform OCR
        performOCR(on: screenshotItem, from: fileURL)
        
        do {
            try modelContext.save()
            print("Saved screenshot: \(fileName)")
        } catch {
            print("Error saving screenshot: \(error)")
        }
    }
    
    private func generateThumbnail(for screenshotItem: ScreenshotItem, from fileURL: URL) {
        guard let image = NSImage(contentsOf: fileURL) else { return }
        
        let thumbnailSize = NSSize(width: 100, height: 100)
        let thumbnail = NSImage(size: thumbnailSize)
        
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: thumbnailSize),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        thumbnail.unlockFocus()
        
        if let tiffData = thumbnail.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            screenshotItem.thumbnailData = pngData
        }
    }
    
    private func performOCR(on screenshotItem: ScreenshotItem, from fileURL: URL) {
        guard let image = NSImage(contentsOf: fileURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        
        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                print("OCR error: \(error)")
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            DispatchQueue.main.async {
                screenshotItem.ocrText = recognizedText
                try? self?.modelContext.save()
            }
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Error performing OCR: \(error)")
            }
        }
    }
    
    func openScreenshot(_ filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }
    
    func copyScreenshotText(_ ocrText: String?) {
        guard let text = ocrText, !text.isEmpty else { return }
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
} 