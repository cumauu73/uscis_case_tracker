import SwiftUI

enum AppTheme {
    static let accent = Color(red: 0.35, green: 0.82, blue: 0.98)
    static let status = Color(red: 0.45, green: 0.90, blue: 0.78)
    static let groupedBackground = Color(red: 0.04, green: 0.07, blue: 0.10)
    static let cardBackground = Color(red: 0.08, green: 0.12, blue: 0.16)
}

@main
struct USCISCaseTrackerApp: App {
    @State private var store = CaseStore()
    @State private var isShowingLaunchScreen = true

    var body: some Scene {
        WindowGroup {
            ZStack {
                CaseListView()
                    .environment(store)
                    .opacity(isShowingLaunchScreen ? 0 : 1)

                if isShowingLaunchScreen {
                    LaunchLoadingView()
                        .transition(.opacity)
                }
            }
            .tint(AppTheme.accent)
            .preferredColorScheme(.dark)
            .task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(.easeOut(duration: 0.25)) {
                    isShowingLaunchScreen = false
                }
            }
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        ZStack {
            AppTheme.groupedBackground
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(spacing: 8) {
                    Text("Case durumunuz kontrol ediliyor")
                        .font(.headline)
                    Text("Bilgileriniz güncelleniyor...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ProgressView()
                    .tint(AppTheme.accent)
                    .padding(.top, 6)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
        }
    }
}
