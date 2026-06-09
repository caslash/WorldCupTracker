import SwiftUI

@main
struct WorldCupTrackerApp: App {
    @State private var tracker = MatchTracker()

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environment(tracker)
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
