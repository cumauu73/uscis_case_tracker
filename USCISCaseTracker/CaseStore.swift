import Foundation
import Observation

@MainActor
@Observable
final class CaseStore {
    private(set) var cases: [CaseRecord] = []
    var alertMessage: String?
    private let storageKey = "saved-cases-v1"
    private let service = CaseStatusService()

    init() {
        load()
    }

    func add(receiptNumber: String, nickname: String) -> Bool {
        let number = ReceiptNumber.normalized(receiptNumber)
        guard ReceiptNumber.isValid(number),
              !cases.contains(where: { $0.receiptNumber == number }) else {
            return false
        }
        cases.insert(CaseRecord(receiptNumber: number, nickname: nickname), at: 0)
        save()
        return true
    }

    func delete(at offsets: IndexSet) {
        cases.remove(atOffsets: offsets)
        save()
    }

    func refresh(_ record: CaseRecord) async {
        do {
            let response = try await service.fetch(receiptNumber: record.receiptNumber)
            guard let index = cases.firstIndex(where: { $0.id == record.id }) else { return }
            let changed = cases[index].statusTitle != response.title
            if changed {
                cases[index].events.insert(
                    CaseEvent(
                        title: response.title,
                        detail: response.description,
                        date: response.updatedAt
                    ),
                    at: 0
                )
            }
            cases[index].formType = response.formType
            cases[index].statusTitle = response.title
            cases[index].statusDescription = response.description
            cases[index].lastCheckedAt = .now
            save()
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func refreshAll() async {
        let records = cases
        for record in records {
            await refresh(record)
        }
    }

    func addDemoCase() {
        guard cases.isEmpty else { return }
        let event = CaseEvent(
            title: "Case Was Received",
            detail: "USCIS received the case and sent a receipt notice.",
            date: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now
        )
        cases = [
            CaseRecord(
                receiptNumber: "IOE0912345678",
                nickname: "My Application",
                formType: "I-485",
                statusTitle: "Case Is Being Actively Reviewed",
                statusDescription: "Your case is currently being reviewed. No action is required at this time.",
                lastCheckedAt: .now,
                events: [
                    CaseEvent(
                        title: "Case Is Being Actively Reviewed",
                        detail: "USCIS began reviewing the case.",
                        date: .now
                    ),
                    event
                ]
            )
        ]
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([CaseRecord].self, from: data) else {
            return
        }
        cases = saved
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(cases) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
