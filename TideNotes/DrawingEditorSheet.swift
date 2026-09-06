import SwiftUI
import PencilKit

struct DrawingEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var data: Data?
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            PencilCanvas(data: $data)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Drawing")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") {
                            onSave()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Clear", role: .destructive) {
                            data = nil
                        }
                    }
                }
        }
    }
}

private struct PencilCanvas: UIViewRepresentable {
    @Binding var data: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .systemBackground
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator

        if let data, let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }

        let picker = PKToolPicker()
        picker.addObserver(canvas)
        picker.setVisible(true, forFirstResponder: canvas)
        context.coordinator.toolPicker = picker

        DispatchQueue.main.async {
            canvas.becomeFirstResponder()
        }

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        guard let data else {
            if !uiView.drawing.strokes.isEmpty {
                uiView.drawing = PKDrawing()
            }
            return
        }

        if let drawing = try? PKDrawing(data: data),
           drawing.dataRepresentation() != uiView.drawing.dataRepresentation() {
            uiView.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvas
        var toolPicker: PKToolPicker?

        init(parent: PencilCanvas) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.data = canvasView.drawing.dataRepresentation()
        }
    }
}

enum DrawingPreview {
    static func image(from data: Data) -> UIImage? {
        guard let drawing = try? PKDrawing(data: data) else { return nil }
        let bounds = drawing.bounds.isEmpty ? CGRect(x: 0, y: 0, width: 600, height: 300) : drawing.bounds.insetBy(dx: -20, dy: -20)
        return drawing.image(from: bounds, scale: UIScreen.main.scale)
    }
}
