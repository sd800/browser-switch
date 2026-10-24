import AppKit
import SwiftUI
import XCTest
import BrowserSwitchCore
@testable import BrowserSwitch

final class PickerWindowTests: XCTestCase {
    @MainActor
    private func makeWindow(singleBrowser: Bool = false) throws -> (BrowserPickerWindow, ChooserState, AppModel) {
        _ = NSApplication.shared
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Window layout tests require a graphical macOS session.") }
        let suite = "org.songming.BrowserSwitch.WindowTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        if singleBrowser, let first = model.orderedBrowsers.first {
            model.settings.browsers = model.orderedBrowsers.map { BrowserPreference(bundleID: $0.id, isVisible: $0.id == first.id) }
        }
        let state = ChooserState()
        state.urls = [URL(string: "https://layout.invalid")!]
        let window = BrowserPickerWindow(rootView: ChooserView(model: model, state: state, choose: { _ in }, cancel: {}, openSettings: {}))
        return (window, state, model)
    }

    @MainActor
    private func settleLayout() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.12))
    }

    @MainActor
    private func assertNativePosition(_ window: NSWindow, file: StaticString = #filePath, line: UInt = #line) throws {
        let reference = NSWindow(contentRect: .zero, styleMask: window.styleMask, backing: .buffered, defer: true)
        reference.setFrame(window.frame, display: false)
        reference.center()
        XCTAssertEqual(window.frame.minX, reference.frame.minX, accuracy: 1, file: file, line: line)
        XCTAssertEqual(window.frame.minY, reference.frame.minY, accuracy: 1, file: file, line: line)
        let screen = try XCTUnwrap(window.screen, file: file, line: line)
        XCTAssertTrue(screen.visibleFrame.insetBy(dx: -1, dy: -1).contains(window.frame), file: file, line: line)
    }

    @MainActor
    func testFirstPresentationStaysAtNativePositionAfterLayout() throws {
        let (window, _, model) = try makeWindow()
        defer { window.close(); _ = model }
        window.prepareForPresentation()
        let initial = window.frame
        window.makeKeyAndOrderFront(nil)
        settleLayout()
        XCTAssertEqual(window.frame, initial)
        try assertNativePosition(window)
    }

    @MainActor
    func testSingleBrowserUsesNativePosition() throws {
        let (window, _, model) = try makeWindow(singleBrowser: true)
        defer { window.close(); _ = model }
        window.prepareForPresentation()
        window.makeKeyAndOrderFront(nil)
        settleLayout()
        try assertNativePosition(window)
    }

    @MainActor
    func testQueuedLongLinkKeepsTopEdgeAndReopeningRecenters() throws {
        let (window, state, model) = try makeWindow()
        defer { window.close(); _ = model }
        window.prepareForPresentation()
        window.makeKeyAndOrderFront(nil)
        settleLayout()
        let initial = window.frame
        state.urls = [URL(string: "https://a-long-subdomain-for-window-layout.example.invalid/" + String(repeating: "path/", count: 35))!]
        window.prepareForPresentation()
        settleLayout()
        XCTAssertEqual(window.frame.minX, initial.minX, accuracy: 1)
        XCTAssertEqual(window.frame.maxY, initial.maxY, accuracy: 1)
        XCTAssertGreaterThan(window.frame.height, initial.height)
        window.close()
        state.urls = [URL(string: "https://layout.invalid")!]
        window.prepareForPresentation()
        window.makeKeyAndOrderFront(nil)
        settleLayout()
        try assertNativePosition(window)
        XCTAssertEqual(window.frame.size, initial.size)
    }
}
