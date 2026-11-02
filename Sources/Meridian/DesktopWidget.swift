import AppKit
import SwiftUI

/// A borderless panel just above the desktop icons that stands in for a WidgetKit widget, which macOS won't load from an ad hoc signed app.
@MainActor
final class DesktopWidget {
    static let shared = DesktopWidget()
    private var panel: NSPanel?

    func setVisible(_ visible: Bool) {
        visible ? show() : panel?.orderOut(nil)
    }

    private func show() {
        if panel == nil {
            let panel = NSPanel(contentRect: NSRect(x: 120, y: 600, width: 400, height: 236),
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
}

private struct DesktopWidgetView: View {
    @AppStorage("cities") private var stored = City.defaults.map(\.id).joined(separator: "\n")
    @AppStorage("twelveHour") private var twelveHour = CityTime.uses12Hour(.autoupdatingCurrent)
    @AppStorage("showWidget") private var showWidget = true

    var body: some View {
        TimelineView(.everyMinute) { context in
            WorldClockView(date: context.date, cities: stored.split(separator: "\n").compactMap { City(id: String($0)) }, twelveHour: twelveHour)
        }
        .frame(width: 380)
        .padding(10)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
        .background(WindowDragArea())
        .contextMenu {
            // Relaunching a running app reopens its window, the same as clicking it in the Dock.
            Button("Open Meridian") { NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: .init()) }
            Button("Hide Widget") { showWidget = false; DesktopWidget.shared.setVisible(false) }
            Divider()
            Button("Quit Meridian") { NSApp.terminate(nil) }
        }
    }
}

/// Drags the panel from anywhere on the widget; a borderless, non-activating panel doesn't reliably move by its background.
private struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }

    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_: DragView, context: Context) {}
}
