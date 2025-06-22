//
//  MenuBarView.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import ImageIO

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var clipboardManager: ClipboardManager
    @StateObject private var screenshotManager: ScreenshotManager
    
    @Query(sort: \TextItem.timestamp, order: .reverse) private var textItems: [TextItem]
    @Query(sort: \URLItem.timestamp, order: .reverse) private var urlItems: [URLItem]
    @Query(sort: \CodeItem.timestamp, order: .reverse) private var codeItems: [CodeItem]
    @Query(sort: \ScreenshotItem.timestamp, order: .reverse) private var screenshotItems: [ScreenshotItem]
    @Query(sort: \ImageItem.timestamp, order: .reverse) private var imageItems: [ImageItem]
    
    @State private var searchText = ""
    @State private var selectedFilter: ItemType? = nil
    @State private var showFavoritesOnly = false
    
    init(modelContext: ModelContext) {
        self._clipboardManager = StateObject(wrappedValue: ClipboardManager(modelContext: modelContext))
        self._screenshotManager = StateObject(wrappedValue: ScreenshotManager(modelContext: modelContext))
    }
    
    var filteredItems: [any ClipboardItem] {
        var allItems: [any ClipboardItem] = []
        allItems.append(contentsOf: textItems)
        allItems.append(contentsOf: urlItems)
        allItems.append(contentsOf: codeItems)
        allItems.append(contentsOf: screenshotItems)
        allItems.append(contentsOf: imageItems)
        
        return allItems
            .filter { item in
                if showFavoritesOnly && !item.isFavorite {
                    return false
                }
                
                if let filter = selectedFilter, item.itemType != filter {
                    return false
                }
                
                if !searchText.isEmpty {
                    return matchesSearch(item, searchText: searchText)
                }
                
                return true
            }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func matchesSearch(_ item: any ClipboardItem, searchText: String) -> Bool {
        let searchLower = searchText.lowercased()
        
        switch item {
        case let textItem as TextItem:
            return textItem.content.lowercased().contains(searchLower) ||
                   textItem.tags.contains { $0.lowercased().contains(searchLower) }
        case let urlItem as URLItem:
            return urlItem.url.lowercased().contains(searchLower) ||
                   (urlItem.title?.lowercased().contains(searchLower) ?? false) ||
                   urlItem.tags.contains { $0.lowercased().contains(searchLower) }
        case let codeItem as CodeItem:
            return codeItem.code.lowercased().contains(searchLower) ||
                   (codeItem.language?.lowercased().contains(searchLower) ?? false) ||
                   codeItem.tags.contains { $0.lowercased().contains(searchLower) }
        case let screenshotItem as ScreenshotItem:
            return screenshotItem.fileName.lowercased().contains(searchLower) ||
                   (screenshotItem.ocrText?.lowercased().contains(searchLower) ?? false) ||
                   screenshotItem.tags.contains { $0.lowercased().contains(searchLower) }
        case let imageItem as ImageItem:
            return imageItem.tags.contains { $0.lowercased().contains(searchLower) }
        default:
            return false
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header, Search, and Filter
            VStack(spacing: 12) {
                // Header
                HStack {
                    HStack(spacing: 0) {
                        Text("Paste")
                            .foregroundStyle(.primary)
                        Text("Port")
                            .foregroundStyle(Color.accentColor)
                    }
                    .font(.title2.bold())
                    
                    Spacer()
                    
                    Button(action: toggleFavorites) {
                        Image(systemName: showFavoritesOnly ? "heart.fill" : "heart")
                            .foregroundColor(showFavoritesOnly ? .red : .primary)
                    }
                    .buttonStyle(.plain)
                    .help(showFavoritesOnly ? "Show All Items" : "Show Favorites Only")
                }
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search history...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                
                // Filter buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterButton(title: "All", isSelected: selectedFilter == nil) {
                            selectedFilter = nil
                        }
                        
                        ForEach(ItemType.allCases, id: \.self) { type in
                            FilterButton(
                                title: type.rawValue.capitalized,
                                icon: type.icon,
                                isSelected: selectedFilter == type
                            ) {
                                selectedFilter = selectedFilter == type ? nil : type
                            }
                        }
                    }
                }
            }
            .padding()

            // Items List
            if !dateSections.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(dateSections) { section in
                            Section(header:
                                Text(formatDate(section.date))
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.ultraThinMaterial)
                            ) {
                                ForEach(section.items, id: \.id) { item in
                                    ItemRowView(
                                        item: item,
                                        clipboardManager: clipboardManager,
                                        screenshotManager: screenshotManager
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            } else {
                VStack {
                    Spacer()
                    Text(searchText.isEmpty ? "No Items Yet" : "No Matching Items")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "Start copying or taking screenshots." : "Try a different search or filter.")
                        .font(.subheadline)
                        .foregroundColor(Color(NSColor.tertiaryLabelColor))
                    Spacer()
                }
            }
            
            // Footer
            HStack {
                Text("\(filteredItems.count) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if let url = URL(string: "https://www.atlverse.xyz") {
                    Link("www.atlverse.xyz", destination: url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Clear All") {
                    clearAllItems()
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Delete all items from history")
            }
            .padding()
        }
        .frame(width: 480, height: 600)
        .background(.ultraThinMaterial)
        .edgesIgnoringSafeArea(.top)
    }
    
    private func toggleFavorites() {
        showFavoritesOnly.toggle()
    }
    
    private func clearAllItems() {
        do {
            try modelContext.delete(model: TextItem.self)
            try modelContext.delete(model: URLItem.self)
            try modelContext.delete(model: CodeItem.self)
            try modelContext.delete(model: ScreenshotItem.self)
            try modelContext.delete(model: ImageItem.self)
        } catch {
            print("Failed to clear all items: \(error)")
        }
    }
}

