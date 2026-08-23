import SwiftUI
import WebKit

struct HostedBookingView: View {
    let title: String
    let url: URL

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var reloadID = UUID()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                WebPageView(url: url, isLoading: $isLoading, loadError: $loadError)
                    .id(reloadID)
                    .ignoresSafeArea(edges: .bottom)

                if isLoading && loadError == nil {
                    ProgressView()
                        .controlSize(.large)
                }

                if let loadError {
                    LoadErrorView(
                        message: loadError,
                        reload: reload,
                        openInBrowser: { openURL(url) }
                    )
                }

                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .labelStyle(.titleAndIcon)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.leading, 12)
            }
            .task(id: reloadID) {
                await markAsTimedOutIfNeeded()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func reload() {
        loadError = nil
        isLoading = true
        reloadID = UUID()
    }

    private func markAsTimedOutIfNeeded() async {
        try? await Task.sleep(for: .seconds(12))
        guard !Task.isCancelled, isLoading else {
            return
        }

        isLoading = false
        loadError = "The booking page is taking too long to load. Check that the app has outgoing network access, then try again."
    }
}

private struct LoadErrorView: View {
    let message: String
    let reload: () -> Void
    let openInBrowser: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(.teal)

            Text("Booking page could not load")
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Try Again", action: reload)
                    .buttonStyle(.borderedProminent)

                Button("Open in Safari", action: openInBrowser)
                    .buttonStyle(.bordered)
            }
        }
        .padding(24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

private struct WebPageView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadError: String?

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, loadError: $loadError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        if #available(iOS 16.4, macOS 13.3, *) {
            webView.isInspectable = true
        }

        webView.load(URLRequest(url: url, timeoutInterval: 15))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        @Binding private var isLoading: Bool
        @Binding private var loadError: String?

        init(isLoading: Binding<Bool>, loadError: Binding<String?>) {
            _isLoading = isLoading
            _loadError = loadError
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
            loadError = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            show(error)
        }

        private func show(_ error: Error) {
            isLoading = false
            loadError = error.localizedDescription
        }
    }
}
