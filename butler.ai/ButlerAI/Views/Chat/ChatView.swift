import SwiftUI

struct ChatView: View {

    @EnvironmentObject var vm: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(vm.messages) { message in
                                    MessageBubbleView(message: message)
                                        .id(message.id)
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }

                                // Streaming bubble
                                if vm.isStreaming && !vm.streamingContent.isEmpty {
                                    MessageBubbleView(message: ChatMessage(
                                        role: .assistant,
                                        content: vm.streamingContent,
                                        isStreaming: true
                                    ))
                                    .id("streaming")
                                }

                                // Typing indicator (before first token)
                                if vm.isStreaming && vm.streamingContent.isEmpty {
                                    TypingIndicatorView()
                                        .id("typing")
                                }

                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.vertical)
                            .padding(.horizontal, 4)
                        }
                        .onChange(of: vm.messages.count) { _ in
                            withAnimation(.spring(response: 0.4)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: vm.streamingContent) { _ in
                            proxy.scrollTo("streaming", anchor: .bottom)
                        }
                        .onChange(of: vm.isStreaming) { streaming in
                            if !streaming {
                                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                            }
                        }
                    }

                    // Suggested prompts (when no input)
                    if vm.inputText.isEmpty && !vm.isStreaming {
                        suggestedPromptsRow
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Input bar
                    inputBar
                }
            }
            .navigationTitle("Butler AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .pulsing()
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Plan My Day") {
                            Task { await vm.generateDayPlan() }
                        }
                        Button("Clear History", role: .destructive) {
                            vm.clearHistory()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .animation(.spring(response: 0.3), value: vm.messages.count)
    }

    // MARK: - Suggested Prompts

    var suggestedPromptsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(vm.suggestedPrompts, id: \.self) { prompt in
                    Button {
                        vm.inputText = prompt
                        isInputFocused = true
                    } label: {
                        Text(prompt)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.15))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Input Bar

    var inputBar: some View {
        HStack(spacing: 10) {
            // Text field
            HStack {
                TextField("Ask Butler anything...", text: $vm.inputText, axis: .vertical)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(.purple)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onSubmit {
                        if !vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            vm.sendMessage()
                        }
                    }

                if !vm.inputText.isEmpty {
                    Button {
                        vm.inputText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Send / Stop button
            Button {
                if vm.isStreaming {
                    vm.cancelStreaming()
                } else {
                    vm.sendMessage()
                    isInputFocused = false
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(vm.inputText.isEmpty && !vm.isStreaming ? Color.white.opacity(0.1) : Color.purple)
                        .frame(width: 42, height: 42)

                    Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(vm.inputText.isEmpty && !vm.isStreaming ? .white.opacity(0.3) : .white)
                }
            }
            .disabled(vm.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !vm.isStreaming)
            .animation(.spring(response: 0.3), value: vm.inputText.isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(red: 0.08, green: 0.06, blue: 0.12))
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {

    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Text("B")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == i ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            Spacer()
        }
        .padding(.horizontal, 8)
        .onAppear {
            phase = 1
        }
    }
}
