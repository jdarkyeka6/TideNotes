import SwiftUI
import UIKit

struct RichTextCommand: Identifiable, Equatable {
    enum Kind: Equatable {
        case bold
        case italic
        case heading
        case body
        case checklist
        case bullet
        case numbered
        case quote
    }

    let id = UUID()
    let kind: Kind
}

struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var rtfData: Data?
    @Binding var command: RichTextCommand?
    @Binding var isFocused: Bool

    let onChange: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = false
        textView.isScrollEnabled = true

        if let rtfData,
           let attributed = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
           ) {
            textView.attributedText = attributed
        } else {
            textView.attributedText = NSAttributedString(
                string: text,
                attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
            )
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if !uiView.isFirstResponder && uiView.text != text {
            if let rtfData,
               let attributed = try? NSAttributedString(
                data: rtfData,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
               ) {
                uiView.attributedText = attributed
            } else {
                uiView.attributedText = NSAttributedString(
                    string: text,
                    attributes: [.font: UIFont.preferredFont(forTextStyle: .body)]
                )
            }
        }

        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            DispatchQueue.main.async {
                uiView.resignFirstResponder()
            }
        }

        if let command, command.id != context.coordinator.lastCommandID {
            context.coordinator.lastCommandID = command.id
            context.coordinator.apply(command.kind, to: uiView)
            DispatchQueue.main.async {
                self.command = nil
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        var lastCommandID: UUID?

        init(parent: RichTextEditor) {
            self.parent = parent
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
            sync(textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            sync(textView)
        }

        func apply(_ kind: RichTextCommand.Kind, to textView: UITextView) {
            switch kind {
            case .bold:
                toggleTrait(.traitBold, in: textView)
            case .italic:
                toggleTrait(.traitItalic, in: textView)
            case .heading:
                applyFont(UIFont.systemFont(ofSize: 28, weight: .bold), in: textView)
            case .body:
                applyFont(UIFont.preferredFont(forTextStyle: .body), in: textView)
            case .checklist:
                toggleLinePrefix("☐ ", in: textView)
            case .bullet:
                toggleLinePrefix("• ", in: textView)
            case .numbered:
                toggleLinePrefix("1. ", in: textView)
            case .quote:
                toggleLinePrefix("› ", in: textView)
            }

            sync(textView)
            textView.becomeFirstResponder()
        }

        private func toggleTrait(_ trait: UIFontDescriptor.SymbolicTraits, in textView: UITextView) {
            let range = textView.selectedRange
            let currentFont = font(at: range.location, in: textView)
            var traits = currentFont.fontDescriptor.symbolicTraits

            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }

            guard let descriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) else { return }
            let newFont = UIFont(descriptor: descriptor, size: currentFont.pointSize)

            if range.length == 0 {
                var attributes = textView.typingAttributes
                attributes[.font] = newFont
                textView.typingAttributes = attributes
            } else {
                textView.textStorage.addAttribute(.font, value: newFont, range: range)
            }
        }

        private func applyFont(_ font: UIFont, in textView: UITextView) {
            let range = textView.selectedRange
            if range.length == 0 {
                var attributes = textView.typingAttributes
                attributes[.font] = font
                textView.typingAttributes = attributes
            } else {
                textView.textStorage.addAttribute(.font, value: font, range: range)
            }
        }

        private func font(at location: Int, in textView: UITextView) -> UIFont {
            let length = textView.textStorage.length
            guard length > 0 else {
                return (textView.typingAttributes[.font] as? UIFont) ?? .preferredFont(forTextStyle: .body)
            }

            let safeLocation = min(max(location, 0), length - 1)
            return (textView.textStorage.attribute(.font, at: safeLocation, effectiveRange: nil) as? UIFont)
                ?? .preferredFont(forTextStyle: .body)
        }

        private func toggleLinePrefix(_ prefix: String, in textView: UITextView) {
            let string = textView.textStorage.string as NSString
            let location = min(textView.selectedRange.location, string.length)
            let lineRange: NSRange

            if string.length == 0 {
                lineRange = NSRange(location: 0, length: 0)
            } else if location == string.length {
                lineRange = string.lineRange(for: NSRange(location: max(0, location - 1), length: 0))
            } else {
                lineRange = string.lineRange(for: NSRange(location: location, length: 0))
            }

            let lineText = lineRange.length > 0 ? string.substring(with: lineRange) : ""
            let knownPrefixes = ["☐ ", "• ", "1. ", "› "]

            if let existing = knownPrefixes.first(where: { lineText.hasPrefix($0) }) {
                let length = (existing as NSString).length
                textView.textStorage.replaceCharacters(
                    in: NSRange(location: lineRange.location, length: length),
                    with: ""
                )
                textView.selectedRange = NSRange(
                    location: max(lineRange.location, textView.selectedRange.location - length),
                    length: textView.selectedRange.length
                )

                if existing == prefix { return }
            }

            textView.textStorage.replaceCharacters(
                in: NSRange(location: lineRange.location, length: 0),
                with: prefix
            )
            let length = (prefix as NSString).length
            textView.selectedRange = NSRange(
                location: textView.selectedRange.location + length,
                length: textView.selectedRange.length
            )
        }

        private func sync(_ textView: UITextView) {
            parent.text = textView.text

            let fullRange = NSRange(location: 0, length: textView.attributedText.length)
            if let data = try? textView.attributedText.data(
                from: fullRange,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) {
                parent.rtfData = data
            }

            parent.onChange()
        }
    }
}
