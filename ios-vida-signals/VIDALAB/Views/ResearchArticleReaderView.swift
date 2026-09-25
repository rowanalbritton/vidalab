import SwiftUI
import WebKit

struct ResearchArticleReaderView: View {
    @Environment(VidaStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let article: ResearchArticle

    var body: some View {
        NavigationStack {
            if let contentHTML = article.contentHTML, !contentHTML.isEmpty {
                ResearchArticleWebView(
                    html: ResearchArticleHTMLDocument.make(
                        article: article,
                        bodyHTML: contentHTML,
                        textScale: dynamicTypeSize.researchTextScale
                    ),
                    baseURL: article.canonicalURL,
                    onOpenExternalURL: SafariPresenter.present
                )
                .ignoresSafeArea(edges: .bottom)
            } else {
                ResearchArticleUnavailableView(
                    canonicalURL: article.canonicalURL,
                    onOpen: SafariPresenter.present
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    store.toggleSave(article.savedID)
                } label: {
                    Image(
                        systemName: store.savedArticleIDs.contains(article.savedID)
                            ? "bookmark.fill"
                            : "bookmark"
                    )
                    .foregroundStyle(Vida.moss)
                }
                .accessibilityLabel(
                    store.savedArticleIDs.contains(article.savedID)
                        ? "Remove bookmark"
                        : "Save article"
                )
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                ShareLink(
                    item: article.canonicalURL,
                    subject: Text(article.title),
                    message: Text(article.summary)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Vida.moss)
                }
                .accessibilityLabel("Share article")

                Button("Done") {
                    dismiss()
                }
                .font(Vida.sans(15, weight: .medium))
                .foregroundStyle(Vida.moss)
            }
        }
        .toolbarBackground(Vida.cream, for: .navigationBar)
    }
}

private struct ResearchArticleUnavailableView: View {
    let canonicalURL: URL
    let onOpen: (URL) -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Vida.moss)
            Text("This article isn’t cached yet")
                .font(Vida.serif(22))
                .foregroundStyle(Vida.forest)
            Text("Connect once to save the complete VIDA LAB article for offline reading.")
                .font(Vida.sans(14))
                .foregroundStyle(Vida.inkSoft)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            Button("Open published article") {
                onOpen(canonicalURL)
            }
            .font(Vida.sans(14, weight: .semibold))
            .foregroundStyle(Vida.onForest)
            .padding(.horizontal, 18)
            .frame(minHeight: 44)
            .background(Vida.forest, in: Capsule())
            .buttonStyle(PressableStyle())
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .vidaBackground()
    }
}

private struct ResearchArticleWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL
    let onOpenExternalURL: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onOpenExternalURL: onOpenExternalURL)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.allowsBackForwardNavigationGestures = false
        webView.loadHTMLString(html, baseURL: baseURL.deletingLastPathComponent())
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedHTML != html else { return }
        context.coordinator.loadedHTML = html
        context.coordinator.onOpenExternalURL = onOpenExternalURL
        webView.loadHTMLString(html, baseURL: baseURL.deletingLastPathComponent())
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var loadedHTML: String?
        var onOpenExternalURL: (URL) -> Void

        init(onOpenExternalURL: @escaping (URL) -> Void) {
            self.onOpenExternalURL = onOpenExternalURL
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
            guard url.scheme == "https" else { return }
            onOpenExternalURL(url)
        }
    }
}

