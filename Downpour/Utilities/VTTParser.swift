//
//  VTTParser.swift
//  Downpour
//

import Foundation

struct SubtitleCue {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
}

enum VTTParser {
    static func parse(url: URL) -> [SubtitleCue] {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return []
        }
        return parse(content: content)
    }

    static func parse(content: String) -> [SubtitleCue] {
        var cues: [SubtitleCue] = []
        let lines = content.components(separatedBy: .newlines)
        var i = 0

        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Look for timestamp line (00:00:00.000 --> 00:00:00.000)
            if line.contains("-->") {
                let parts = line.components(separatedBy: "-->")
                if parts.count >= 2 {
                    let startStr = parts[0].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""
                    let endStr = parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? ""

                    if let startTime = parseTimestamp(startStr),
                       let endTime = parseTimestamp(endStr) {
                        // Collect text lines until empty line or next timestamp
                        var textLines: [String] = []
                        i += 1
                        while i < lines.count {
                            let textLine = lines[i]
                            if textLine.trimmingCharacters(in: .whitespaces).isEmpty {
                                break
                            }
                            if textLine.contains("-->") {
                                i -= 1
                                break
                            }
                            // Strip VTT tags like <c>, </c>, <00:00:00.000> and decode HTML entities
                            let cleanedLine = decodeHTMLEntities(
                                textLine
                                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                                    .trimmingCharacters(in: .whitespaces)
                            )
                            if !cleanedLine.isEmpty {
                                textLines.append(cleanedLine)
                            }
                            i += 1
                        }

                        if !textLines.isEmpty {
                            let text = textLines.joined(separator: "\n")
                            cues.append(SubtitleCue(startTime: startTime, endTime: endTime, text: text))
                        }
                    }
                }
            }
            i += 1
        }

        return cues
    }

    private static func decodeHTMLEntities(_ string: String) -> String {
        var result = string
        // Named entities
        let namedEntities: [String: String] = [
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&nbsp;": " ",
            "&lrm;": "\u{200E}",
            "&rlm;": "\u{200F}",
            "&shy;": "\u{00AD}",
            "&ndash;": "–",
            "&mdash;": "—",
            "&hellip;": "…",
            "&lsquo;": "'",
            "&rsquo;": "'",
            "&ldquo;": """,
            "&rdquo;": """,
        ]
        for (entity, char) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        // Numeric entities (decimal): &#123;
        if let regex = try? NSRegularExpression(pattern: "&#(\\d+);", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range).reversed()
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[codeRange]),
                   let scalar = Unicode.Scalar(codePoint) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }
        // Numeric entities (hex): &#x1F600;
        if let regex = try? NSRegularExpression(pattern: "&#[xX]([0-9a-fA-F]+);", options: []) {
            let range = NSRange(result.startIndex..., in: result)
            let matches = regex.matches(in: result, options: [], range: range).reversed()
            for match in matches {
                if let codeRange = Range(match.range(at: 1), in: result),
                   let codePoint = UInt32(result[codeRange], radix: 16),
                   let scalar = Unicode.Scalar(codePoint) {
                    let fullRange = Range(match.range, in: result)!
                    result.replaceSubrange(fullRange, with: String(Character(scalar)))
                }
            }
        }
        return result
    }

    private static func parseTimestamp(_ str: String) -> TimeInterval? {
        // Format: HH:MM:SS.mmm or MM:SS.mmm
        let components = str.components(separatedBy: ":")
        guard components.count >= 2 else { return nil }

        var hours: Double = 0
        var minutes: Double = 0
        var seconds: Double = 0

        if components.count == 3 {
            hours = Double(components[0]) ?? 0
            minutes = Double(components[1]) ?? 0
            seconds = Double(components[2].replacingOccurrences(of: ",", with: ".")) ?? 0
        } else if components.count == 2 {
            minutes = Double(components[0]) ?? 0
            seconds = Double(components[1].replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        return hours * 3600 + minutes * 60 + seconds
    }
}
