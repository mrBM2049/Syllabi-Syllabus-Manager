import SwiftUI
import AppKit

/// Resigns native text editing when a mouse click lands outside a text input.
/// This keeps inline editing and search fields usable while making clicks on
/// buttons, menus, cards, and navigation reliably remove the insertion cursor.
public struct FocusDismissalView: NSViewRepresentable {
    public init() {}

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    public func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installMonitor()
        return view
    }

    public func updateNSView(_ nsView: NSView, context: Context) {}

    public static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.removeMonitor()
    }

    public final class Coordinator {
        private var monitor: Any?

        func installMonitor() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { event in
                guard let window = event.window,
                      window.firstResponder is NSTextField || window.firstResponder is NSTextView else {
                    return event
                }

                let hitView = window.contentView?.hitTest(event.locationInWindow)
                if !Self.isTextInput(hitView) {
                    window.makeFirstResponder(nil)
                }
                return event
            }
        }

        func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }

        private static func isTextInput(_ view: NSView?) -> Bool {
            var current = view
            while let candidate = current {
                if candidate is NSTextField || candidate is NSTextView {
                    return true
                }
                current = candidate.superview
            }
            return false
        }

        deinit {
            removeMonitor()
        }
    }
}
