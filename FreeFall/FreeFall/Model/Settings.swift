import Foundation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var macIP: String {
        didSet { UserDefaults.standard.set(macIP, forKey: "mac_ip") }
    }

    var usePrivateMode: Bool {
        didSet { UserDefaults.standard.set(usePrivateMode, forKey: "usePrivateMode") }
    }

    private init() {
        self.macIP         = UserDefaults.standard.string(forKey: "mac_ip") ?? ""
        self.usePrivateMode = UserDefaults.standard.bool(forKey: "usePrivateMode")
    }

    var isConfigured: Bool { !macIP.trimmingCharacters(in: .whitespaces).isEmpty }
}
