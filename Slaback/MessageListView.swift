import SwiftUI

struct MessageListView: View {
    @Environment(SlackArchive.self) private var archive

    var body: some View {
        VStack(spacing: 0) {
            // Channel header
            channelHeader

            Divider()

            // Show search results or messages
            if !archive.searchResults.isEmpty {
                SearchResultsView()
            } else if let channelName = archive.currentChannelName {
                messageList(for: channelName)
            } else {
                emptyState
            }
        }
        .background(SlackTheme.mainBg)
    }

    // MARK: - Channel Header

    private var channelHeader: some View {
        HStack(spacing: 8) {
            if !archive.searchResults.isEmpty {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(SlackTheme.secondaryText)
                Text("\"\(archive.searchQuery)\"")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("— \(archive.searchResults.count) result\(archive.searchResults.count == 1 ? "" : "s")")
                    .font(.system(size: 12))
                    .foregroundStyle(SlackTheme.secondaryText)
            } else if let channelName = archive.currentChannelName {
                Text("# \(channelName)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                if let channel = archive.channels[channelName],
                   let purpose = channel.purpose?.value.nonEmpty {
                    Text("— \(purpose)")
                        .font(.system(size: 12))
                        .foregroundStyle(SlackTheme.secondaryText)
                        .lineLimit(1)
                } else {
                    let count = archive.currentMessages.count
                    Text("\(count.formatted()) message\(count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundStyle(SlackTheme.secondaryText)
                }
            } else {
                Text("Select a channel")
                    .font(.system(size: 15))
                    .foregroundStyle(SlackTheme.secondaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Message List

    private func messageList(for channelName: String) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    let groups = groupedMessages
                    ForEach(groups) { group in
                        DateDivider(date: group.dateString)
                            .id("date-\(group.id)")

                        ForEach(group.messages) { message in
                            MessageView(message: message)
                                .id(message.ts)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .onChange(of: archive.currentChannelName) {
                // Scroll to bottom when switching channels
                if let lastMsg = archive.currentMessages.last {
                    proxy.scrollTo(lastMsg.ts, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundStyle(SlackTheme.secondaryText)
            Text("Select a channel to read messages")
                .foregroundStyle(SlackTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Date Grouping

    private var groupedMessages: [MessageGroup] {
        let messages = archive.currentMessages
        var groups: [MessageGroup] = []
        var currentDateKey = ""
        var currentDateString = ""
        var currentMessages: [SlackMessage] = []

        for msg in messages {
            let dateKey = Self.dateKey(from: msg.ts)
            if dateKey != currentDateKey {
                if !currentMessages.isEmpty {
                    groups.append(MessageGroup(
                        dateKey: currentDateKey,
                        dateString: currentDateString,
                        messages: currentMessages
                    ))
                }
                currentDateKey = dateKey
                currentDateString = Self.formatDate(from: msg.ts)
                currentMessages = [msg]
            } else {
                currentMessages.append(msg)
            }
        }
        if !currentMessages.isEmpty {
            groups.append(MessageGroup(
                dateKey: currentDateKey,
                dateString: currentDateString,
                messages: currentMessages
            ))
        }
        return groups
    }

    private static func dateKey(from ts: String?) -> String {
        guard let ts, let interval = Double(ts) else { return "" }
        let date = Date(timeIntervalSince1970: interval)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func formatDate(from ts: String?) -> String {
        guard let ts, let interval = Double(ts) else { return "Unknown" }
        let date = Date(timeIntervalSince1970: interval)

        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Types

struct MessageGroup: Identifiable {
    let dateKey: String
    let dateString: String
    let messages: [SlackMessage]

    var id: String { dateKey }
}

struct DateDivider: View {
    let date: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(SlackTheme.divider)
                .frame(height: 1)
            Text(date)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SlackTheme.secondaryText)
                .fixedSize()
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .overlay(
                    Capsule()
                        .stroke(SlackTheme.divider, lineWidth: 1)
                )
            Rectangle()
                .fill(SlackTheme.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }
}
