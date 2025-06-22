# PastePort 📋✨

**An intelligent clipboard and screenshot manager for macOS, built to boost your productivity.**

PastePort lives in your menu bar, automatically capturing everything you copy and every screenshot you take. It provides a beautiful, searchable, and organized history, so you never lose important information again.

![PastePort Screenshot](https://github.com/andrewtliem/PastePort/blob/main/Images/PastePort1.png)

---

## 🌟 Core Features

### 📋 Smart Clipboard History
- **Automatic Capture**: Silently saves text, URLs, code snippets, and images from your clipboard.
- **Content-Aware**: Automatically detects content types, fetching website titles for URLs and identifying code blocks.
- **Image Support**: Captures images copied to the clipboard, not just those saved as files.
- **Deduplication**: Intelligently avoids saving duplicate entries, especially when copying from the app itself.

### 📸 Powerful Screenshot Manager
- **Automatic Indexing**: Detects new screenshots the moment they are created.
- **Custom Folder Support**: Monitors the default Desktop or any custom folder you configure in settings.
- **On-Device OCR**: Extracts text from your screenshots using Apple's Vision framework, making them fully searchable.
- **Thumbnails**: Generates quick-to-view thumbnails for all images and screenshots.

### 🔍 Modern & Efficient UI
- **Menu Bar Native**: Built with SwiftUI's modern `MenuBarExtra` for a seamless macOS experience.
- **Visual Timeline**: Items are grouped by date (Today, Yesterday, etc.) for easy navigation.
- **Powerful Search**: Instantly find any item by its content, title, or OCR text.
- **Filtering**: Quickly filter by item type (Text, URL, Code, Image, etc.) or show only your favorites.
- **Quick Actions on Hover**:
    - **Copy**: Instantly copy any item back to your clipboard.
    - **Open**: Open URLs in your browser or screenshots in Preview.
    - **Favorite**: Pin important items for quick access.
    - **Delete**: Clean up your history by deleting individual items.
- **Drag and Drop**: Drag items directly from PastePort into other applications.

---

## 🛠️ Built With

- **UI**: SwiftUI
- **Data Persistence**: SwiftData
- **OCR**: Vision Framework
- **System Integration**: AppKit for low-level services like pasteboard monitoring.

---

## 🚀 Getting Started

1.  **Clone the repository**: `git clone [your-repo-url]`
2.  **Open in Xcode**: Open the `PastePort.xcodeproj` file.
3.  **Build & Run**: Press `Cmd + R`. The PastePort icon will appear in your menu bar.

## 🔧 Configuration

The app includes a settings window (`Cmd + ,`) where you can configure:
- **Launch Preferences**: Enable/disable clipboard and screenshot monitoring at startup.
- **Data Preferences**: Toggle favicon fetching for URLs and OCR for screenshots.
- **Screenshot Folder**: Set a custom folder for screenshot monitoring.
- **Data Management**: Clear all history with a single click.

### Permissions
For full functionality, the app requires:
- **File System Access**: To monitor the screenshot folder (granted via a user-selection dialog).
- **Network Access**: To fetch website metadata and favicons (optional).

---

## 🎯 Future Roadmap

While the core functionality is robust, here are some features being considered for the future:

- [ ] **Advanced Tagging & Organization**
- [ ] **Cloud Sync via iCloud**
- [ ] **Customizable Keyboard Shortcuts**
- [ ] **History Export/Import**
- [ ] **Rich Text & Formatting Support**

---

## 📄 License

This project is developed for personal use and as a portfolio piece. Feel free to explore the code, but please do not distribute without permission.

---

**PastePort** - Never lose your clipboard content again! 📋✨
