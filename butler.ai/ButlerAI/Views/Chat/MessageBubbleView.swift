import SwiftUI

struct MessageBubbleView: View {

    let message: ChatMessage
    @State private var showTimestamp = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser {
                Spacer(minLength: 60)
                userBubble
            } else {
                assistantBubble
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                showTimestamp.toggle()
            }
        }
    }

    // MARK: - User Bubble

    var userBubble: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.purple, Color(red: 0.5, green: 0.2, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 18,
                        bottomLeadingRadius: 18,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 18
                    )
                )

            if showTimestamp {
                Text(message.timestamp.timeAgoDisplay)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Assistant Bubble

    var assistantBubble: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 32, height: 32)
                Text("B")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                // Content with Markdown rendering
                if message.isError {
                    errorContent
                } else {
                    markdownContent
                }

                if showTimestamp && !message.isStreaming {
                    Text(message.timestamp.timeAgoDisplay)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                        .transition(.opacity)
                }
            }
        }
    }

    // MARK: - Markdown Content

    var markdownContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(LocalizedStringKey(message.content))
                .font(.body)
                .foregroundColor(.white)
                .tint(.purple)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            // Streaming cursor
            if message.isStreaming {
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: 2, height: 16)
                        .padding(.trailing, 14)
                        .padding(.bottom, 8)
                }
            }
        }
        .background(Color.white.opacity(0.08))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18
            )
        )
        .overlay(
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 18,
                topTrailingRadius: 18
            )
            .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Error Content

    var errorContent: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message.content)
                .font(.body)
                .foregroundColor(.orange.opacity(0.8))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
