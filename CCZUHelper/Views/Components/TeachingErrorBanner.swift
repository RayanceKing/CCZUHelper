import SwiftUI

/// Inline failure feedback keeps cached content visible without implying it is current.
struct TeachingErrorBanner: View {
    let message: String
    var showsCachedData = false
    var isRetrying = false
    var retry: (() -> Void)?
    @State private var showLogin = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
            if showsCachedData {
                Text("teaching.error.cached_data".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let retry {
                HStack {
                    Button("common.retry".localized, action: retry)
                        .disabled(isRetrying)
                    if TeachingErrorPresentation.requiresLogin(message) {
                        Button("login.title".localized) { showLogin = true }
                            .disabled(isRetrying)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showLogin, onDismiss: retry) { LoginView() }
    }
}

struct TeachingErrorPage: View {
    let title: String
    let message: String
    let retry: () -> Void
    @State private var showLogin = false

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("common.retry".localized, action: retry)
            if TeachingErrorPresentation.requiresLogin(message) {
                Button("login.title".localized) { showLogin = true }
            }
        }
        .sheet(isPresented: $showLogin, onDismiss: retry) { LoginView() }
    }
}

extension View {
    func teachingRefreshError(
        _ message: String?, hasCachedData: Bool, isLoading: Bool, retry: @escaping () -> Void
    ) -> some View {
        safeAreaInset(edge: .top, spacing: 0) {
            if let message, hasCachedData {
                TeachingErrorBanner(message: message, showsCachedData: true, isRetrying: isLoading, retry: retry)
            }
        }
    }
}
