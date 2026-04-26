import Combine
import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isThinking = false

    private let executor = ActionExecutor()
    private var router: MessageRouting
    private var cancellables: Set<AnyCancellable> = []
    private let historyKey = "chat_history"

    init() {
        self.router = MockMessageRouter()
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            self.messages = saved
        }
        refreshRouter()

        Publishers.CombineLatest(
            AppSettings.shared.$macIP.removeDuplicates(),
            AppSettings.shared.$usePrivateMode.removeDuplicates()
        )
        .sink { [weak self] _, _ in
            self?.refreshRouter()
        }
        .store(in: &cancellables)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(200))) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }

    func refreshRouter() {
        if AppSettings.shared.usePrivateMode {
            if #available(iOS 26, *) {
                router = PrivateRouter()
                return
            }
        }

        let ip = AppSettings.shared.macIP
        router = ip.isEmpty ? MockMessageRouter() : MacBackendRouter(macIP: ip)
    }

    func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(text: text, isUser: true))
        inputText = ""
        isThinking = true
        saveHistory()

        Task {
            let result = await router.route(text)
            let reply = await executor.execute(result)
            messages.append(ChatMessage(text: reply, isUser: false))
            isThinking = false
            saveHistory()
        }
    }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }
}

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()
    @StateObject private var settings = AppSettings.shared
    @FocusState private var inputFocused: Bool
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !settings.usePrivateMode && !settings.isConfigured {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Mac IP not set — using mock responses")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Configure") { showSettings = true }
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.systemYellow).opacity(0.15))
                }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(vm.messages) { msg in
                                MessageBubble(message: msg)
                                    .id(msg.id)
                            }
                            if vm.isThinking {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .onChange(of: vm.messages.count) { _ in
                        if let last = vm.messages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                    .onChange(of: vm.isThinking) { thinking in
                        if thinking {
                            withAnimation { proxy.scrollTo("typing", anchor: .bottom) }
                        }
                    }
                }

                Divider()

                HStack(spacing: 10) {
                    TextField("Message", text: $vm.inputText, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(1...4)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())
                        .focused($inputFocused)
                        .onSubmit { vm.send() }

                    Button {
                        vm.send()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(vm.inputText.isEmpty ? .gray : .blue)
                    }
                    .disabled(vm.inputText.isEmpty || vm.isThinking)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Free Fall")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Free Fall").font(.headline)
                        Text(statusText)
                            .font(.caption2)
                            .foregroundColor(statusColor)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings, onDismiss: { vm.refreshRouter() }) {
                SettingsSheet(onClearHistory: { vm.clearHistory() })
            }
        }
    }
}

struct SettingsSheet: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft = AppSettings.shared.macIP
    var onClearHistory: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 192.168.1.42", text: $draft)
                        .keyboardType(.numbersAndPunctuation)
                        .autocorrectionDisabled()
                } header: {
                    Text("Mac IP Address")
                } footer: {
                    Text("Your Mac's local IP on the same WiFi network. Find it in System Settings → Network → Wi-Fi → Details.")
                }

                Section {
                    Toggle("Private Mode (on-device AI)", isOn: $settings.usePrivateMode)
                } footer: {
                    Text("Runs AI entirely on your iPhone. Requires iPhone 15 Pro or later with Apple Intelligence enabled.")
                }

                Section {
                    Button("Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Section {
                    Button("Clear Conversation History", role: .destructive) {
                        onClearHistory?()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        settings.macIP = draft.trimmingCharacters(in: .whitespaces)
                        dismiss()
                    }
                }
            }
        }
    }

    @State private var connectionStatus = ""

    private func testConnection() async {
        let ip = draft.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "http://\(ip):8000/message") else {
            connectionStatus = "Invalid IP"
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": "ping", "sender": "ios-test"])
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                connectionStatus = "Connected"
            } else {
                connectionStatus = "Server error"
            }
        } catch {
            connectionStatus = "Unreachable — check IP and server"
        }
    }
}

private extension ChatView {
    var statusText: String {
        if settings.usePrivateMode {
            return "on-device AI"
        }
        return settings.isConfigured ? "connected · private" : "mock mode"
    }

    var statusColor: Color {
        if settings.usePrivateMode || settings.isConfigured {
            return .secondary
        }
        return .orange
    }
}

#Preview {
    ChatView()
}
