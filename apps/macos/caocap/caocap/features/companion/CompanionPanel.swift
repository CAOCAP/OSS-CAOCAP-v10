import AppKit
import SwiftUI

/// Hosts the SwiftUI pet and owns native window dragging so the sprite follows the cursor.
final class CompanionHostingView<Content: View>: NSHostingView<Content> {
    var onDragBegan: (() -> Void)?
    var onDragEnded: ((_ didMove: Bool, _ clickCount: Int) -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onRightClick: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        wantsLayer = true
        layer?.masksToBounds = false
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else { return }
        let startMouse = NSEvent.mouseLocation
        let startOrigin = window.frame.origin
        var didMove = false
        var clickCount = event.clickCount

        var keepTracking = true
        while keepTracking {
            guard let next = window.nextEvent(
                matching: [.leftMouseDragged, .leftMouseUp],
                until: .distantFuture,
                inMode: .eventTracking,
                dequeue: true
            ) else { break }

            let now = NSEvent.mouseLocation
            let distance = hypot(now.x - startMouse.x, now.y - startMouse.y)
            if !didMove, distance >= CompanionLayout.clickSlop {
                didMove = true
                onDragBegan?()
            }
            if didMove {
                window.setFrameOrigin(
                    NSPoint(
                        x: startOrigin.x + (now.x - startMouse.x),
                        y: startOrigin.y + (now.y - startMouse.y)
                    )
                )
            }

            if next.type == .leftMouseUp {
                clickCount = next.clickCount
                keepTracking = false
                onDragEnded?(didMove, clickCount)
            }
        }
    }
}

/// Borderless, always-on-top panel that hosts the CoCaptain sprite above other apps.
final class CompanionPanel: NSPanel {
    init(
        rootView: some View,
        onDragBegan: @escaping () -> Void,
        onDragEnded: @escaping (Bool, Int) -> Void,
        onHoverChanged: @escaping (Bool) -> Void,
        onRightClick: @escaping () -> Void
    ) {
        let size = CompanionLayout.panelSize
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        isFloatingPanel = true
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let hosting = CompanionHostingView(rootView: rootView)
        hosting.onDragBegan = onDragBegan
        hosting.onDragEnded = onDragEnded
        hosting.onHoverChanged = onHoverChanged
        hosting.onRightClick = onRightClick
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.wantsLayer = true
        hosting.layer?.masksToBounds = false
        contentView = hosting
        contentView?.wantsLayer = true
        contentView?.layer?.masksToBounds = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
