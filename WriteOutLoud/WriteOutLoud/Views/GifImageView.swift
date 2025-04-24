// File: Views/GifImageView.swift
import SwiftUI
import WebKit

struct GifImageView: UIViewRepresentable {
    private let data: Data // Changed to accept Data

    init(data: Data) { // Initializer takes Data
        self.data = data
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false // Make background transparent
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false // Disable scrolling
        // Load GIF data directly into the web view
        webView.load(
            data,
            mimeType: "image/gif", // Specify the MIME type
            characterEncodingName: "UTF-8", // Standard encoding
            baseURL: Bundle.main.resourceURL! // Base URL for potential relative paths (usually not needed for data)
        )
        print("GifImageView: Loading GIF data into WKWebView")
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Check if the data has changed - if so, reload
        // Note: Comparing large Data objects can be inefficient.
        // Consider adding an ID or checksum if frequent updates are needed.
        // For simplicity, we assume data only changes when the character changes.
        // Let's reload only if the data object reference changes (which happens
        // when a new character's data is passed).
        // A more robust way might involve passing a unique ID bound to the data.
        
        // Simple reload logic (might reload unnecessarily if data content is same but object changes)
         uiView.load(
             data,
             mimeType: "image/gif",
             characterEncodingName: "UTF-8",
             baseURL: Bundle.main.resourceURL!
         )
        print("GifImageView: updateUIView called, reloading data.")

    }
}
