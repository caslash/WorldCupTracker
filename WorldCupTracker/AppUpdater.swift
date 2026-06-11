#if os(macOS)
import Sparkle

@Observable
final class AppUpdater {
    private(set) var canCheckForUpdates = false
    private let updaterController: SPUStandardUpdaterController
    private var observation: NSKeyValueObservation?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        observation = updaterController.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            DispatchQueue.main.async {
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates() {
        updaterController.updater.checkForUpdates()
    }
}
#endif
