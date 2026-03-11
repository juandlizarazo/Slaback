import SwiftUI

struct SearchResultsView: View {
    @Environment(SlackArchive.self) private var archive

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Search Results")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("\(archive.searchResults.count) result\(archive.searchResults.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(SlackTheme.secondaryText)
                Button {
                    archive.searchQuery = ""
                    archive.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(SlackTheme.secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if archive.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundStyle(SlackTheme.secondaryText)
                    Text("No results found")
                        .foregroundStyle(SlackTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(archive.searchResults.prefix(200)) { result in
                            SearchResultRow(result: result)
                                .onTapGesture {
                                    archive.currentChannelName = result.channelName
                                    archive.selectedThreadTs = nil
                                    archive.searchQuery = ""
                                    archive.searchResults = []
                                }
                        }
                    }
                }
            }
        }
        .background(SlackTheme.mainBg)
    }
}

struct SearchResultRow: View {
    let result: SlackArchive.SearchResult
    @Environment(SlackArchive.self) private var archive
    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("#\(result.channelName)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SlackTheme.linkText)
                Text("·")
                    .foregroundStyle(SlackTheme.secondaryText)
                Text(archive.displayName(for: result.message.user))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(SlackTheme.secondaryText)
                Text("·")
                    .foregroundStyle(SlackTheme.secondaryText)
                Text(formatTimestamp(result.message.ts))
                    .font(.system(size: 11))
                    .foregroundStyle(SlackTheme.secondaryText)
            }

            Text(result.message.text ?? "")
                .font(.system(size: 13))
                .foregroundStyle(SlackTheme.primaryText)
                .lineLimit(3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovered ? SlackTheme.messageHoverBg : .clear)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }

    private func formatTimestamp(_ ts: String?) -> String {
        guard let ts, let interval = Double(ts) else { return "" }
        let date = Date(timeIntervalSince1970: interval)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: date)
    }
}
