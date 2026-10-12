import SwiftUI
import UIKit
import WebKit

struct BrowserView: View {
    @State private var address = "https://www.example.com"
    @State private var pageURL = URL(string: "https://www.example.com")!
    @State private var showingInvalidAddress = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("HTTPS address", text: $address)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(loadAddress)

                Button("Go", action: loadAddress)
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            BrowserWebView(url: pageURL)
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
