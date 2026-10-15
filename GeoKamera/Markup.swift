import SwiftUI
import UIKit
import PencilKit

/// Fotoğraf üzerindeki hazır şekiller. Noktalar görsele göre 0...1 arası oransal tutulur.
struct Markup: Identifiable {
    enum Kind { case arrow, circle, rect, text }
    let id = UUID()
    var kind: Kind
    var start: CGPoint
    var end: CGPoint
    var color: UIColor
    var text: String = ""
}

enum MarkupRenderer {
    static func draw(_ items: [Markup], in ctx: CGContext, size: CGSize) {
        let lw = max(2, min(size.width, size.height) * 0.009)

        for m in items {
            let s = CGPoint(x: m.start.x * size.width, y: m.start.y * size.height)
            let e = CGPoint(x: m.end.x * size.width, y: m.end.y * size.height)

            ctx.saveGState()
            ctx.setStrokeColor(m.color.cgColor)
            ctx.setFillColor(m.color.cgColor)
            ctx.setLineWidth(lw)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.setShadow(offset: CGSize(width: 0, height: lw * 0.3),
                          blur: lw * 1.2,
                          color: UIColor(white: 0, alpha: 0.55).cgColor)

            switch m.kind {
            case .arrow:
                let dx = e.x - s.x
                let dy = e.y - s.y
                let len = max(hypot(dx, dy), 0.001)
                let head = min(len * 0.5, lw * 5.5)
                let ux = dx / len
                let uy = dy / len
                let base = CGPoint(x: e.x - ux * head, y: e.y - uy * head)
                ctx.move(to: s)
                ctx.addLine(to: base)
                ctx.strokePath()
                let px = -uy
                let py = ux
                ctx.move(to: e)
                ctx.addLine(to: CGPoint(x: base.x + px * head * 0.65, y: base.y + py * head * 0.65))
                ctx.addLine(to: CGPoint(x: base.x - px * head * 0.65, y: base.y - py * head * 0.65))
                ctx.closePath()
                ctx.fillPath()

            case .circle:
                ctx.strokeEllipse(in: rect(s, e))

            case .rect:
                ctx.stroke(rect(s, e))

            case .text:
                let fontSize = min(size.width, size.height) * 0.06
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                    .foregroundColor: m.color,
                    .strokeColor: UIColor.black,
                    .strokeWidth: -3.0
                ]
                let str = m.text as NSString
                let ts = str.size(withAttributes: attrs)
                UIGraphicsPushContext(ctx)
                str.draw(at: CGPoint(x: s.x - ts.width / 2, y: s.y - ts.height / 2), withAttributes: attrs)
                UIGraphicsPopContext()
            }
            ctx.restoreGState()
        }
    }

    private static func rect(_ a: CGPoint, _ b: CGPoint) -> CGRect {
        CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }
}

/// Şekilleri ekranda gösteren katman
final class MarkupUIView: UIView {
    var markups: [Markup] = [] { didSet { setNeedsDisplay() } }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) kullanılmıyor") }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        MarkupRenderer.draw(markups, in: ctx, size: bounds.size)
    }
}

struct MarkupLayer: UIViewRepresentable {
    var markups: [Markup]
    func makeUIView(context: Context) -> MarkupUIView { MarkupUIView(frame: .zero) }
    func updateUIView(_ uiView: MarkupUIView, context: Context) { uiView.markups = markups }
}

/// Düzenleyici durumu: kalem çizimi + şekiller + geri alma geçmişi
final class EditorModel: NSObject, ObservableObject, PKCanvasViewDelegate {
    let canvas = PKCanvasView()
    let toolPicker = PKToolPicker()

    @Published var markups: [Markup] = []
    @Published var draft: Markup?

    private enum Step { case pen, shape }
    private var history: [Step] = []
    private var ignoreChanges = false

    override init() {
        super.init()
        canvas.delegate = self
    }

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        if ignoreChanges { return }
        history.append(.pen)
    }

    func add(_ m: Markup) {
        markups.append(m)
        history.append(.shape)
    }

    func undo() {
        guard let last = history.popLast() else { return }
        switch last {
        case .shape:
            if !markups.isEmpty { markups.removeLast() }
        case .pen:
            var d = canvas.drawing
            if !d.strokes.isEmpty {
                d.strokes.removeLast()
                setDrawingSilently(d)
            }
        }
    }

    func clear() {
        setDrawingSilently(PKDrawing())
        markups.removeAll()
        history.removeAll()
    }

    var isEmpty: Bool { markups.isEmpty && canvas.drawing.strokes.isEmpty }

    private func setDrawingSilently(_ d: PKDrawing) {
        ignoreChanges = true
        canvas.drawing = d
        DispatchQueue.main.async { self.ignoreChanges = false }
    }
}
