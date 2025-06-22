//
//  ClipboardManager.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import Foundation
import AppKit
import SwiftData
import Vision
import UniformTypeIdentifiers

@MainActor
class ClipboardManager: ObservableObject {
    private var lastChangeCount: Int = 0
    private var timer: Timer?
    private let modelContext: ModelContext
    
    @Published var isMonitoring = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }
    
    func startMonitoring() {
        isMonitoring = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.checkClipboard()
            }
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        
        guard pasteboard.changeCount != lastChangeCount else {
            return
        }
        
        lastChangeCount = pasteboard.changeCount

        // 1. Check for images
        if let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
            saveImageItem(imageData: tiffData)
            return
        }
        
        // 2. Check for strings
        if let clipboardString = pasteboard.string(forType: .string),
           !clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            processClipboardContent(clipboardString)
        }
    }
    
    private func processClipboardContent(_ content: String) {
        // Check if it's a URL
        if let url = URL(string: content), let scheme = url.scheme, ["http", "https"].contains(scheme) {
            saveURLItem(url: content)
            return
        }
        
        // Check if it's code (simple heuristic)
        if isCode(content) {
            saveCodeItem(code: content)
            return
        }
        
        // Default to text
        saveTextItem(content: content)
    }
    
    private func isCode(_ content: String) -> Bool {
        let codeIndicators = [
            "function", "class", "def ", "import ", "export ", "var ", "let ", "const ",
            "if ", "for ", "while ", "switch ", "case ", "return ", "public ", "private ",
            "{", "}", "(", ")", ";", "=>", "->", "::", "//", "/*", "*/"
        ]
        
        let lines = content.components(separatedBy: .newlines)
        let codeLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return codeIndicators.contains { indicator in
                trimmed.contains(indicator)
            }
        }
        
        return codeLines.count > lines.count / 2
    }
    
    private func saveTextItem(content: String) {
        // Deduplication Check
        var fetchDescriptor = FetchDescriptor<TextItem>(predicate: nil, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        fetchDescriptor.fetchLimit = 1
        
        if let mostRecent = try? modelContext.fetch(fetchDescriptor).first, mostRecent.content == content {
            print("Skipping duplicate text item.")
            return
        }
        
        let textItem = TextItem(content: content)
        modelContext.insert(textItem)
        
        do {
            try modelContext.save()
            print("Saved text item: \(content.prefix(50))...")
        } catch {
            print("Error saving text item: \(error)")
        }
    }
    
    private func saveURLItem(url: String) {
        // Deduplication Check
        var fetchDescriptor = FetchDescriptor<URLItem>(predicate: nil, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        fetchDescriptor.fetchLimit = 1

        if let mostRecent = try? modelContext.fetch(fetchDescriptor).first, mostRecent.url == url {
            print("Skipping duplicate URL item.")
            return
        }

        let urlItem = URLItem(url: url)
        modelContext.insert(urlItem)
        
        // Fetch favicon and title in background
        Task {
            await fetchURLMetadata(for: urlItem)
        }
        
        do {
            try modelContext.save()
            print("Saved URL item: \(url)")
        } catch {
            print("Error saving URL item: \(error)")
        }
    }
    
    private func saveCodeItem(code: String) {
        // Deduplication Check
        var fetchDescriptor = FetchDescriptor<CodeItem>(predicate: nil, sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        fetchDescriptor.fetchLimit = 1

        if let mostRecent = try? modelContext.fetch(fetchDescriptor).first, mostRecent.code == code {
            print("Skipping duplicate code item.")
            return
        }

        let codeItem = CodeItem(code: code)
        modelContext.insert(codeItem)
        
        do {
            try modelContext.save()
            print("Saved code item: \(code.prefix(50))...")
        } catch {
            print("Error saving code item: \(error)")
        }
    }
    
    private func saveImageItem(imageData: Data) {
        // Deduplication Check 1: Check against recent screenshots
        let fiveSecondsAgo = Date().addingTimeInterval(-5)
        let screenshotDescriptor = FetchDescriptor<ScreenshotItem>(
            predicate: #Predicate { $0.timestamp > fiveSecondsAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let recentScreenshots = try? modelContext.fetch(screenshotDescriptor) {
            for screenshot in recentScreenshots {
                if let screenshotThumb = screenshot.thumbnailData,
                   let clipboardThumb = generateThumbnailData(from: imageData, size: NSSize(width: 36, height: 36)) {
                    if screenshotThumb == clipboardThumb {
                        print("Skipping duplicate image item (matches recent screenshot).")
                        return
                    }
                }
            }
        }
        
        // Deduplication Check 2: Check against recent images
        let imageDescriptor = FetchDescriptor<ImageItem>(
            predicate: #Predicate { $0.timestamp > fiveSecondsAgo },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        if let recentImages = try? modelContext.fetch(imageDescriptor),
           recentImages.contains(where: { $0.imageData == imageData }) {
            print("Skipping duplicate image item (matches recent image).")
            return
        }
        
        let imageItem = ImageItem(imageData: imageData)
        
        // Generate thumbnail for the new image
        if let thumb = generateThumbnailData(from: imageData, size: NSSize(width: 100, height: 100)) {
            imageItem.thumbnailData = thumb
        }
        
        modelContext.insert(imageItem)
        
        do {
            try modelContext.save()
            print("Saved image item.")
        } catch {
            print("Error saving image item: \(error)")
        }
    }
    
    private func generateThumbnailData(from data: Data, size: NSSize) -> Data? {
        guard let image = NSImage(data: data) else { return nil }
        
        let thumbnail = NSImage(size: size)
        
        thumbnail.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy,
                  fraction: 1.0)
        thumbnail.unlockFocus()
        
        if let tiffData = thumbnail.tiffRepresentation,
           let bitmapImage = NSBitmapImageRep(data: tiffData),
           let pngData = bitmapImage.representation(using: .png, properties: [:]) {
            return pngData
        }
        
        return nil
    }
    
    private func fetchURLMetadata(for urlItem: URLItem) async {
        guard let url = URL(string: urlItem.url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let htmlString = String(data: data, encoding: .utf8) {
                // Extract title
                if let titleRange = htmlString.range(of: "<title>"),
                   let titleEndRange = htmlString.range(of: "</title>") {
                    let titleStart = htmlString.index(titleRange.upperBound, offsetBy: 0)
                    let title = String(htmlString[titleStart..<titleEndRange.lowerBound])
                    urlItem.title = title
                }
                
                // Extract favicon
                if let faviconRange = htmlString.range(of: "rel=\"icon\""),
                   let hrefRange = htmlString.range(of: "href=\"", range: faviconRange.upperBound..<htmlString.endIndex) {
                    let hrefStart = htmlString.index(hrefRange.upperBound, offsetBy: 0)
                    if let hrefEndRange = htmlString.range(of: "\"", range: hrefStart..<htmlString.endIndex) {
                        let faviconURL = String(htmlString[hrefStart..<hrefEndRange.lowerBound])
                        urlItem.faviconURL = faviconURL
                    }
                }
                
                try modelContext.save()
            }
        } catch {
            print("Error fetching URL metadata: \(error)")
        }
    }
    
    func copyToClipboard(_ content: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        // Update change count to prevent the monitor from immediately re-capturing it
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func copyImageToClipboard(_ imageData: Data) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setData(imageData, forType: .tiff)
        // Update change count to prevent the monitor from immediately re-capturing it
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
    
    func openScreenshot(_ filePath: String) {
        let url = URL(fileURLWithPath: filePath)
        NSWorkspace.shared.open(url)
    }
} 