import SwiftUI
import WebKit

// MARK: - MealPlanWebCoordinator
//
// Drives the WKWebView for the UNT meal plan portal.
//
// Extraction strategy: evaluate document.body.innerText on every navigation
// finish at immediate, +0.8s, +1.8s, +4.0s, then feed to BalanceScraper.
//
// URL logic:
//   login.php  → let user fill the form
//   index.php without expand=1 → redirect to balance page
//   Everything else → extract text

final class MealPlanWebCoordinator: NSObject, WKNavigationDelegate {

    var onDataExtracted:  ((MealPlanInfo) -> Void)?
    var onAuthDetected:   (() -> Void)?
    var onLoadingChange:  ((Bool) -> Void)?
    var onSessionExpired: (() -> Void)?

    private let portalHost = "mealplans.unt.edu"
    private(set) var hasExtracted = false
    private var authDetectionScheduled = false

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        onLoadingChange?(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        onLoadingChange?(false)

        let url  = webView.url
        let host = url?.host ?? ""

        #if DEBUG
        print("[MealPlanWeb] didFinish: \(url?.absoluteString ?? "nil")")
        #endif

        if host.contains(portalHost),
           url?.path.contains("index.php") == true,
           url?.query?.contains("expand=1") != true,
           url?.path.contains("login.php") != true {
            let expandURL = URL(string: "https://\(portalHost)/index.php?cid=338&expand=1&")!
            webView.load(URLRequest(url: expandURL))
        }

        extractText(from: webView)

        for delay in [0.8, 1.8, 4.0] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self, let webView, !self.hasExtracted else { return }
                self.extractText(from: webView)
            }
        }

        if !authDetectionScheduled {
            authDetectionScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) { [weak self, weak webView] in
                guard let self, !self.hasExtracted else { return }
                if let currentURL = webView?.url,
                   currentURL.host?.contains(self.portalHost) == true,
                   !currentURL.path.contains("login.php") {
                    self.hasExtracted = true
                    self.onAuthDetected?()
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadingChange?(false)
        #if DEBUG
        print("[MealPlanWeb] didFail: \(error.localizedDescription)")
        #endif
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if let http = navigationResponse.response as? HTTPURLResponse,
           (http.statusCode == 401 || http.statusCode == 403),
           navigationResponse.response.url?.host?.contains(portalHost) == true {
            onSessionExpired?()
        }
        decisionHandler(.allow)
    }

    func extractText(from webView: WKWebView) {
        guard !hasExtracted else { return }
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
            guard let self, !self.hasExtracted else { return }
            let text = result as? String ?? ""
            DispatchQueue.main.async {
                guard !self.hasExtracted, !text.isEmpty else { return }
                if let info = BalanceScraper.parse(text) {
                    self.hasExtracted = true
                    #if DEBUG
                    print("[MealPlanWeb] Extracted: swipes=\(info.diningSwipes ?? -1) flex=\(info.flexBalance ?? -1)")
                    #endif
                    self.onDataExtracted?(info)
                }
            }
        }
    }

    func resetExtraction() {
        hasExtracted = false
        authDetectionScheduled = false
    }
}

// MARK: - MealPlanWebView (UIViewRepresentable)

struct MealPlanWebView: UIViewRepresentable {

    let url:              URL
    var onDataExtracted:  ((MealPlanInfo) -> Void)?
    var onAuthDetected:   (() -> Void)?
    var onLoading:        ((Bool) -> Void)?
    var onSessionExpired: (() -> Void)?

    func makeCoordinator() -> MealPlanWebCoordinator {
        let c = MealPlanWebCoordinator()
        c.onDataExtracted  = onDataExtracted
        c.onAuthDetected   = onAuthDetected
        c.onLoadingChange  = onLoading
        c.onSessionExpired = onSessionExpired
        return c
    }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.load(URLRequest(url: url))
        return wv
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    static func dismantleUIView(_ webView: WKWebView, coordinator: MealPlanWebCoordinator) {
        webView.stopLoading()
    }
}

// MARK: - SilentMealPlanFetcher
//
// Background refresh using existing portal session cookies.
// Returns a FetchResult distinguishing between:
//   .success(MealPlanInfo) — balance data parsed
//   .sessionExpired        — portal redirected to login.php
//   .parseFailed           — page loaded but no balance data found

final class SilentMealPlanFetcher: NSObject, WKNavigationDelegate {

    enum FetchResult {
        case success(MealPlanInfo)
        case sessionExpired
        case parseFailed
    }

    private var webView:    WKWebView?
    private var completion: ((FetchResult) -> Void)?
    private var completed   = false
    private let portalHost  = "mealplans.unt.edu"
    private var pageLoaded  = false

    func fetch(completion: @escaping (FetchResult) -> Void) {
        self.completion = completion
        self.completed  = false
        self.pageLoaded = false

        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        wv.navigationDelegate = self
        self.webView = wv

        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first?.windows.first {
            window.addSubview(wv)
            wv.isHidden = true
        }

        guard let url = URL(string: "https://\(portalHost)") else {
            finish(.parseFailed)
            return
        }

        #if DEBUG
        print("[SilentFetcher] Starting fetch...")
        #endif

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        wv.load(request)

        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, !self.completed else { return }
            #if DEBUG
            print("[SilentFetcher] Timeout after 30s")
            #endif
            self.finish(self.pageLoaded ? .parseFailed : .sessionExpired)
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let host = url.host ?? ""

        #if DEBUG
        print("[SilentFetcher] didFinish: \(url.absoluteString)")
        #endif

        if host.contains(portalHost) && url.path.contains("login.php") {
            #if DEBUG
            print("[SilentFetcher] Hit login page — session expired")
            #endif
            finish(.sessionExpired)
            return
        }

        pageLoaded = true

        if host.contains(portalHost),
           url.path.contains("index.php"),
           url.query?.contains("expand=1") != true {
            let expandURL = URL(string: "https://\(portalHost)/index.php?cid=338&expand=1&")!
            var request = URLRequest(url: expandURL)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            webView.load(request)
            return
        }

        extractText(from: webView)
        for delay in [0.8, 1.8, 4.0, 8.0] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self, let webView, !self.completed else { return }
                self.extractText(from: webView)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self, !self.completed else { return }
            #if DEBUG
            print("[SilentFetcher] Page loaded but no data parsed after 12s")
            #endif
            self.finish(.parseFailed)
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        print("[SilentFetcher] didFail: \(error.localizedDescription)")
        #endif
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        #if DEBUG
        print("[SilentFetcher] provisional fail: \(error.localizedDescription)")
        #endif
        finish(.parseFailed)
    }

    private func extractText(from webView: WKWebView) {
        guard !completed else { return }
        webView.evaluateJavaScript("document.body ? document.body.innerText : ''") { [weak self] result, _ in
            guard let self, !self.completed else { return }
            let text = result as? String ?? ""
            if let info = BalanceScraper.parse(text) {
                #if DEBUG
                print("[SilentFetcher] Parsed: swipes=\(info.diningSwipes ?? -1) flex=\(info.flexBalance ?? -1)")
                #endif
                self.finish(.success(info))
            }
        }
    }

    private func finish(_ result: FetchResult) {
        guard !completed else { return }
        completed = true
        webView?.stopLoading()
        webView?.removeFromSuperview()
        webView = nil
        DispatchQueue.main.async { self.completion?(result) }
    }
}
