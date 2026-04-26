import SwiftUI

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isThinking = false

    private let executor = ActionExecutor()
    private var router: MessageRouting
    private let historyKey = "chat_history"

    init() {
        self.router = MockMessageRouter()
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            self.messages = saved
        }
        refreshRouter()
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

        messages.append(ChatMessage(role: .user, text: text))
        inputText = ""
        isThinking = true
        saveHistory()

        Task {
            let result = await router.route(text)
            let reply  = await executor.execute(result)
            messages.append(ChatMessage(role: .assistant, text: reply))
            isThinking = false
            saveHistory()
        }
    }

    func clearHistory() {
        messages = []
        UserDefaults.standard.removeObject(forKey: historyKey)
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(Array(messages.suffix(200))) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
}

struct ChatView: View {
    @State private var vm = ChatViewModel()
    @FocusState private var inputFocused: Bool
    @State private var showSettings = false

    var body: some View {
        let settings = AppSettings.shared
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

                    Button { vm.send() } label: {
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
                        Text(statusText(settings))
                            .font(.caption2)
                            .foregroundColor(statusColor(settings))
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
            .onChange(of: AppSettings.shared.usePrivateMode) { _ in vm.refreshRouter() }
            .onChange(of: AppSettings.shared.macIP) { _ in vm.refreshRouter() }
        }
    }

    private func statusText(_ s: AppSettings) -> String {
        s.usePrivateMode ? "on-device AI" : (s.isConfigured ? "connected · private" : "mock mode")
    }

    private func statusColor(_ s: AppSettings) -> Color {
        (s.usePrivateMode || s.isConfigured) ? .secondary : .orange
    }
}

struct SettingsSheet: View {
    @State private var draft = AppSettings.shared.macIP
    @Environment(\.dismiss) private var dismiss
    var onClearHistory: (() -> Void)? = nil

    var body: some View {
        let settings = AppSettings.shared
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
                    Toggle("Private Mode (on-device AI)", isOn: Binding(
                        get: { settings.usePrivateMode },
                        set: { settings.usePrivateMode = $0 }
                    ))
                } footer: {
                    Text("Runs AI entirely on your iPhone with no internet. Requires iPhone 15 Pro or later with Apple Intelligence enabled.")
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
        guard let url = URL(string: "http://\(ip):8000/message") else { return }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": "ping", "sender": "ios-test"])
        do {
            let (_, response) = try await URLSession.shared.data(for: req)
            connectionStatus = (response as? HTTPURLResponse)?.statusCode == 200 ? "Connected" : "Server error"
        } catch {
            connectionStatus = "Unreachable — check IP and server"
        }
    }
}

#Preview {
    ChatView()
}
