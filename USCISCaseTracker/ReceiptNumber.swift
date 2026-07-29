import Foundation

enum ReceiptNumber {
    static func normalized(_ value: String) -> String {
        String(value.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    static func isValid(_ value: String) -> Bool {
        let normalized = normalized(value)
        guard normalized.count == 13 else { return false }
        let prefix = normalized.prefix(3)
        let suffix = normalized.dropFirst(3)
        return prefix.allSatisfy(\.isLetter) && suffix.allSatisfy(\.isNumber)
    }
}

