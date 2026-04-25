import Foundation
import Combine

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var macIP: String {
        didSet { UserDefaults.standard.set(macIP, forKey: "mac_ip") }
    }

    private init() {
        self.macIP = UserDefaults.standard.string(forKey: "mac_ip") ?? ""
    }

    var isConfigured: Bool { !macIP.trimmingCharacters(in: .whitespaces).isEmpty }
}
