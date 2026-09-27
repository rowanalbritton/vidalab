import SwiftUI

/// Renders the small slice of Markdown the website's content uses: headings,
/// bullet and numbered lists, and paragraphs with inline bold, italics, and
/// links.
///
/// SwiftUI's `Text(markdown:)` only handles inline styling, so a guide written
/// as "## Common Symptoms\n\n- Fatigue" would otherwise show its pound signs
/// and dashes as literal characters.
struct MarkdownBlocks: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.blocks(from: markdown).enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let text):
                    Text(Self.inline(text))
                        .font(Vida.sans(16, weight: .semibold))
                        .foregroundStyle(Vida.forest)
                        .padding(.top, 4)
                case .bullet(let marker, let text):
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(marker)
                            .font(Vida.sans(15, weight: .semibold))
                            .foregroundStyle(Vida.moss)
                        Text(Self.inline(text))
                            .font(Vida.sans(15))
                            .foregroundStyle(Vida.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                case .paragraph(let text):
                    Text(Self.inline(text))
                        .font(Vida.sans(15))
                        .foregroundStyle(Vida.ink)
                        .lineSpacing(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Vida.moss)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    nonisolated enum Block: Equatable, Sendable {
        case heading(String)
        case bullet(marker: String, text: String)
        case paragraph(String)
    }

    /// Splits text into blocks. Consecutive plain lines join into a single
    /// paragraph, as they would on the website.
    nonisolated static func blocks(from markdown: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []

        func flush() {
            if !paragraph.isEmpty {
                blocks.append(.paragraph(paragraph.joined(separator: " ")))
                paragraph.removeAll()
            }
        }

        for rawLine in markdown.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
            } else if line.hasPrefix("#") {
                flush()
                let text = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                if !text.isEmpty { blocks.append(.heading(text)) }
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flush()
                blocks.append(.bullet(marker: "•", text: String(line.dropFirst(2))))
            } else if let match = line.firstMatch(of: /^(\d+)[.)]\s+(.*)$/) {
                flush()
                blocks.append(.bullet(marker: "\(match.1).", text: String(match.2)))
            } else {
                paragraph.append(line)
            }
        }
        flush()
        return blocks
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
