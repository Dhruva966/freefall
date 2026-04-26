import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var macIP: String {
        didSet { UserDefaults.standard.set(macIP, forKey: "mac_ip") }
    }

    @Published var usePrivateMode: Bool {
        didSet { UserDefaults.standard.set(usePrivateMode, forKey: "usePrivateMode") }
    }

    private init() {
        self.macIP = UserDefaults.standard.string(forKey: "mac_ip") ?? ""
        self.usePrivateMode = UserDefaults.standard.bool(forKey: "usePrivateMode")
    }

    var isConfigured: Bool { !macIP.trimmingCharacters(in: .whitespaces).isEmpty }
}
