import SwiftUI

struct AddCaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CaseStore.self) private var store
    @State private var receiptNumber = ""
    @State private var nickname = ""
    @State private var attemptedSave = false
    @State private var showingPremium = false

    private var normalizedNumber: String {
        ReceiptNumber.normalized(receiptNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Receipt Number") {
                    TextField("IOE0912345678", text: $receiptNumber)
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
                        attemptedSave = true
                        if store.add(receiptNumber: receiptNumber, nickname: nickname) {
                            dismiss()
                        } else if !store.canAddCase {
                            showingPremium = true
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!store.canAddCase)
                }
            }
            .sheet(isPresented: $showingPremium) {
                PremiumView()
            }
        }
    }
}
