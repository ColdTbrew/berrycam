import Foundation

struct RecentHost: Codable, Identifiable, Hashable {
    var id: String { "\(host):\(port)" }
    var host: String
    var port: UInt16
    var lastUsedAt: Date

    var displayAddress: String {
        "\(host):\(port)"
    }
}

final class RecentHostStore: ObservableObject {
    @Published private(set) var hosts: [RecentHost] = []

    private let key = "berrycam.recentHosts"
    private let limit = 6

    init() {
        load()
    }

    func record(host: String, port: UInt16) {
        let normalizedHost = host
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedHost.isEmpty else { return }

        hosts.removeAll { $0.host == normalizedHost && $0.port == port }
        hosts.insert(RecentHost(host: normalizedHost, port: port, lastUsedAt: Date()), at: 0)
        if hosts.count > limit {
            hosts.removeLast(hosts.count - limit)
        }
        save()
    }

    func remove(_ host: RecentHost) {
        hosts.removeAll { $0.id == host.id }
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        hosts = (try? JSONDecoder().decode([RecentHost].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(hosts) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
