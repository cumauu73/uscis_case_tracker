import SwiftUI

struct AddCaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CaseStore.self) private var store
    @State private var receiptNumber = ""
    @State private var nickname = ""
    @State private var attemptedSave = false
    @State private var showingPremium = false
    @State private var saveErrorMessage: String?

    private var normalizedNumber: String {
        ReceiptNumber.normalized(receiptNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Number") {
                    TextField("EAC9999103402", text: $receiptNumber)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .onChange(of: receiptNumber) {
                            receiptNumber = String(normalizedNumber.prefix(13))
                        }
                    if attemptedSave && !ReceiptNumber.isValid(receiptNumber) {
                        Label("Enter 3 letters followed by 10 numbers.", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let saveErrorMessage {
                        Label(saveErrorMessage, systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                if !store.canAddCase {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Free plan limit reached", systemImage: "star.circle.fill")
                                .font(.headline)
                                .foregroundStyle(AppTheme.accent)
                            Text("Free users can track up to \(CaseStore.freeCaseLimit) cases. Premium supports up to \(CaseStore.premiumCaseLimit) cases with automatic checks and notifications.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("See Premium") {
                                showingPremium = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section("Optional Name") {
                    TextField("Example: Work Permit", text: $nickname)
                }

                Section {
                    Text("You can find the 13-character receipt number on notices sent by USCIS.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingPremium) {
                PremiumView()
            }
        }
    }

    private func save() {
        attemptedSave = true
        saveErrorMessage = nil

        let number = normalizedNumber
        guard ReceiptNumber.isValid(number) else {
            saveErrorMessage = "Enter 3 letters followed by 10 numbers."
            return
        }

        guard !store.cases.contains(where: { $0.receiptNumber == number }) else {
            saveErrorMessage = "This case is already being tracked."
            return
        }

        guard store.canAddCase else {
            showingPremium = true
            return
        }

        if store.add(receiptNumber: number, nickname: nickname) {
            let addedCase = store.cases.first { $0.receiptNumber == number }
            dismiss()
            if let addedCase {
                Task {
                    await store.refresh(addedCase)
                }
            }
        } else {
            saveErrorMessage = "Unable to save this case. Please check the receipt number and try again."
        }
    }
}
