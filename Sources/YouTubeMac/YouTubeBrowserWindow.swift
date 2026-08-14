import AppKit
import WebKit

extension Notification.Name {
    static let youTubeBrowserDidAuthenticate = Notification.Name("youTubeBrowserDidAuthenticate")
    static let youTubeBrowserDidSignOut = Notification.Name("youTubeBrowserDidSignOut")
}

enum YouTubeAuthBridge {
    static let profileImageURLKey = "profileImageURL"
    static let profileCaptureScript = """
    (() => {
      const selectors = [
        'button#avatar-btn img',
        'ytd-topbar-menu-button-renderer img',
        'yt-img-shadow#avatar img',
        'img[src*="googleusercontent.com"]',
        'img[src*="ggpht.com"]'
      ];
      for (const selector of selectors) {
        const image = document.querySelector(selector);
        const src = image && (image.currentSrc || image.src);
        if (src && !src.includes('default_avatar') && !src.includes('yt_favicon')) return src;
      }
      return '';
    })();
    """
}

@MainActor
final class YouTubeBrowserWindow: NSObject, WKNavigationDelegate {
    static let shared = YouTubeBrowserWindow()

    private var window: NSWindow?
    private var webView: WKWebView?
    private var addressField: NSTextField?

    func open(_ url: URL, title: String = "YouTube") {
        let webView = existingOrCreateWebView()
        addressField?.stringValue = url.absoluteString
        webView.load(URLRequest(url: url))
        window?.title = title
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func checkAuthenticationState() {
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            let signedIn = Self.cookiesContainYouTubeSession(cookies)
            guard signedIn else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .youTubeBrowserDidAuthenticate,
                    object: nil
                )
            }
        }
    }

    func clearAuthenticationSession() {
        let store = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        store.fetchDataRecords(ofTypes: types) { records in
            let accountRecords = records.filter { record in
                let name = record.displayName.lowercased()
                return name.contains("youtube") || name.contains("google") || name.contains("googleusercontent")
            }
            guard !accountRecords.isEmpty else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .youTubeBrowserDidSignOut, object: nil)
                }
                return
            }
            store.removeData(ofTypes: types, for: accountRecords) {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .youTubeBrowserDidSignOut, object: nil)
                }
            }
        }
    }

    private func existingOrCreateWebView() -> WKWebView {
        if let webView {
            return webView
        }

        let configuration = WKWebViewConfiguration()
        configuration.youGlassDisableWebMaterialsOnAffectedSystems()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1280, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "YouTube"
        window.titlebarAppearsTransparent = true

        let chrome = BrowserChrome(webView: webView)
        window.contentView = chrome

        self.window = window
        self.webView = webView
        self.addressField = chrome.addressField
        return webView
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        addressField?.stringValue = webView.url?.absoluteString ?? ""
        // WebKit can invalidate the title object while a navigation callback is
        // being delivered. The browser window does not need page titles, so keep
        // a stable native title and avoid retaining that transient object.
        window?.title = "YouTube"
        checkAuthenticationState()
        captureProfileImage(from: webView)
    }

    private nonisolated static func cookiesContainYouTubeSession(_ cookies: [HTTPCookie]) -> Bool {
        let sessionCookieNames: Set<String> = [
            "APISID",
            "HSID",
            "LOGIN_INFO",
            "SAPISID",
            "SID",
            "SSID",
            "__Secure-1PAPISID",
            "__Secure-1PSID",
            "__Secure-1PSIDTS",
            "__Secure-3PAPISID",
            "__Secure-3PSID",
            "__Secure-3PSIDTS"
        ]

        return cookies.contains { cookie in
            let domain = cookie.domain.lowercased()
            let isGoogleSessionDomain = domain.contains("youtube.com") || domain.contains("google.com")
            return isGoogleSessionDomain && sessionCookieNames.contains(cookie.name)
        }
    }

    private func captureProfileImage(from webView: WKWebView) {
        guard webView.url?.host?.contains("youtube.com") == true else { return }

        Task { @MainActor in
            let result = try? await webView.youGlassEvaluateJavaScript(YouTubeAuthBridge.profileCaptureScript)
            guard let urlString = result, !urlString.isEmpty else { return }
            NotificationCenter.default.post(
                name: .youTubeBrowserDidAuthenticate,
                object: nil,
                userInfo: [YouTubeAuthBridge.profileImageURLKey: urlString]
            )
        }
    }
}

private final class BrowserChrome: NSView {
    let addressField = NSTextField()
    private let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        let back = button(symbol: "chevron.left", action: #selector(goBack))
        let forward = button(symbol: "chevron.right", action: #selector(goForward))
        let reload = button(symbol: "arrow.clockwise", action: #selector(reload))
        let external = button(symbol: "safari", action: #selector(openExternal))

        addressField.isEditable = true
        addressField.isBordered = false
        addressField.bezelStyle = .roundedBezel
        addressField.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1)
        addressField.textColor = .white
        addressField.font = .systemFont(ofSize: 13, weight: .medium)
        addressField.target = self
        addressField.action = #selector(loadAddress)

        let toolbar = NSStackView(views: [back, forward, reload, addressField, external])
        toolbar.orientation = .horizontal
        toolbar.spacing = 10
        toolbar.edgeInsets = NSEdgeInsets(top: 13, left: 14, bottom: 10, right: 14)
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(toolbar)
        addSubview(webView)

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: trailingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 58),

            addressField.widthAnchor.constraint(greaterThanOrEqualToConstant: 520),

            webView.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func button(symbol: String, action: Selector) -> NSButton {
        let button = NSButton(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(), target: self, action: action)
        button.isBordered = false
        button.contentTintColor = .white
        button.widthAnchor.constraint(equalToConstant: 30).isActive = true
        return button
    }

    @objc private func goBack() {
        if webView.canGoBack { webView.goBack() }
    }

    @objc private func goForward() {
        if webView.canGoForward { webView.goForward() }
    }

    @objc private func reload() {
        webView.reload()
    }

    @objc private func openExternal() {
        if let url = webView.url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func loadAddress() {
        let raw = addressField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }

        if let url = URL(string: raw), url.scheme != nil {
            webView.load(URLRequest(url: url))
            return
        }

        let query = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
        let url = URL(string: "https://www.youtube.com/results?search_query=\(query)")!
        webView.load(URLRequest(url: url))
    }
}
