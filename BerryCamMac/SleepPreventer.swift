import Foundation

@MainActor
final class SleepPreventer: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var status = "Off"

    private var process: Process?

    func setEnabled(_ enabled: Bool) {
        enabled ? start() : stop()
    }

    func start() {
        guard process == nil else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-u", "-s", "-i", "-m"]

        do {
            try process.run()
            self.process = process
            isEnabled = true
            status = "On"
        } catch {
            isEnabled = false
            status = error.localizedDescription
        }
    }

    func stop() {
        process?.terminate()
        process = nil
        isEnabled = false
        status = "Off"
    }

    deinit {
        process?.terminate()
    }
}
