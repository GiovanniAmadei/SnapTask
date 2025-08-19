import SwiftUI

struct MarkdownView: View {
    let text: String
    private let lineSpacing: CGFloat = 4
    private let paragraphSpacing: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: paragraphSpacing) {
            ForEach(parseBlocks(), id: \.id) { block in
                switch block.kind {
                case .heading(let level, let content):
                    switch level {
                    case 1:
                        Text(content).font(.title.bold())
                    case 2:
                        Text(content).font(.headline.bold())
                    default:
                        Text(content).font(.subheadline.bold())
                    }
                case .paragraph(let content):
                    Text(content)
                        .font(.body)
                        .lineSpacing(lineSpacing)
                case .bulleted(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("•")
                                Text(items[i]).lineSpacing(lineSpacing)
                            }
                            .font(.body)
                        }
                    }
                case .numbered(let items):
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(i + 1).")
                                Text(items[i]).lineSpacing(lineSpacing)
                            }
                            .font(.body)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Parsing
    private enum BlockKind {
        case heading(level: Int, content: String)
        case paragraph(content: String)
        case bulleted(items: [String])
        case numbered(items: [String])
    }

    private struct Block {
        let id = UUID()
        let kind: BlockKind
    }

    private func parseBlocks() -> [Block] {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var blocks: [Block] = []
        var paragraphBuffer: [String] = []
        var bulletBuffer: [String] = []
        var numberBuffer: [String] = []

        func flushParagraph() {
            if !paragraphBuffer.isEmpty {
                let content = paragraphBuffer.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    blocks.append(Block(kind: .paragraph(content: content)))
                }
                paragraphBuffer.removeAll()
            }
        }

        func flushBullets() {
            if !bulletBuffer.isEmpty {
                blocks.append(Block(kind: .bulleted(items: bulletBuffer)))
                bulletBuffer.removeAll()
            }
        }

        func flushNumbers() {
            if !numberBuffer.isEmpty {
                blocks.append(Block(kind: .numbered(items: numberBuffer)))
                numberBuffer.removeAll()
            }
        }

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.isEmpty {
                flushParagraph()
                flushBullets()
                flushNumbers()
                continue
            }

            if let (level, title) = parseHeading(line) {
                flushParagraph()
                flushBullets()
                flushNumbers()
                blocks.append(Block(kind: .heading(level: level, content: title)))
                continue
            }

            if line.hasPrefix("- ") || line.hasPrefix("• ") {
                flushParagraph()
                flushNumbers()
                bulletBuffer.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
                continue
            }

            if let numberRange = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                flushParagraph()
                flushBullets()
                let item = String(line[numberRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                numberBuffer.append(item)
                continue
            }

            paragraphBuffer.append(line)
        }

        flushParagraph()
        flushBullets()
        flushNumbers()

        return blocks
    }

    private func parseHeading(_ line: String) -> (Int, String)? {
        if line.hasPrefix("### ") { return (3, String(line.dropFirst(4))) }
        if line.hasPrefix("## ")  { return (2, String(line.dropFirst(3))) }
        if line.hasPrefix("# ")   { return (1, String(line.dropFirst(2))) }
        return nil
    }
}