import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CaseStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    debugTesting
                    pricing
                    comparison
                    note
                }
                .padding()
            }
            .background(AppTheme.groupedBackground)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
            Text("Stay ahead of case updates")
                .font(.title.bold())
            Text("Premium adds automatic server checks, push notifications, and room to track more cases without burning through API limits on every device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private var debugTesting: some View {
        #if DEBUG
        VStack(alignment: .leading, spacing: 12) {
            Label("Testing Only", systemImage: "hammer.fill")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
            Text(store.isPremium ? "Premium is enabled for this debug build." : "Enable Premium locally to test higher limits and premium UI before StoreKit is connected.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(store.isPremium ? "Disable Test Premium" : "Enable Premium for Testing") {
                store.setPremiumForTesting(!store.isPremium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
        #else
        EmptyView()
        #endif
    }

    private var pricing: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recommended Pricing")
                .font(.headline)
            HStack(spacing: 12) {
                PriceCard(title: "Monthly", price: "$1.99", subtitle: "Cancel anytime")
                PriceCard(title: "Yearly", price: "$14.99", subtitle: "Best value")
            }
            Text("Purchases will be enabled with App Store Connect products and StoreKit before release.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Free vs Premium")
                .font(.headline)

            PlanRow(icon: "checkmark.circle", title: "Free", details: [
                "Track up to 2 cases",
                "Manual refresh when you open the app",
                "Masked receipt numbers for privacy",
                "Basic status history"
            ])

            PlanRow(icon: "star.circle.fill", title: "Premium", details: [
                "Track up to 10 cases",
                "Automatic backend checks",
                "Push notifications when status changes",
                "Priority refresh and richer history",
                "Designed to protect shared USCIS API limits"
            ])
        }
    }

    private var note: some View {
        Text("This app is not affiliated with USCIS or any government agency. Status information is informational only and is not legal advice.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding()
            .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct PriceCard: View {
    let title: String
    let price: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(price)
                .font(.title2.bold())
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct PlanRow: View {
    let icon: String
    let title: String
    let details: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(title == "Premium" ? AppTheme.accent : .primary)

            ForEach(details, id: \.self) { detail in
                Label(detail, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(AppTheme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }
}
