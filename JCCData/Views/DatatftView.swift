import SwiftUI
import WebKit

/// 持有一个 WKWebView。用默认的持久化数据存储，所以在里面登录一次后会一直保持登录。
/// 放在一图流页面里长期持有，关掉再打开时停留在上次看的阵容。
@MainActor
final class WebViewStore: NSObject, ObservableObject, WKNavigationDelegate {
    let webView: WKWebView
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var progress: Double = 0
    @Published var loadError: String?

    private var observers: [NSKeyValueObservation] = []

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .default()
        cfg.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: cfg)
        super.init()
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = UIColor(red: 0.13, green: 0.15, blue: 0.21, alpha: 1)
        webView.isOpaque = false

        observers = [
            webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.isLoading = wv.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                DispatchQueue.main.async { self?.progress = wv.estimatedProgress }
            }
        ]
    }

    func loadIfNeeded(_ url: URL) {
        if webView.url == nil { load(url) }
    }

    func load(_ url: URL) {
        loadError = nil
        webView.load(URLRequest(url: url))
    }

    func reload() {
        loadError = nil
        if webView.url == nil { return }
        webView.reload()
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadError = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }
        loadError = error.localizedDescription
    }
}

struct WebContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// datatft 的一图流网页，全屏打开
struct DatatftView: View {
    @ObservedObject var store: WebViewStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    static let homeURL = URL(string: "https://jcc.datatft.com/comp/allinone")!

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.13, green: 0.15, blue: 0.21).ignoresSafeArea()
                WebContainer(webView: store.webView)
                    .ignoresSafeArea(edges: .bottom)

                if let err = store.loadError {
                    VStack(spacing: 10) {
                        Image(systemName: "wifi.exclamationmark").font(.largeTitle)
                        Text("页面打不开").font(.headline)
                        Text(err).font(.caption).multilineTextAlignment(.center)
                        Button("重试") { store.load(Self.homeURL) }
                            .buttonStyle(.borderedProminent)
                    }
                    .foregroundColor(.white)
                    .padding(32)
                }
            }
            .overlay(alignment: .top) {
                if store.isLoading {
                    ProgressView(value: store.progress)
                        .progressViewStyle(.linear)
                        .tint(Color(hex: 0xE8A01F))
                }
            }
            .navigationTitle("datatft 一图流")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        store.webView.goBack()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .disabled(!store.canGoBack)

                    Button {
                        store.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }

                    Menu {
                        Button {
                            store.load(Self.homeURL)
                        } label: {
                            Label("回到一图流首页", systemImage: "house")
                        }
                        Button {
                            openURL(store.webView.url ?? Self.homeURL)
                        } label: {
                            Label("在 Safari 中打开", systemImage: "safari")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear { store.loadIfNeeded(Self.homeURL) }
    }
}
