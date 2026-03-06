//
//  PageFetcher.swift
//  JobsTracker
//
//  Created by Marcos Leal on 3/4/26.
//

import Foundation

/// Downloads a web page directly and strips HTML to extract plain text.
/// No external API or token required.
enum PageFetcher {

    static func fetchPageText(url: String) async throws -> String {
        guard let pageURL = URL(string: url) else {
            throw PageFetchError.invalidURL(url)
        }

        var request = URLRequest(url: pageURL)
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw PageFetchError.httpError(code)
        }

        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            throw PageFetchError.noContent
        }

        let text = stripHTML(html)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PageFetchError.noContent
        }
        return text
    }

    private static func stripHTML(_ html: String) -> String {
        var result = html

        // Remove script and style blocks entirely
        let blockTags = ["script", "style", "head"]
        for tag in blockTags {
            let pattern = "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: ""
                )
            }
        }

        // Insert newlines before block-level elements for readability
        let blockElements = ["<br", "<p[> ]", "<div[> ]", "<li[> ]", "<h[1-6][> ]", "<tr[> ]"]
        for pattern in blockElements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "\n$0"
                )
            }
        }

        // Strip all remaining HTML tags
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: []) {
            result = regex.stringByReplacingMatches(
                in: result,
                range: NSRange(result.startIndex..., in: result),
                withTemplate: ""
            )
        }

        // Decode common HTML entities
        let entities: [(String, String)] = [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'"),
            ("&nbsp;", " "), ("&#x2F;", "/"), ("&ndash;", "–"),
            ("&mdash;", "—"), ("&bull;", "•"), ("&hellip;", "…"),
        ]
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }

        // Decode numeric HTML entities (&#123; and &#x1A;)
        if let numericRegex = try? NSRegularExpression(pattern: "&#(x?[0-9a-fA-F]+);") {
            let matches = numericRegex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let codeRange = Range(match.range(at: 1), in: result) else { continue }
                let codeStr = String(result[codeRange])
                let codePoint: UInt32?
                if codeStr.hasPrefix("x") {
                    codePoint = UInt32(String(codeStr.dropFirst()), radix: 16)
                } else {
                    codePoint = UInt32(codeStr)
                }
                if let cp = codePoint, let scalar = Unicode.Scalar(cp) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }

        // Collapse multiple blank lines and trim
        let lines = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var collapsed: [String] = []
        var lastWasBlank = false
        for line in lines {
            if line.isEmpty {
                if !lastWasBlank { collapsed.append("") }
                lastWasBlank = true
            } else {
                collapsed.append(line)
                lastWasBlank = false
            }
        }

        return collapsed.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Errors

enum PageFetchError: LocalizedError {
    case invalidURL(String)
    case httpError(Int)
    case noContent

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .httpError(let code):
            return "Page returned HTTP \(code)."
        case .noContent:
            return "No content found on the page."
        }
    }
}
