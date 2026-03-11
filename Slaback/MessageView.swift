import SwiftUI

struct MessageView: View {
    let message: SlackMessage
    var inThread: Bool = false
    @Environment(SlackArchive.self) private var archive
    @State private var isHovered = false

    var body: some View {
        if message.isSystemMessage {
            systemMessageView
        } else {
            normalMessageView
        }
    }

    // MARK: - System Message

    private var systemMessageView: some View {
        Text(message.text ?? "")
            .font(.callout)
            .italic()
            .foregroundStyle(SlackTheme.secondaryText)
            .padding(.horizontal, 20)
            .padding(.leading, 48)
            .padding(.vertical, 2)
    }

    // MARK: - Normal Message

    private var normalMessageView: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(
                name: senderName,
                colorHex: archive.userColor(for: message.user ?? message.botId),
                size: 36
            )

            VStack(alignment: .leading, spacing: 2) {
                // Header: sender name + timestamp
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(senderName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(formatTimestamp(message.ts))
                        .font(.system(size: 11))
                        .foregroundStyle(SlackTheme.secondaryText)
                }

                // Message text
                if let text = message.text, !text.isEmpty {
                    Text(SlackFormatter.format(
                        text: text,
                        users: archive.users,
                        channels: archive.channels
                    ))
                    .font(.system(size: 14))
                    .foregroundStyle(SlackTheme.primaryText)
                    .textSelection(.enabled)
                }

                // File attachments
                if let files = message.files {
                    ForEach(files) { file in
                        FileAttachmentView(file: file)
                    }
                }

                // Attachments
                if let attachments = message.attachments {
                    ForEach(attachments) { attachment in
                        AttachmentView(attachment: attachment)
                    }
                }

                // Thread button (only in main view, not in thread panel)
                if !inThread && (message.replyCount ?? 0) > 0 {
                    ThreadButton(
                        replyCount: message.replyCount ?? 0,
                        replyUserIds: message.replyUsers ?? []
                    )
                    .onTapGesture {
                        archive.selectedThreadTs = message.ts
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .background(isHovered ? SlackTheme.messageHoverBg : .clear)
        .onHover { isHovered = $0 }
    }

    // MARK: - Helpers

    private var senderName: String {
        if let profile = message.userProfile {
            if let dn = profile.displayName.nonEmpty { return dn }
            if let rn = profile.realName.nonEmpty { return rn }
        }
        if let username = message.username.nonEmpty { return username }
        return archive.displayName(for: message.user)
    }

    private func formatTimestamp(_ ts: String?) -> String {
        guard let ts, let interval = Double(ts) else { return "" }
        let date = Date(timeIntervalSince1970: interval)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Thread Button

struct ThreadButton: View {
    let replyCount: Int
    let replyUserIds: [String]
    @Environment(SlackArchive.self) private var archive
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            // Reply user avatars (up to 3)
            ForEach(Array(replyUserIds.prefix(3).enumerated()), id: \.offset) { _, userId in
                AvatarView(
                    name: archive.displayName(for: userId),
                    colorHex: archive.userColor(for: userId),
                    size: 20
                )
            }
            Text("\(replyCount) \(replyCount == 1 ? "reply" : "replies")")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(SlackTheme.threadBtnText)
            Image(systemName: "chevron.right")
                .font(.system(size: 9))
                .foregroundStyle(SlackTheme.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? SlackTheme.threadBtnText : SlackTheme.divider, lineWidth: 1)
                .fill(isHovered ? SlackTheme.threadBtnText.opacity(0.1) : .clear)
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
}

// MARK: - File Attachment

struct FileAttachmentView: View {
    let file: SlackFile
    @Environment(SlackArchive.self) private var archive
    @State private var showLightbox = false

    var body: some View {
        if file.isImage {
            imageView
        } else {
            filePillView
        }
    }

    @ViewBuilder
    private var imageView: some View {
        if let fileId = file.fileId, let url = archive.localFileURL(for: fileId),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 420, maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(SlackTheme.divider, lineWidth: 1)
                )
                .onTapGesture { showLightbox = true }
                .sheet(isPresented: $showLightbox) {
                    ImageLightboxView(
                        imageURL: url,
                        title: file.title ?? file.name ?? "Image"
                    )
                }
        } else {
            // Image not downloaded
            missingFileView(icon: "photo")
        }
    }

    private var filePillView: some View {
        Group {
            if let fileId = file.fileId, let url = archive.localFileURL(for: fileId) {
                // Local file - clickable to open
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    filePillContent(isLocal: true)
                }
                .buttonStyle(.plain)
            } else {
                filePillContent(isLocal: false)
            }
        }
    }

    private func filePillContent(isLocal: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: iconForFile)
                .font(.title3)
                .foregroundStyle(SlackTheme.linkText)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name ?? file.title ?? "File")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SlackTheme.linkText)
                    .lineLimit(1)
                if let size = file.size {
                    Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                        .font(.system(size: 11))
                        .foregroundStyle(SlackTheme.secondaryText)
                }
            }
            if isLocal {
                Spacer()
                Text("local")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "3EB891"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: 360, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(SlackTheme.divider, lineWidth: 1)
                .fill(SlackTheme.messageHoverBg)
        )
    }

    private func missingFileView(icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(SlackTheme.secondaryText)
            Text(file.name ?? file.title ?? "File")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SlackTheme.primaryText)
                .lineLimit(1)
            if let size = file.size {
                Text(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))
                    .font(.system(size: 11))
                    .foregroundStyle(SlackTheme.secondaryText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundStyle(SlackTheme.divider)
        )
    }

    private var iconForFile: String {
        guard let mime = file.mimetype else { return "doc" }
        if mime.contains("pdf") { return "doc.richtext" }
        if mime.contains("zip") || mime.contains("tar") || mime.contains("gzip") { return "archivebox" }
        if mime.hasPrefix("video/") { return "film" }
        if mime.hasPrefix("audio/") { return "waveform" }
        if mime.contains("spreadsheet") || mime.contains("csv") { return "tablecells" }
        if mime.hasPrefix("text/") { return "doc.text" }
        return "doc"
    }
}

// MARK: - Attachment (Link Unfurl / Share)

struct AttachmentView: View {
    let attachment: SlackAttachment

    var body: some View {
        HStack(spacing: 0) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: attachment.color ?? "565758"))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                if let authorName = attachment.authorName.nonEmpty {
                    Text(authorName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(SlackTheme.secondaryText)
                }
                if let title = attachment.title.nonEmpty {
                    if let link = attachment.titleLink, let url = URL(string: link) {
                        Link(title, destination: url)
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Text(title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                if let text = (attachment.text ?? attachment.fallback).nonEmpty {
                    Text(text)
                        .font(.system(size: 13))
                        .foregroundStyle(SlackTheme.secondaryText)
                        .lineLimit(5)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 6)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(SlackTheme.messageHoverBg)
        )
        .frame(maxWidth: 520, alignment: .leading)
    }
}
