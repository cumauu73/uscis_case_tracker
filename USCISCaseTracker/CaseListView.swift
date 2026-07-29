import SwiftUI

struct CaseListView: View {
    @Environment(CaseStore.self) private var store
    @State private var showingAddCase = false

    var body: some View {
        NavigationStack {
            Group {
                if store.cases.isEmpty {
                    ContentUnavailableView {
                        Label("No Cases Yet", systemImage: "doc.text.magnifyingglass")
                    } description: {
                        Text("Add a USCIS receipt number to keep your cases organized.")
                    } actions: {
                        Button("Add a Case") { showingAddCase = true }
                            .buttonStyle(.borderedProminent)
                        Button("Preview with Demo Case") { store.addDemoCase() }
                    }
                } else {
                    List {
                        Section {
                            ForEach(store.cases) { record in
                                NavigationLink(value: record.id) {
                                    CaseRow(record: record)
                                }
                            }
                            .onDelete(perform: store.delete)
                        } header: {
                            Text("\(store.cases.count) tracked")
                        } footer: {
                            Text("Status information is informational and does not constitute legal advice.")
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.groupedBackground)
                    .refreshable {
                        await store.refreshAll()
                    }
                }
            }
            .navigationTitle("My USCIS Cases")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAddCase = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add case")
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let record = store.cases.first(where: { $0.id == id }) {
                    CaseDetailView(record: record)
                }
            }
            .sheet(isPresented: $showingAddCase) {
                AddCaseView()
            }
            .alert(
                "Unable to Check Status",
                isPresented: Binding(
                    get: { store.alertMessage != nil },
                    set: { if !$0 { store.alertMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(store.alertMessage ?? "")
            }
        }
    }
}

private struct CaseRow: View {
    let record: CaseRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(record.displayName)
                    .font(.headline)
                Spacer()
                Text(record.formType)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }
            Text(record.statusTitle)
                .font(.subheadline)
                .foregroundStyle(AppTheme.status)
            HStack {
                Text(record.maskedReceiptNumber)
                    .font(.caption.monospaced())
                Spacer()
                Text(record.lastCheckedAt, style: .relative)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .listRowBackground(AppTheme.cardBackground)
    }
}
