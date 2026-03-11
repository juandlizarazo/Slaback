import Foundation
import SwiftUI

enum SlackFormatter {

    /// Convert Slack mrkdwn text to a styled AttributedString
    static func format(
        text: String,
        users: [String: SlackUser],
        channels: [String: SlackChannel]
    ) -> AttributedString {
        // First pass: resolve Slack-specific tokens
        var processed = text

        // Replace user mentions: <@U12345> or <@U12345|username>
        processed = resolveUserMentions(processed, users: users)

        // Replace channel refs: <#C12345|channel-name>
        processed = resolveChannelRefs(processed, channels: channels)

        // Replace links: <https://url|display text> or <https://url>
        processed = resolveLinks(processed)

        // Replace special mentions
        processed = processed.replacingOccurrences(of: "<!here|here>", with: "@here")
        processed = processed.replacingOccurrences(of: "<!here>", with: "@here")
        processed = processed.replacingOccurrences(of: "<!channel|channel>", with: "@channel")
        processed = processed.replacingOccurrences(of: "<!channel>", with: "@channel")
        processed = processed.replacingOccurrences(of: "<!everyone|everyone>", with: "@everyone")
        processed = processed.replacingOccurrences(of: "<!everyone>", with: "@everyone")

        // Decode HTML entities that Slack uses
        processed = processed.replacingOccurrences(of: "&amp;", with: "&")
        processed = processed.replacingOccurrences(of: "&lt;", with: "<")
        processed = processed.replacingOccurrences(of: "&gt;", with: ">")

        // Build AttributedString with inline formatting
        return buildAttributedString(from: processed)
    }

    // MARK: - Reference Resolution

    private static func resolveUserMentions(_ text: String, users: [String: SlackUser]) -> String {
        var result = text
        let pattern = try! NSRegularExpression(pattern: "<@(\\w+)(?:\\|([^>]*))?>" )
        let nsText = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        // Process in reverse to preserve ranges
        for match in matches.reversed() {
            let userId = nsText.substring(with: match.range(at: 1))
            let explicitName: String? = match.range(at: 2).location != NSNotFound
                ? nsText.substring(with: match.range(at: 2)) : nil

            let displayName = explicitName.nonEmpty
                ?? users[userId]?.profile?.displayName.nonEmpty
                ?? users[userId]?.realName.nonEmpty
                ?? users[userId]?.name
                ?? userId

            result = (result as NSString).replacingCharacters(
                in: match.range, with: "@\(displayName)"
            )
        }
        return result
    }

    private static func resolveChannelRefs(_ text: String, channels: [String: SlackChannel]) -> String {
        var result = text
        let pattern = try! NSRegularExpression(pattern: "<#(\\w+)(?:\\|([^>]*))?>" )
        let nsText = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            let channelName: String
            if match.range(at: 2).location != NSNotFound {
                channelName = nsText.substring(with: match.range(at: 2))
            } else {
                let channelId = nsText.substring(with: match.range(at: 1))
                channelName = channels.values.first(where: { $0.id == channelId })?.name ?? channelId
            }
            result = (result as NSString).replacingCharacters(
                in: match.range, with: "#\(channelName)"
            )
        }
        return result
    }

    private static func resolveLinks(_ text: String) -> String {
        var result = text
        let pattern = try! NSRegularExpression(pattern: "<(https?://[^|>]+)(?:\\|([^>]+))?>" )
        let nsText = text as NSString
        let matches = pattern.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        for match in matches.reversed() {
            let url = nsText.substring(with: match.range(at: 1))
            let display: String
            if match.range(at: 2).location != NSNotFound {
                display = nsText.substring(with: match.range(at: 2))
            } else {
                display = url
            }
            result = (result as NSString).replacingCharacters(in: match.range, with: display)
        }
        return result
    }

    // MARK: - AttributedString Builder

    private static func buildAttributedString(from text: String) -> AttributedString {
        var result = AttributedString()

        // Split by code blocks (```) first
        let parts = text.components(separatedBy: "```")
        for (index, part) in parts.enumerated() {
            if index % 2 == 1 {
                // Code block
                var codeStr = AttributedString(part.trimmingCharacters(in: .newlines))
                codeStr.font = .system(.body, design: .monospaced)
                codeStr.foregroundColor = Color(hex: "abb2bf")
                codeStr.backgroundColor = Color(hex: "2c2d30")
                result.append(AttributedString("\n"))
                result.append(codeStr)
                result.append(AttributedString("\n"))
            } else {
                // Normal text with inline formatting
                result.append(parseInlineFormatting(part))
            }
        }

        return result
    }

    private static func parseInlineFormatting(_ text: String) -> AttributedString {
        var result = AttributedString()
        var scanner = text[...]

        while !scanner.isEmpty {
            // Inline code: `text`
            if scanner.first == "`" {
                let rest = scanner.dropFirst()
                if let endIdx = rest.firstIndex(of: "`") {
                    let code = String(rest[rest.startIndex..<endIdx])
                    var codeAttr = AttributedString(code)
                    codeAttr.font = .system(.body, design: .monospaced)
                    codeAttr.foregroundColor = Color(hex: "e06c75")
                    codeAttr.backgroundColor = Color(hex: "2c2d30")
                    result.append(codeAttr)
                    scanner = rest[rest.index(after: endIdx)...]
                    continue
                } else {
                    result.append(AttributedString("`"))
                    scanner = rest
                    continue
                }
            }

            // Bold: *text*
            if scanner.first == "*" {
                if let styled = extractDelimited(&scanner, delimiter: "*") {
                    var attr = parseInlineFormatting(styled)
                    attr.font = .body.bold()
                    result.append(attr)
                    continue
                }
            }

            // Italic: _text_
            if scanner.first == "_" {
                if let styled = extractDelimited(&scanner, delimiter: "_") {
                    var attr = parseInlineFormatting(styled)
                    attr.font = .body.italic()
                    result.append(attr)
                    continue
                }
            }

            // Strikethrough: ~text~
            if scanner.first == "~" {
                if let styled = extractDelimited(&scanner, delimiter: "~") {
                    var attr = AttributedString(styled)
                    attr.strikethroughStyle = .single
                    result.append(attr)
                    continue
                }
            }

            // Regular character
            let char = scanner.removeFirst()
            result.append(AttributedString(String(char)))
        }

        return result
    }

    private static func extractDelimited(_ scanner: inout Substring, delimiter: Character) -> String? {
        guard scanner.first == delimiter else { return nil }
        let rest = scanner.dropFirst()

        // Don't match if the next char is whitespace or the same delimiter
        guard let firstChar = rest.first, firstChar != delimiter, !firstChar.isWhitespace else {
            return nil
        }

        guard let endIdx = rest.firstIndex(of: delimiter) else { return nil }

        // Don't match if the char before the closing delimiter is whitespace
        let beforeEnd = rest.index(before: endIdx)
        if rest[beforeEnd].isWhitespace { return nil }

        let content = String(rest[rest.startIndex..<endIdx])
        guard !content.isEmpty, !content.contains("\n") else { return nil }
        scanner = rest[rest.index(after: endIdx)...]
        return content
    }
}


