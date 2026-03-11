import SwiftUI

struct ThreadPanelView: View {
    @Environment(SlackArchive.self) private var archive

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Thread")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    archive.selectedThreadTs = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(SlackTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // Thread messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Parent message
                    if let parent = archive.currentThreadParent {
                        MessageView(message: parent, inThread: true)
                    }

                    // Replies divider
                    let replies = archive.currentThreadReplies
                    if !replies.isEmpty {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(SlackTheme.divider)
                                .frame(height: 1)
                            Text("\(replies.count) \(replies.count == 1 ? "reply" : "replies")")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(SlackTheme.secondaryText)
                                .fixedSize()
                            Rectangle()
                                .fill(SlackTheme.divider)
                                .frame(height: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)

                        // Reply messages
                        ForEach(replies) { reply in
                            MessageView(message: reply, inThread: true)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(SlackTheme.mainBg)
    }
}
