import Foundation

// MARK: - User

struct SlackUser: Codable, Identifiable {
    let id: String
    let name: String
    let realName: String?
    let profile: SlackUserProfile?
    let color: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case realName = "real_name"
        case profile, color
    }
}

struct SlackUserProfile: Codable {
    let displayName: String?
    let realName: String?
    let image72: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case realName = "real_name"
        case image72 = "image_72"
    }
}

// MARK: - Channel

struct SlackChannel: Codable, Identifiable {
    let id: String
    let name: String
    let purpose: SlackChannelPurpose?
    let created: Int?
}

struct SlackChannelPurpose: Codable {
    let value: String?
}

// MARK: - Message

struct SlackMessage: Codable, Identifiable {
    let ts: String?
    let user: String?
    let text: String?
    let subtype: String?
    let threadTs: String?
    let replyCount: Int?
    let replyUsers: [String]?
    let username: String?
    let userProfile: SlackMessageUserProfile?
    let files: [SlackFile]?
    let attachments: [SlackAttachment]?
    let botId: String?

    // Stable ID — generated once at decode time, not recomputed
    let stableId: String

    var id: String { stableId }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ts = try c.decodeIfPresent(String.self, forKey: .ts)
        user = try c.decodeIfPresent(String.self, forKey: .user)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        subtype = try c.decodeIfPresent(String.self, forKey: .subtype)
        threadTs = try c.decodeIfPresent(String.self, forKey: .threadTs)
        replyCount = try c.decodeIfPresent(Int.self, forKey: .replyCount)
        replyUsers = try c.decodeIfPresent([String].self, forKey: .replyUsers)
        username = try c.decodeIfPresent(String.self, forKey: .username)
        userProfile = try c.decodeIfPresent(SlackMessageUserProfile.self, forKey: .userProfile)
        files = try c.decodeIfPresent([SlackFile].self, forKey: .files)
        attachments = try c.decodeIfPresent([SlackAttachment].self, forKey: .attachments)
        botId = try c.decodeIfPresent(String.self, forKey: .botId)
        stableId = ts ?? UUID().uuidString
    }

    var isThreadParent: Bool {
        (replyCount ?? 0) > 0
    }

    var isReply: Bool {
        threadTs != nil && threadTs != ts
    }

    /// System/event messages that should be rendered differently
    var isSystemMessage: Bool {
        guard let subtype else { return false }
        return !["bot_message", "thread_broadcast", "file_share"].contains(subtype)
    }

    enum CodingKeys: String, CodingKey {
        case ts, user, text, subtype
        case threadTs = "thread_ts"
        case replyCount = "reply_count"
        case replyUsers = "reply_users"
        case username
        case userProfile = "user_profile"
        case files, attachments
        case botId = "bot_id"
    }
}

struct SlackMessageUserProfile: Codable {
    let displayName: String?
    let realName: String?

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case realName = "real_name"
    }
}

// MARK: - File

struct SlackFile: Codable, Identifiable {
    let fileId: String?
    let name: String?
    let title: String?
    let mimetype: String?
    let size: Int?

    let id: String

    var isImage: Bool {
        mimetype?.hasPrefix("image/") ?? false
    }

    enum CodingKeys: String, CodingKey {
        case fileId = "id"
        case name, title, mimetype, size
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileId = try c.decodeIfPresent(String.self, forKey: .fileId)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        mimetype = try c.decodeIfPresent(String.self, forKey: .mimetype)
        size = try c.decodeIfPresent(Int.self, forKey: .size)
        id = fileId ?? UUID().uuidString
    }
}

// MARK: - Attachment

struct SlackAttachment: Codable, Identifiable {
    let title: String?
    let titleLink: String?
    let text: String?
    let fallback: String?
    let color: String?
    let isMsgUnfurl: Bool?
    let isShare: Bool?
    let authorName: String?

    let stableId: String

    var id: String { stableId }

    enum CodingKeys: String, CodingKey {
        case title
        case titleLink = "title_link"
        case text, fallback, color
        case isMsgUnfurl = "is_msg_unfurl"
        case isShare = "is_share"
        case authorName = "author_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        titleLink = try c.decodeIfPresent(String.self, forKey: .titleLink)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        fallback = try c.decodeIfPresent(String.self, forKey: .fallback)
        color = try c.decodeIfPresent(String.self, forKey: .color)
        isMsgUnfurl = try c.decodeIfPresent(Bool.self, forKey: .isMsgUnfurl)
        isShare = try c.decodeIfPresent(Bool.self, forKey: .isShare)
        authorName = try c.decodeIfPresent(String.self, forKey: .authorName)
        stableId = titleLink ?? title ?? fallback ?? UUID().uuidString
    }
}

// MARK: - Helpers

extension Optional where Wrapped == String {
    var nonEmpty: String? {
        guard let self, !self.isEmpty else { return nil }
        return self
    }
}
