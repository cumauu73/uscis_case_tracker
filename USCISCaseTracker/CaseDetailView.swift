import SwiftUI

struct CaseDetailView: View {
    @Environment(CaseStore.self) private var store
    let record: CaseRecord
    @State private var isRefreshing = false

    private var current: CaseRecord {
        store.cases.first(where: { $0.id == record.id }) ?? record
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("CURRENT STATUS", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.status)
                    Text(current.statusTitle)
                        .font(.title2.bold())
                    Text(current.statusDescription)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                    HStack {
                        Label(current.formType, systemImage: "doc.text")
                        Spacer()
                        Text(current.maskedReceiptNumber)
                            .font(.caption.monospaced())
                    }
                    .font(.subheadline)
                }
                .padding()
                .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.28), radius: 12, y: 4)

                Button {
                    Task {
                        isRefreshing = true
                        await store.refresh(current)
                        isRefreshing = false
                    }
                } label: {
                    HStack {
                        if isRefreshing { ProgressView() }
                        Text(isRefreshing ? "Checking…" : "Check Latest Status")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isRefreshing)

                VStack(alignment: .leading, spacing: 16) {
                    Text("History")
                        .font(.title3.bold())
                    if current.events.isEmpty {
                        Text("Status changes will appear here after the backend is connected.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(current.events) { event in
                            TimelineRow(event: event)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.groupedBackground)
        .navigationTitle(current.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct TimelineRow: View {
    let event: CaseEvent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppTheme.status)
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(.secondary.opacity(0.25))
                    .frame(width: 2, height: 58)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline)
                Text(event.detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text(event.date, format: .dateTime.month(.abbreviated).day().year())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
