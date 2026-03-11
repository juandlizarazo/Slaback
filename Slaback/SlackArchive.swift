import Foundation
import Observation

@Observable
class SlackArchive {
    // Data
    var users: [String: SlackUser] = [:]
    var channels: [String: SlackChannel] = [:]
    var channelMessages: [String: [SlackMessage]] = [:]
    var replies: [String: [SlackMessage]] = [:]
    var localFiles: [String: URL] = [:]

    // Navigation state
    var currentChannelName: String?
    var selectedThreadTs: String?
    var searchQuery: String = ""
    var searchResults: [SearchResult] = []

    // UI state
    var isLoaded: Bool = false
    var isLoading: Bool = false
    var loadingProgress: String = ""
    var workspaceName: String = "Slack Export"

    // Stats
    var totalMessages: Int = 0
    var totalReplies: Int = 0
    var totalFiles: Int = 0
    var localFileCount: Int = 0

    // Sorted channel list for sidebar
    var sortedChannelNames: [String] {
        channelMessages.keys.sorted { a, b in
            if a == "general" { return true }
            if b == "general" { return false }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    // Top-level messages for the current channel (not thread replies)
    var currentMessages: [SlackMessage] {
        guard let name = currentChannelName else { return [] }
        return channelMessages[name] ?? []
    }

    // Thread messages for selected thread
    var currentThreadReplies: [SlackMessage] {
        guard let threadTs = selectedThreadTs else { return [] }
        return replies[threadTs] ?? []
    }

    // Thread parent message
    func threadParent(for threadTs: String) -> SlackMessage? {
        for (_, msgs) in channelMessages {
            if let msg = msgs.first(where: { $0.ts == threadTs }) {
                return msg
            }
        }
        return nil
    }

    var currentThreadParent: SlackMessage? {
        guard let threadTs = selectedThreadTs else { return nil }
        return threadParent(for: threadTs)
    }

    // MARK: - Loading

    func loadExport(from url: URL) async {
        isLoading = true
        isLoaded = false
        loadingProgress = "Starting..."

        // Reset state
        users = [:]
        channels = [:]
        channelMessages = [:]
        replies = [:]
        localFiles = [:]
        totalMessages = 0
        totalReplies = 0
        totalFiles = 0
        localFileCount = 0
        currentChannelName = nil
        selectedThreadTs = nil
        searchQuery = ""
        searchResults = []

        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        workspaceName = url.lastPathComponent

        let fm = FileManager.default

        do {
            // Load users.json
            loadingProgress = "Loading users..."
            let usersURL = url.appendingPathComponent("users.json", isDirectory: false)
            if fm.fileExists(atPath: usersURL.path) {
                let data = try Data(contentsOf: usersURL)
                let userList = try JSONDecoder().decode([SlackUser].self, from: data)
                for u in userList { users[u.id] = u }
            }

            // Load channels.json
            loadingProgress = "Loading channels..."
            let channelsURL = url.appendingPathComponent("channels.json", isDirectory: false)
            if fm.fileExists(atPath: channelsURL.path) {
                let data = try Data(contentsOf: channelsURL)
                let channelList = try JSONDecoder().decode([SlackChannel].self, from: data)
                for c in channelList { channels[c.name] = c }
            }

            // Scan channel directories
            loadingProgress = "Loading messages..."
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey]
            )

            let directories = contents.filter { item in
                let vals = try? item.resourceValues(forKeys: [.isDirectoryKey])
                return vals?.isDirectory == true
            }

            var channelDirCount = 0
            let totalDirs = directories.count

            for dir in directories {
                let dirName = dir.lastPathComponent
                guard dirName != "_files" && !dirName.hasPrefix(".") else { continue }

                channelDirCount += 1
                loadingProgress = "Loading channels... \(channelDirCount)/\(totalDirs)"

                let jsonFiles = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                    .filter { $0.pathExtension == "json" }
                    .sorted { $0.lastPathComponent < $1.lastPathComponent }

                var allMessages: [SlackMessage] = []
                for jsonFile in jsonFiles {
                    let data = try Data(contentsOf: jsonFile)
                    let msgs = try JSONDecoder().decode([SlackMessage].self, from: data)
                    allMessages.append(contentsOf: msgs)
                }

                allMessages.sort { (a, b) in
                    let aTs = Double(a.ts ?? "0") ?? 0
                    let bTs = Double(b.ts ?? "0") ?? 0
                    return aTs < bTs
                }

                // Separate top-level messages from replies
                var topLevel: [SlackMessage] = []
                for msg in allMessages {
                    if msg.isReply {
                        if let threadTs = msg.threadTs {
                            replies[threadTs, default: []].append(msg)
                            totalReplies += 1
                        }
                    } else {
                        topLevel.append(msg)
                        totalMessages += 1
                    }
                    // Count files
                    if let files = msg.files {
                        totalFiles += files.count
                    }
                }

                channelMessages[dirName] = topLevel
            }

            // Scan _files directory for local downloads
            loadingProgress = "Indexing local files..."
            let filesDir = url.appendingPathComponent("_files", isDirectory: true)
            if fm.fileExists(atPath: filesDir.path) {
                let fileIdDirs = try fm.contentsOfDirectory(at: filesDir, includingPropertiesForKeys: nil)
                for fileIdDir in fileIdDirs {
                    let fileId = fileIdDir.lastPathComponent
                    guard !fileId.hasPrefix(".") else { continue }
                    let innerFiles = try fm.contentsOfDirectory(at: fileIdDir, includingPropertiesForKeys: nil)
                    if let firstFile = innerFiles.first(where: { !$0.lastPathComponent.hasPrefix(".") }) {
                        localFiles[fileId] = firstFile
                        localFileCount += 1
                    }
                }
            }

            // Auto-select general or first channel
            let names = sortedChannelNames
            if names.contains("general") {
                currentChannelName = "general"
            } else if let first = names.first {
                currentChannelName = first
            }

            isLoaded = true
            loadingProgress = "Done"
        } catch {
            loadingProgress = "Error: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Search

    struct SearchResult: Identifiable {
        let id = UUID()
        let channelName: String
        let message: SlackMessage
    }

    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        let query = searchQuery.lowercased()
        var results: [SearchResult] = []

        // Search top-level messages
        for (channelName, messages) in channelMessages {
            for msg in messages {
                if let text = msg.text?.lowercased(), text.contains(query) {
                    results.append(SearchResult(channelName: channelName, message: msg))
                }
            }
        }

        // Search replies
        for (threadTs, replyMsgs) in replies {
            for msg in replyMsgs {
                if let text = msg.text?.lowercased(), text.contains(query) {
                    // Find which channel this thread belongs to
                    let channelName = findChannel(for: threadTs) ?? "unknown"
                    results.append(SearchResult(channelName: channelName, message: msg))
                }
            }
        }

        // Sort newest first
        results.sort { (a, b) in
            let aTs = Double(a.message.ts ?? "0") ?? 0
            let bTs = Double(b.message.ts ?? "0") ?? 0
            return aTs > bTs
        }

        searchResults = results
    }

    private func findChannel(for threadTs: String) -> String? {
        for (channelName, msgs) in channelMessages {
            if msgs.contains(where: { $0.ts == threadTs }) {
                return channelName
            }
        }
        return nil
    }

    // MARK: - Helpers

    func displayName(for userId: String?) -> String {
        guard let userId else { return "Unknown" }
        guard let user = users[userId] else { return userId }
        return user.profile?.displayName.nonEmpty
            ?? user.profile?.realName.nonEmpty
            ?? user.realName.nonEmpty
            ?? user.name
    }

    func userColor(for userId: String?) -> String {
        guard let userId else { return "999999" }
        if let user = users[userId], let color = user.color {
            return color
        }
        // Hash-based fallback color
        var hash = 0
        for char in userId.unicodeScalars {
            hash = ((hash << 5) &- hash) &+ Int(char.value)
        }
        let palette = SlackTheme.colorPalette
        return palette[abs(hash) % palette.count]
    }

    func localFileURL(for fileId: String?) -> URL? {
        guard let fileId else { return nil }
        return localFiles[fileId]
    }
}
