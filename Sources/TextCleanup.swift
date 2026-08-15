import Foundation

enum TextCleanup {
    /// 行尾出现这些标点，说明这一行本身就是完整句子，不该和下一行接起来
    private static let sentenceEnders: Set<Character> = [
        "。", "！", "？", "；", "：", "…", ".", "!", "?", ";", ":",
    ]
    private static let bulletPrefixes = ["-", "*", "•", "·", "–", "—", "+"]

    /// 把 Vision 的视觉断行合并回段落。
    ///
    /// Vision 按图像上的行返回文本，一段话会被切成许多行，粘贴出去不连贯。
    /// 这里只处理「明显是同一段被切断」的情况，句末标点、列表项、空行都保持原样——
    /// 宁可少合并，也不要把代码或列表揉成一团。
    static func mergeParagraphs(_ text: String) -> String {
        var result: [String] = []

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let previous = result.last

            if line.isEmpty || previous == nil || previous!.isEmpty {
                result.append(line)
            } else if shouldKeepBreak(after: previous!, before: line) {
                result.append(line)
            } else {
                result[result.count - 1] = previous! + joiner(previous!, line) + line
            }
        }
        return result.joined(separator: "\n")
    }

    private static func shouldKeepBreak(after previous: String, before next: String) -> Bool {
        if let tail = previous.last, sentenceEnders.contains(tail) { return true }
        if bulletPrefixes.contains(where: { next.hasPrefix($0) }) { return true }
        return next.range(of: #"^\d+[.)、]"#, options: .regularExpression) != nil
    }

    /// 中日韩字符之间直接相接；只要有一侧是西文就补空格，避免两个单词粘在一起
    private static func joiner(_ previous: String, _ next: String) -> String {
        guard let tail = previous.last, let head = next.first else { return "" }
        return isCJK(tail) && isCJK(head) ? "" : " "
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x3000...0x303F, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0xFF00...0xFFEF:
            return true
        default:
            return false
        }
    }
}