nonisolated private enum ResearchArticleHTMLDocument {
    static func make(article: ResearchArticle, bodyHTML: String, textScale: Int) -> String {
        let author = article.author.map {
            "<span>By \($0.htmlEscaped)</span>"
        } ?? ""
        let status = article.evidenceStatus.map {
            "<div class=\"evidence\">\($0.title.htmlEscaped)</div>"
        } ?? ""

        return """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta http-equiv="Content-Security-Policy"
                content="default-src 'none'; style-src 'unsafe-inline'; img-src 'none'; media-src 'none'; frame-src 'none'; font-src 'none';">
          <style>
            :root { color-scheme: light dark; }
            * { box-sizing: border-box; }
            html { -webkit-text-size-adjust: 100%; }
            body {
              margin: 0;
              padding: 24px 22px 48px;
              background: #F8F5EE;
              color: #24352F;
              font-family: -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif;
              font-size: calc(17px * \(textScale) / 100);
              line-height: 1.65;
              overflow-wrap: anywhere;
            }
            article { max-width: 720px; margin: 0 auto; }
            .eyebrow {
              margin: 0 0 12px;
              color: #567663;
              font-size: 12px;
              font-weight: 700;
              letter-spacing: 0.14em;
              text-transform: uppercase;
            }
            h1 {
              margin: 0 0 12px;
              color: #1F3A30;
              font-family: Georgia, "Times New Roman", serif;
              font-size: 2.05rem;
              line-height: 1.12;
              font-weight: 500;
            }
            .dek {
              margin: 0 0 14px;
              color: #53615C;
              font-family: Georgia, "Times New Roman", serif;
              font-size: 1.12rem;
              font-style: italic;
              line-height: 1.5;
            }
            .meta {
              display: flex;
              flex-wrap: wrap;
              gap: 6px 12px;
              margin-bottom: 14px;
              color: #6D7773;
              font-size: 0.78rem;
            }
            .evidence {
              display: inline-block;
              margin: 0 0 18px;
              padding: 6px 10px;
              border: 1px solid #8AA393;
              border-radius: 999px;
              color: #355746;
              font-size: 0.72rem;
              font-weight: 700;
              letter-spacing: 0.06em;
              text-transform: uppercase;
            }
            hr {
              height: 1px;
              border: 0;
              background: #D9D5CA;
              margin: 28px 0;
            }
            h2, h3 {
              color: #1F3A30;
              font-family: Georgia, "Times New Roman", serif;
              font-weight: 500;
              line-height: 1.25;
            }
            h2 { margin: 2rem 0 0.65rem; font-size: 1.45rem; }
            h3 { margin: 1.6rem 0 0.55rem; font-size: 1.2rem; }
            p { margin: 0 0 1.05rem; }
            ul, ol { padding-left: 1.35rem; margin: 0 0 1.1rem; }
            li { margin-bottom: 0.45rem; }
            blockquote {
              margin: 1.4rem 0;
              padding: 0.2rem 0 0.2rem 1rem;
              border-left: 3px solid #8AA393;
              color: #53615C;
              font-family: Georgia, "Times New Roman", serif;
            }
            a { color: #2F6B50; text-decoration-thickness: 1px; }
            .medical {
              margin-top: 32px;
              padding: 16px;
              border-radius: 16px;
              background: rgba(126, 157, 137, 0.16);
              color: #53615C;
              font-size: 0.82rem;
              line-height: 1.55;
            }
            .medical strong { display: block; color: #1F3A30; margin-bottom: 5px; }
            img, picture, video, audio, iframe, form,
            .subscription-widget, .subscription-widget-wrap-editor {
              display: none !important;
            }
            @media (prefers-color-scheme: dark) {
              body { background: #18231F; color: #E8E5DE; }
              h1, h2, h3, .medical strong { color: #F1EEE7; }
              .dek, .meta, blockquote, .medical { color: #C4CBC6; }
              .evidence { color: #CFE2D6; border-color: #718B79; }
              hr { background: #3A4741; }
              a { color: #9CCBAE; }
              .medical { background: rgba(126, 157, 137, 0.13); }
            }
          </style>
        </head>
        <body>
          <article>
            <div class="eyebrow">VIDA LAB Research Library</div>
            <h1>\(article.title.htmlEscaped)</h1>
            <p class="dek">\(article.summary.htmlEscaped)</p>
            <div class="meta">
              \(author)
              <span>Published \(article.publishedAt.formatted(date: .long, time: .omitted).htmlEscaped)</span>
            </div>
            \(status)
            <hr>
            \(bodyHTML)
            <aside class="medical">
              <strong>Medical Information</strong>
              VIDA LAB provides educational information about health and biomedical research and is not a substitute for professional medical advice, diagnosis, or treatment. Always discuss medical decisions with a qualified healthcare professional.
            </aside>
          </article>
        </body>
        </html>
        """
    }
}

private extension DynamicTypeSize {
    var researchTextScale: Int {
        switch self {
        case .xSmall: 82
        case .small: 88
        case .medium: 94
        case .large: 100
        case .xLarge: 112
        case .xxLarge: 124
        case .xxxLarge: 136
        case .accessibility1: 150
        case .accessibility2: 165
        case .accessibility3: 180
        case .accessibility4: 195
        case .accessibility5: 210
        @unknown default: 100
        }
    }
}

nonisolated private extension String {
    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
