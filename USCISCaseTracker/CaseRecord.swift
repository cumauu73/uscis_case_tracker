import Foundation

struct CaseEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let title: String
    let detail: String
    let date: Date

    init(id: UUID = UUID(), title: String, detail: String, date: Date) {
        self.id = id
        self.title = title
        self.detail = detail
        self.date = date
    }
}

struct CaseRecord: Codable, Hashable, Identifiable {
    let id: UUID
    var receiptNumber: String
    var nickname: String
    var formType: String
    var statusTitle: String
    var statusDescription: String
    var lastCheckedAt: Date
    var events: [CaseEvent]

    init(
        id: UUID = UUID(),
        receiptNumber: String,
        nickname: String = "",
        formType: String = "USCIS Case",
        statusTitle: String = "Ready to Check",
        statusDescription: String = "Tap Check Latest Status to retrieve the latest available case status.",
        lastCheckedAt: Date = .now,
        events: [CaseEvent] = []
    ) {
        self.id = id
        self.receiptNumber = receiptNumber
        self.nickname = nickname
        self.formType = formType
        self.statusTitle = statusTitle
        self.statusDescription = statusDescription
        self.lastCheckedAt = lastCheckedAt
        self.events = events
    }

    var displayName: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? formType : nickname
    }

    var maskedReceiptNumber: String {
        guard receiptNumber.count > 4 else { return receiptNumber }
        return String(repeating: "*", count: receiptNumber.count - 4) + receiptNumber.suffix(4)
    }
}
