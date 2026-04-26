# Skill: build-chat-interface

Build or update the iMessage-style chat UI in the SwiftUI iOS app.

## Relevant Files

- `FreeFall/FreeFall/Views/ChatView.swift` — main chat screen + ChatViewModel
- `FreeFall/FreeFall/Views/MessageBubble.swift` — bubble component + ChatMessage model
- `FreeFall/FreeFall/Views/TypingIndicator.swift` — animated "thinking" indicator
- `FreeFall/FreeFall/Model/IntentResult.swift` — data model for router output
- `FreeFall/FreeFall/Model/MessageRouting.swift` — routing protocol + MockMessageRouter

## Current State (as of April 2026)

ChatView, MessageBubble, and TypingIndicator are implemented and functional.
ChatViewModel uses MockMessageRouter by default. ActionExecutor is referenced but
not yet in source — needs implementation or stub.

## Message Bubble Rules

- User messages: blue background, white text, right-aligned, left Spacer(minLength: 60).
- Assistant messages: systemGray5 background, primary text, left-aligned, right Spacer.
- Corner radius: 18, style: .continuous.
- Padding: horizontal 14, vertical 10 inside bubble; horizontal 12 outside.
- Never mix user/assistant styles. `isUser: Bool` drives all styling.

## Input Bar Rules

- TextField with `axis: .vertical`, lineLimit 1...4 (grows with content).
- Capsule background (systemGray6).
- Send button: `arrow.up.circle.fill`, size 32.
- Button disabled when inputText is empty OR isThinking is true.
- Send on Return key (`.onSubmit { vm.send() }`).
- Focus state managed with `@FocusState`.

## Typing / Thinking State

- `isThinking: Bool` on ChatViewModel drives TypingIndicator visibility.
- Typing indicator shown as a left-aligned assistant bubble with animated dots.
- ScrollView auto-scrolls to typing indicator when it appears.
- ScrollView auto-scrolls to last message when messages.count changes.
- Use `withAnimation` on all scroll calls.

## Message History

- `messages: [ChatMessage]` stored on ChatViewModel as `@Published`.
- `ChatMessage` has `id: UUID`, `text: String`, `isUser: Bool`.
- Use `LazyVStack` inside `ScrollView` for performance.
- Use `ScrollViewReader` + `.id(msg.id)` for scroll targeting.

## Navigation / Header

- `NavigationStack` with `.navigationBarTitleDisplayMode(.inline)`.
- Principal toolbar item shows "Free Fall" headline + "on device · private" caption.
- Do not add back buttons, settings gear, or avatar unless explicitly requested.

## Adding Real Router

When replacing MockMessageRouter with a real on-device model:
1. Create a new class conforming to `MessageRouting` protocol.
2. Inject via `ChatViewModel(router: RealMessageRouter())`.
3. Never break MockMessageRouter — it's the demo fallback.

## Mobile-First Rules

- Test on iPhone SE (smallest), iPhone 15 Pro, and iPad simulator.
- No hardcoded frame widths. Use Spacer and padding only.
- Safe area respected automatically by NavigationStack.
- Dark mode must work — use semantic colors (`Color(.systemGray5)`, `.primary`).

## Definition of Done

- [ ] Bubbles render correctly for user and assistant messages.
- [ ] Input bar grows vertically, send button disables when empty.
- [ ] Typing indicator appears/disappears with isThinking.
- [ ] ScrollView follows new messages automatically.
- [ ] Builds with no Xcode warnings.
- [ ] Preview works in Xcode canvas.
