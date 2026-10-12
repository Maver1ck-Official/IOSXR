import SwiftUI
import UIKit
import WebKit

struct BrowserView: View {
    @State private var address = "https://www.google.com"
    @State private var pageURL = URL(string: "https://www.google.com")!
    @State private var showingInvalidAddress = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)

                    TextField("Search or enter a website", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(size: 14))
                        .onSubmit(loadAddress)

                    Button(action: loadAddress) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.9)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 10)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Go to address")
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 15))
                .overlay {
                    RoundedRectangle(cornerRadius: 15)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                BrowserWebView(url: pageURL)
            }
            .background(Color(red: 0.035, green: 0.045, blue: 0.075))
            .navigationTitle("Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(red: 0.035, green: 0.045, blue: 0.075), for: .navigationBar)
        }
        .alert("Invalid address", isPresented: $showingInvalidAddress) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enter a valid HTTP or HTTPS web address.")
        }
    }

    private func loadAddress() {
        let candidate = address.contains("://") ? address : "https://" + address
        guard
            let url = URL(string: candidate),
            let scheme = url.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            url.host != nil
        else {
            showingInvalidAddress = true
            return
        }
        pageURL = url
    }
}

private struct BrowserWebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 0.035, green: 0.045, blue: 0.075, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard
                let scheme = navigationAction.request.url?.scheme?.lowercased(),
                scheme == "http" || scheme == "https"
            else {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }
    }
}
