//
//  PostureProjectApp.swift
//  PostureProject
//
//  Created by Noah M on 2/27/25.
//

import SwiftUI
import AppKit

@main
struct PostureProjectApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchWindowController?
    private var statusItem: NSStatusItem?
    private let frameHandler = FrameHandler()
    private let bodyLandmarks = BodyLandmarks()

    func applicationDidFinishLaunching(_ notification: Notification) {
        frameHandler.onFrameCaptured = { [weak self] cgImage in
            self?.bodyLandmarks.processFrame(cgImage)
        }
        installStatusItem()
        let controller = NotchWindowController(
            frameHandler: frameHandler,
            bodyLandmarks: bodyLandmarks
        )
        controller.show()
        notchController = controller
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "figure.stand",
                accessibilityDescription: "PostureProject"
            )
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Quit PostureProject",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        item.menu = menu
        statusItem = item
    }
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchWindowController {
    private let panel: NotchPanel
    private let frameHandler: FrameHandler
    private let bodyLandmarks: BodyLandmarks

    // Panel is always sized to the expanded dimensions; the notch shape inside
    // animates its size within this canvas.
    private let expandedWidth: CGFloat = 420
    private let expandedHeight: CGFloat = 280

    init(frameHandler: FrameHandler, bodyLandmarks: BodyLandmarks) {
        self.frameHandler = frameHandler
        self.bodyLandmarks = bodyLandmarks

        let screen = NSScreen.main ?? NSScreen.screens.first!
        // Fall back to sensible defaults on Macs without a notch.
        let notchWidth = screen.effectiveNotchWidth > 0 ? screen.effectiveNotchWidth : 200
        let notchHeight = screen.safeAreaInsets.top > 0 ? screen.safeAreaInsets.top : 32

        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        // Above the system menu bar so the shape visually merges with the
        // physical notch bezel. .statusBar alone is drawn beneath the menu bar.
        panel.level = NSWindow.Level(rawValue: Int(CGShieldingWindowLevel()))
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        let rootView = NotchView(
            frameHandler: frameHandler,
            bodyLandmarks: bodyLandmarks,
            notchWidth: notchWidth,
            notchHeight: notchHeight,
            expandedWidth: expandedWidth,
            expandedHeight: expandedHeight
        )
        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = NSRect(x: 0, y: 0, width: expandedWidth, height: expandedHeight)
        panel.contentView = hosting

        self.panel = panel
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.positionPanel() }
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let x = screen.frame.origin.x + (screen.frame.width - expandedWidth) / 2
        let y = screen.frame.origin.y + screen.frame.height - expandedHeight
        panel.setFrame(
            NSRect(x: x, y: y, width: expandedWidth, height: expandedHeight),
            display: true
        )
    }
}

private extension NSScreen {
    var effectiveNotchWidth: CGFloat {
        guard safeAreaInsets.top > 0 else { return 0 }
        let left = auxiliaryTopLeftArea?.size.width ?? 0
        let right = auxiliaryTopRightArea?.size.width ?? 0
        return max(frame.width - left - right, 0)
    }
}
