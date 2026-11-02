import AppKit
import SwiftUI

/// A borderless panel at desktop-icon level that stands in for a WidgetKit widget, which macOS won't load from an ad hoc signed app.
@MainActor
final class DesktopWidget {
    static let shared = DesktopWidget()
    private var panel: NSPanel?

    var isVisible: Bool { panel?.isVisible ?? false }

    func show() {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 120, y: 600, width: 380, height: 200),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)))
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.isMovableByWindowBackground = true
            let host = NSHostingController(rootView: DesktopWidgetView())
            host.sizingOptions = .preferredContentSize
            panel.contentViewController = host
            panel.setFrameAutosaveName("DesktopWidget")
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    func hide() { panel?.orderOut(nil) }
}

private struct DesktopWidgetView: View {
    @AppStorage("cities") private var stored = City.defaults.map(\.id).joined(separator: "\n")

    var body: some View {
        TimelineView(.everyMinute) { context in
            WorldClockView(date: context.date, cities: stored.split(separator: "\n").compactMap { City(id: String($0)) })
        }
        .frame(width: 380)
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }
}
