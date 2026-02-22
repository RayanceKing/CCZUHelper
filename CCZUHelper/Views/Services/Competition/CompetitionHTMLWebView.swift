//
//  CompetitionHTMLWebView.swift
//  CCZUHelper
//
//  Created by rayanceking on 2026/2/19.
//

import SwiftUI
import WebKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct CompetitionHTMLWebView: ViewRepresentableCompat {
    let html: String
    @Binding var height: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    #if canImport(UIKit)
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = [.link, .phoneNumber]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        webView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.loadHTMLString(wrappedHTML(html), baseURL: nil)
    }
    #elseif canImport(AppKit)
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        webView.loadHTMLString(wrappedHTML(html), baseURL: nil)
    }
    #endif

    private func wrappedHTML(_ body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
          <style>
            :root { color-scheme: light dark; }
            body {
              margin: 0;
              padding: 0;
              font: -apple-system-body;
              font-size: 17px;
              line-height: 1.8;
              word-wrap: break-word;
              overflow-wrap: break-word;
              -webkit-text-size-adjust: 100%;
            }
            p { margin: 0 0 14px 0; text-indent: 2em; }
            h1,h2,h3,h4,h5,h6 { margin: 14px 0 10px 0; line-height: 1.4; }
            ul,ol { padding-left: 1.2em; margin: 10px 0; }
            li { margin: 6px 0; }
            img, video, iframe, table { max-width: 100% !important; height: auto !important; }
            pre, code {
              white-space: pre-wrap;
              word-break: break-word;
            }
            a {
              color: #0A84FF;
              text-decoration: underline;
              word-break: break-all;
            }
          </style>
          <script>
            function escapeHtml(text) {
              return text.replace(/[&<>"']/g, function(m) {
                return ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#039;'})[m];
              });
            }

            function linkifyText(text) {
              const pattern = /(https?:\\/\\/[^\\s<>"'，。；：、！？）】》\\)\\]]+)|(www\\.[^\\s<>"'，。；：、！？）】》\\)\\]]+)|([A-Z0-9._%+-]+@[A-Z0-9.-]+\\.[A-Z]{2,})|((?:\\+?86[-\\s]?)?1[3-9]\\d{9})|(?:\\b(?:qq|QQ)\\s*[:：]?\\s*([1-9][0-9]{4,11})\\b)/g;
              return text.replace(pattern, function(match, p1, p2, p3, p4, p5) {
                const value = match.trim();
                const splitTail = function(input) {
                  const m = input.match(/^(.*?)([\\)\\]\\}>,，。；：、！？）】》”’"'.,;:!?]+)$/);
                  if (m && m[1]) return { core: m[1], tail: m[2] };
                  return { core: input, tail: '' };
                };

                if (p3) {
                  const parts = splitTail(value);
                  return '<a href="mailto:' + parts.core + '">' + parts.core + '</a>' + parts.tail;
                }
                if (p4) {
                  const parts = splitTail(value);
                  const phone = parts.core.replace(/[^\\d+]/g, '');
                  return '<a href="tel:' + phone + '">' + parts.core + '</a>' + parts.tail;
                }
                if (p5) {
                  const qq = p5.trim();
                  const qqLink = 'mqqapi://card/show_pslcard?src_type=internal&version=1&uin=' + qq + '&card_type=person&source=qrcode';
                  return '<a href="' + qqLink + '">QQ:' + qq + '</a>';
                }

                const parts = splitTail(value);
                let url = parts.core;
                if (p2) url = 'https://' + parts.core;
                return '<a href="' + url + '">' + parts.core + '</a>' + parts.tail;
              });
            }

            function linkifyNode(node) {
              if (!node || !node.childNodes) return;
              const skipTags = ['A', 'SCRIPT', 'STYLE', 'NOSCRIPT', 'CODE', 'PRE'];
              const children = Array.from(node.childNodes);
              for (const child of children) {
                if (child.nodeType === Node.TEXT_NODE) {
                  const text = child.nodeValue || '';
                  if (!text.trim()) continue;
                  const rawEscaped = escapeHtml(text);
                  const linked = linkifyText(rawEscaped);
                  if (linked === rawEscaped) continue;
                  const span = document.createElement('span');
                  span.innerHTML = linked;
                  child.parentNode.replaceChild(span, child);
                } else if (child.nodeType === Node.ELEMENT_NODE && !skipTags.includes(child.tagName)) {
                  linkifyNode(child);
                }
              }
            }

            document.addEventListener('DOMContentLoaded', function() {
              linkifyNode(document.body);
            });
          </script>
        </head>
        <body>\(body)</body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: CompetitionHTMLWebView

        init(_ parent: CompetitionHTMLWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            let script = "Math.max(document.body.scrollHeight, document.documentElement.scrollHeight)"
            webView.evaluateJavaScript(script) { result, _ in
                let rawHeight: CGFloat
                if let value = result as? Double {
                    rawHeight = CGFloat(value)
                } else if let value = result as? NSNumber {
                    rawHeight = CGFloat(truncating: value)
                } else {
                    return
                }

                let newHeight = max(1, rawHeight)
                DispatchQueue.main.async {
                    if abs(self.parent.height - newHeight) > 1 {
                        self.parent.height = newHeight
                    }
                }
            }
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

            #if canImport(UIKit)
            if ["http", "https", "mailto", "tel", "mqqapi"].contains(url.scheme?.lowercased() ?? "") {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            #elseif canImport(AppKit)
            if ["http", "https", "mailto", "tel", "mqqapi"].contains(url.scheme?.lowercased() ?? "") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            #endif

            decisionHandler(.allow)
        }
    }
}

#if canImport(UIKit)
typealias ViewRepresentableCompat = UIViewRepresentable
#elseif canImport(AppKit)
typealias ViewRepresentableCompat = NSViewRepresentable
#endif
