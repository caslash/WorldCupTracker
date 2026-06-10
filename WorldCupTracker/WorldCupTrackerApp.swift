import SwiftUI
import AppKit

#if os(macOS)
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window.level == .normal else { return }
        DispatchQueue.main.async {
            let hasOpenWindows = NSApp.windows.contains {
                $0.level == .normal && ($0.isVisible || $0.isMiniaturized)
            }
            if !hasOpenWindows {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
#endif

@main
struct WorldCupTrackerApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif
    @State private var tracker = MatchTracker()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(tracker)
                #if os(macOS)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                }
                #endif
        }

        #if os(macOS)
        MenuBarExtra {
            MenuBarPanelView()
                .environment(tracker)
        } label: {
            MenuBarLabel(tracker: tracker)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
