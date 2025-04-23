// File: Views/CanvasView.swift
import SwiftUI
import PencilKit

/**
 A SwiftUI wrapper for the PKCanvasView, allowing it to be used in the view hierarchy.
 The actual configuration (delegate, tool, drawingPolicy) should be handled by the
 `StrokeInputController` via its `setup` method, which receives the underlying
 `PKCanvasView` instance managed here via `@Binding`.
 */
struct CanvasView: UIViewRepresentable {
    /// Binding to the PKCanvasView instance created and managed by the parent view (e.g., MainView).
    /// This allows the controller (`StrokeInputController`) to interact with the *same* UIView instance.
    @Binding var pkCanvasView: PKCanvasView

    // Optional: Add bindings for tool, drawing policy etc. if they need to be controlled
    // directly from SwiftUI state, although the controller pattern is generally preferred.
    // @Binding var currentTool: PKTool
    // @Binding var drawingPolicy: PKCanvasViewDrawingPolicy

    func makeUIView(context: Context) -> PKCanvasView {
        // The pkCanvasView instance is passed in via the binding.
        // Basic configuration that is unlikely to change frequently can go here.
        // The StrokeInputController's setup method will handle critical configurations like delegate.
        pkCanvasView.isOpaque = false
        pkCanvasView.backgroundColor = .clear // Ensure transparent background
        // Drawing policy and tool should ideally be set by the controller during setup.
        // Setting defaults here is okay but might be overridden.
        // pkCanvasView.drawingPolicy = .anyInput
        // pkCanvasView.tool = PKInkingTool(.pen, color: .label, width: 10)

        print("CanvasView makeUIView: Returning bound PKCanvasView instance.")
        return pkCanvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // This method is called when SwiftUI state bound to this view changes.
        // Generally, updates related to drawing interaction are handled via the delegate
        // (`StrokeInputController`).
        // If you added bindings for `currentTool` or `drawingPolicy`, update them here:
        // uiView.tool = currentTool
        // uiView.drawingPolicy = drawingPolicy

        // It's crucial that `uiView` IS the instance referenced by `pkCanvasView`.
        // SwiftUI's binding mechanism should ensure this. We don't reassign uiView.
        print("CanvasView updateUIView (called when bound state changes)")
    }

     // Coordinator can be used to handle delegate callbacks directly within the
     // UIViewRepresentable if not using a separate controller class, but here
     // the delegate is handled by StrokeInputController.
     // func makeCoordinator() -> Coordinator {
     //     Coordinator(self)
     // }
     //
     // class Coordinator: NSObject, PKCanvasViewDelegate {
     //     var parent: CanvasView
     //     init(_ parent: CanvasView) { self.parent = parent }
     //     // Implement delegate methods here...
     // }
}
