//
//  Item.swift
//  PastePort
//
//  Created by Andrew Tanny Liem on 20/06/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Base Item Protocol
protocol ClipboardItem: AnyObject, Identifiable {
    var id: UUID { get }
    var timestamp: Date { get }
    var isFavorite: Bool { get set }
    var tags: [String] { get set }
    var itemType: ItemType { get }
}

// MARK: - Item Types
enum ItemType: String, CaseIterable, Codable {
    case text = "text"
    case url = "url"
    case code = "code"
    case screenshot = "screenshot"
    case image = "image"
    
    var icon: String {
        switch self {
        case .text: return "doc.text.fill"
        case .url: return "link"
        case .code: return "curlybraces"
        case .screenshot: return "camera.viewfinder"
        case .image: return "photo.on.rectangle.angled"
        }
    }
    
    var color: Color {
        switch self {
        case .text: return .blue
        case .url: return .green
        case .code: return .orange
        case .screenshot: return .purple
        case .image: return .pink
        }
    }
}

// MARK: - Text Item
@Model
final class TextItem: ClipboardItem {
    var id: UUID
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    var content: String
    var itemType: ItemType { .text }
    
    init(content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isFavorite = false
        self.tags = []
        self.content = content
    }
}

// MARK: - URL Item
@Model
final class URLItem: ClipboardItem {
    var id: UUID
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    var url: String
    var title: String?
    var faviconURL: String?
    var preview: String?
    var itemType: ItemType { .url }
    
    init(url: String, title: String? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isFavorite = false
        self.tags = []
        self.url = url
        self.title = title
    }
}

// MARK: - Code Item
@Model
final class CodeItem: ClipboardItem {
    var id: UUID
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    var code: String
    var language: String?
    var itemType: ItemType { .code }
    
    init(code: String, language: String? = nil, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isFavorite = false
        self.tags = []
        self.code = code
        self.language = language
    }
}

// MARK: - Screenshot Item
@Model
final class ScreenshotItem: ClipboardItem {
    var id: UUID
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    var filePath: String
    var fileName: String
    var ocrText: String?
    var thumbnailData: Data?
    var itemType: ItemType { .screenshot }
    
    init(filePath: String, fileName: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isFavorite = false
        self.tags = []
        self.filePath = filePath
        self.fileName = fileName
    }
}

// MARK: - Image Item
@Model
final class ImageItem: ClipboardItem {
    var id: UUID
    var timestamp: Date
    var isFavorite: Bool
    var tags: [String]
    var imageData: Data
    var thumbnailData: Data?
    var itemType: ItemType { .image }
    
    init(imageData: Data, timestamp: Date = Date()) {
        self.id = UUID()
        self.timestamp = timestamp
        self.isFavorite = false
        self.tags = []
        self.imageData = imageData
    }
}