// MARK: - Date Grouping
private struct DateSection: Identifiable {
    let id: Date
    let date: Date
    let items: [any ClipboardItem]
}

extension MenuBarView {
    private var dateSections: [DateSection] {
        let grouped = Dictionary(grouping: filteredItems) { item in
            Calendar.current.startOfDay(for: item.timestamp)
        }

        return grouped.keys.sorted(by: >).map { date in
            DateSection(id: date, date: date, items: grouped[date]!)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return formatter.string(from: date)
        }
    }
}

struct FilterButton: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.body)
                }
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : .clear)
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? .clear : Color.primary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct ItemRowView: View {
    let item: any ClipboardItem
    let clipboardManager: ClipboardManager
    let screenshotManager: ScreenshotManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var isHovered = false
    @State private var isDragging = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon or Thumbnail
            if let thumbnailData = getThumbnailData(), let nsImage = NSImage(data: thumbnailData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(radius: 2)
            } else {
                ZStack {
                    Image(systemName: item.itemType.icon)
                        .font(.system(size: 18))
                        .foregroundColor(item.itemType.color)
                }
                .frame(width: 36, height: 36)
                .background(item.itemType.color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(itemTitle)
                    .font(.body)
                    .fontWeight(.bold)
                    .lineLimit(2)

                Text(itemSubtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if !item.tags.isEmpty {
                    HStack {
                        ForEach(item.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.2))
                                .foregroundColor(.accentColor)
                                .cornerRadius(5)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Badge and Actions
            HStack(spacing: 10) {
                if let badgeText = fileTypeBadgeText, !badgeText.isEmpty {
                    Text(badgeText)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .foregroundColor(.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .opacity(isHovered ? 0 : 1) // Hide badge when actions appear
                }

                // Actions (appear on hover)
                if isHovered {
                    Group {
                        Button(action: toggleFavorite) {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(item.isFavorite ? .red : .secondary)
                                .font(.body)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help(item.isFavorite ? "Remove from Favorites" : "Add to Favorites")

                        if let urlItem = item as? URLItem {
                            // Specific actions for URLs
                            Button(action: { clipboardManager.copyToClipboard(urlItem.url) }) {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.accentColor)
                                    .font(.body)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Copy URL")
                            
                            Button(action: { clipboardManager.openURL(urlItem.url) }) {
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundColor(.accentColor)
                                    .font(.body)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Open URL")
                        } else if let screenshotItem = item as? ScreenshotItem {
                            // Specific actions for Screenshots
                            Button(action: {
                                if let data = try? Data(contentsOf: URL(fileURLWithPath: screenshotItem.filePath)) {
                                    clipboardManager.copyImageToClipboard(data)
                                }
                            }) {
                                Image(systemName: "photo.on.rectangle")
                            }
                            .help("Copy screenshot image")
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { screenshotManager.openScreenshot(screenshotItem.filePath) }) {
                                Image(systemName: "eye")
                            }
                            .help("Open screenshot file")
                            .buttonStyle(PlainButtonStyle())
                        } else {
                            // Default primary action
                            Button(action: performPrimaryAction) {
                                Image(systemName: primaryActionIcon)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("Copy content")
                        }

                        Button(action: deleteItem) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Delete Item")
                    }
                    .foregroundColor(.accentColor)
                    .font(.body)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(minWidth: 60, alignment: .trailing)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .background(isHovered ? Color.primary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 5, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .opacity(isDragging ? 0.7 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onDrag {
            withAnimation(.easeInOut(duration: 0.2)) {
                isDragging = true
            }
            
            // Reset dragging state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDragging = false
                }
            }
            
            return createDragItem()
        } preview: {
            createDragPreview()
        }
    }
    
    // MARK: - Drag and Drop Support
    
    private func createDragItem() -> NSItemProvider {
        let provider = NSItemProvider()
        
        switch item {
        case let textItem as TextItem:
            // Provide text data
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                completion(textItem.content.data(using: .utf8), nil)
                return nil
            }
            
        case let urlItem as URLItem:
            // Provide URL data
            provider.registerDataRepresentation(forTypeIdentifier: UTType.url.identifier, visibility: .all) { completion in
                completion(urlItem.url.data(using: .utf8), nil)
                return nil
            }
            
            // Also provide as text for compatibility
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                completion(urlItem.url.data(using: .utf8), nil)
                return nil
            }
            
        case let codeItem as CodeItem:
            // Provide code as text
            provider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                completion(codeItem.code.data(using: .utf8), nil)
                return nil
            }
            
        case let screenshotItem as ScreenshotItem:
            // Provide file URL
            let fileURL = URL(fileURLWithPath: screenshotItem.filePath)
            provider.registerDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier, visibility: .all) { completion in
                completion(fileURL.absoluteString.data(using: .utf8), nil)
                return nil
            }
            
            // Also provide as image if we have thumbnail data
            if let thumbnailData = screenshotItem.thumbnailData {
                provider.registerDataRepresentation(forTypeIdentifier: UTType.image.identifier, visibility: .all) { completion in
                    completion(thumbnailData, nil)
                    return nil
                }
            }
            
        case let imageItem as ImageItem:
            // Provide image data
            provider.registerDataRepresentation(forTypeIdentifier: UTType.image.identifier, visibility: .all) { completion in
                completion(imageItem.imageData, nil)
                return nil
            }
            
        default:
            break
        }
        
        return provider
    }
    
    private func createDragPreview() -> some View {
        HStack(spacing: 8) {
            // Icon
            ZStack {
                Image(systemName: item.itemType.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.itemType.color)
            }
            .frame(width: 24, height: 24)
            .background(item.itemType.color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            // Title
            Text(itemTitle.prefix(30))
                .font(.caption)
                .lineLimit(1)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(radius: 4)
    }
    
    private var fileTypeBadgeText: String? {
        switch item {
        case is URLItem:
            return "URL"
        case is TextItem, is CodeItem:
            return "TEXT"
        case let imageItem as ImageItem:
            guard let source = CGImageSourceCreateWithData(imageItem.imageData as CFData, nil),
                  let type = CGImageSourceGetType(source) else {
                return "IMG"
            }
            if let uti = UTType(type as String), let fileExtension = uti.preferredFilenameExtension {
                return fileExtension.uppercased()
            }
            return (type as String).uppercased()
        case let screenshotItem as ScreenshotItem:
            return URL(fileURLWithPath: screenshotItem.filePath).pathExtension.uppercased()
        default:
            return nil
        }
    }
    
    private var itemTitle: String {
        switch item {
        case let textItem as TextItem:
            return textItem.content.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        case let urlItem as URLItem:
            return urlItem.title ?? urlItem.url
        case let codeItem as CodeItem:
            return codeItem.code.prefix(50).trimmingCharacters(in: .whitespacesAndNewlines)
        case let screenshotItem as ScreenshotItem:
            return screenshotItem.fileName
        case let imageItem as ImageItem:
            return "Copied Image"
        default:
            return "Unknown"
        }
    }
    
    private var itemSubtitle: String {
        switch item {
        case let textItem as TextItem:
            return textItem.content.count > 50 ? "\(textItem.content.count) characters" : ""
        case let urlItem as URLItem:
            return urlItem.url
        case let codeItem as CodeItem:
            return codeItem.language ?? "Code"
        case let screenshotItem as ScreenshotItem:
            return screenshotItem.ocrText?.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines) ?? "Screenshot"
        case let imageItem as ImageItem:
            if let image = NSImage(data: imageItem.imageData) {
                return "\(Int(image.size.width)) x \(Int(image.size.height)) pixels"
            }
            return "Image data"
        default:
            return ""
        }
    }
    
    private var primaryActionIcon: String {
        switch item {
        case is TextItem, is CodeItem:
            return "doc.on.clipboard"
        case is ImageItem:
            return "photo.on.rectangle"
        default:
            // Should not happen for handled types
            return "questionmark.circle"
        }
    }
    
    private func getThumbnailData() -> Data? {
        if let screenshotItem = item as? ScreenshotItem {
            return screenshotItem.thumbnailData
        }
        if let imageItem = item as? ImageItem {
            return imageItem.thumbnailData
        }
        return nil
    }
    
    private func toggleFavorite() {
        item.isFavorite.toggle()
        try? modelContext.save()
    }
    
    private func deleteItem() {
        switch item.itemType {
        case .text:
            if let concreteItem = item as? TextItem { modelContext.delete(concreteItem) }
        case .url:
            if let concreteItem = item as? URLItem { modelContext.delete(concreteItem) }
        case .code:
            if let concreteItem = item as? CodeItem { modelContext.delete(concreteItem) }
        case .screenshot:
            if let concreteItem = item as? ScreenshotItem { modelContext.delete(concreteItem) }
        case .image:
            if let concreteItem = item as? ImageItem { modelContext.delete(concreteItem) }
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save context after deleting item: \(error)")
        }
    }
    
    private func performPrimaryAction() {
        switch item {
        case let textItem as TextItem:
            clipboardManager.copyToClipboard(textItem.content)
        case let codeItem as CodeItem:
            clipboardManager.copyToClipboard(codeItem.code)
        case let imageItem as ImageItem:
            clipboardManager.copyImageToClipboard(imageItem.imageData)
        default:
            // URLItem and ScreenshotItem are handled separately now
            break
        }
    }
} 