import AppKit
import SwiftUI

/// A borderless panel just above the desktop icons that stands in for a WidgetKit widget, which macOS won't load from an ad hoc signed app.
@MainActor
final class DesktopWidget {
    static let shared = DesktopWidget()
    /// Set by the main window once it has appeared; reopens it after it's closed.
    var openMainWindow: (() -> Void)?
    private var panel: NSPanel?

    func setVisible(_ visible: Bool) {
        visible ? show() : panel?.orderOut(nil)
    }

    private func show() {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 120, y: 600, width: 740, height: 280),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            // One above Finder's desktop-icon window, which would otherwise take the clicks; still below every app window.
            panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            let host = NSHostingController(rootView: DesktopWidgetView())
            host.sizingOptions = .preferredContentSize
            panel.contentViewController = host
            panel.setFrameAutosaveName("DesktopWidget")
            self.panel = panel
        }
        panel?.orderFrontRegardless()
    }

    @objc func openMeridian() {
        NSApp.activate(ignoringOtherApps: true)
        openMainWindow?()
    }

    @objc func hide() {
        UserDefaults.standard.set(false, forKey: "showWidget")
        setVisible(false)
    }
}

private struct DesktopWidgetView: View {
    @AppStorage("cities") private var stored = City.defaults.map(\.id).joined(separator: "\n")
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)

    var body: some View {
        TimelineView(.everyMinute) { context in
            WorldClockView(date: context.date, cities: stored.split(separator: "\n").compactMap { City(id: String($0)) }, twelveHour: twelveHour)
        }
        .frame(width: 720)
        .padding(10)
        .background(.regularMaterial, in: .rect(cornerRadius: 16))
        .overlay(WidgetMouseArea())
    }
}

/// Covers the widget: dragging moves the panel and right-clicking shows its menu. Plain AppKit, because the panel never
/// becomes key or activates the app, which SwiftUI's background dragging and context menus rely on.
private struct WidgetMouseArea: NSViewRepresentable {
    final class MouseView: NSView {
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }

    func makeNSView(context: Context) -> MouseView {
        let view = MouseView()
        let menu = NSMenu()
        for (title, action) in [("Open Meridian", #selector(DesktopWidget.openMeridian)), ("Hide Widget", #selector(DesktopWidget.hide))] {
            menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = DesktopWidget.shared
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Meridian", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        view.menu = menu
        return view
    }

    func updateNSView(_: MouseView, context: Context) {}
}
