import SwiftUI

struct SidebarView: View {
    @Environment(SlackArchive.self) private var archive
    @Environment(\.openWindow) private var openWindow
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Workspace header
            VStack(alignment: .leading, spacing: 4) {
                Text(archive.workspaceName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 10) {
                    Label(
                        "\((archive.totalMessages + archive.totalReplies).formatted())",
                        systemImage: "message"
                    )
                    if archive.totalFiles > 0 {
                        Label {
                            HStack(spacing: 2) {
                                Text("\(archive.totalFiles.formatted())")
                                if archive.localFileCount > 0 {
                                    Text("(\(archive.localFileCount) local)")
                                        .foregroundStyle(Color(hex: "3EB891"))
                                }
                            }
                        } icon: {
                            Image(systemName: "paperclip")
                        }
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(SlackTheme.sidebarText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(SlackTheme.sidebarBorder)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(SlackTheme.sidebarText)
                TextField("Search messages…", text: Binding(
                    get: { archive.searchQuery },
                    set: { archive.searchQuery = $0 }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .focused($searchFocused)
                .onSubmit {
                    archive.performSearch()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(SlackTheme.sidebarInputBg)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider().background(SlackTheme.sidebarBorder)

            // Section label
            Text("CHANNELS")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(SlackTheme.sidebarText)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)

            // Channel list
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(archive.sortedChannelNames, id: \.self) { name in
                        ChannelRow(
                            name: name,
                            isSelected: name == archive.currentChannelName
                        )
                        .onTapGesture {
                            archive.currentChannelName = name
                            archive.selectedThreadTs = nil
                            archive.searchQuery = ""
                            archive.searchResults = []
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 12)
            }

            Divider().background(SlackTheme.sidebarBorder)

            // Download script button
            Button {
                openWindow(id: "download-script")
            } label: {
                Label("File Download Script", systemImage: "arrow.down.doc")
                    .font(.system(size: 12))
                    .foregroundStyle(SlackTheme.sidebarText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(SlackTheme.sidebarBg)
    }
}

struct ChannelRow: View {
    let name: String
    let isSelected: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 5) {
            Text("#")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? .white.opacity(0.7) : SlackTheme.sidebarText.opacity(0.65))
            Text(name)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : SlackTheme.sidebarText)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    isSelected ? SlackTheme.selectedChannel :
                    isHovered ? Color.white.opacity(0.1) : .clear
                )
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}
