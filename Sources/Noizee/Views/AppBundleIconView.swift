import AppKit
import SwiftUI

// MARK: - AppBundledIconFactory

/// Renders the application’s bundle icon (Dock / Finder), keeping in-app branding in sync with `.icns` / `.icon`.
@available(macOS 26.0, *)
enum AppBundledIconFactory {
    /// Produces a resized `NSImage` for use with `Image(nsImage:)`.
    static func nsImage(desiredPointSize side: CGFloat) -> NSImage {
        let bundlePath = Bundle.main.bundleURL.path
        if bundlePath.isEmpty {
            return Self.systemPlaceholder(side: side)
        }
        let base = NSWorkspace.shared.icon(forFile: bundlePath)
        guard let duplicated = base.copy() as? NSImage else {
            Self.applySize(side, to: base)
            return base
        }
        Self.applySize(side, to: duplicated)
        return duplicated
    }

    private static func applySize(_ side: CGFloat, to image: NSImage) {
        image.size = NSSize(width: side, height: side)
    }

    private static func systemPlaceholder(side: CGFloat) -> NSImage {
        guard let symbol = NSImage(systemSymbolName: "music.note", accessibilityDescription: nil) else {
            return NSImage()
        }
        Self.applySize(side, to: symbol)
        return symbol
    }
}

// MARK: - AppBundleIconView

@available(macOS 26.0, *)
struct AppBundleIconView: View {
    let size: CGFloat

    var body: some View {
        Image(nsImage: AppBundledIconFactory.nsImage(desiredPointSize: self.size))
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: self.size, height: self.size)
            .accessibilityLabel(Text("Application icon", comment: "Accessibility label for the app’s bundle icon graphic"))
    }
}
