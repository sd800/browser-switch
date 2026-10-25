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

final class RoutingSecurityTests: XCTestCase {
    @MainActor
    private func makeModel(storedSettings: Any? = nil) throws -> (AppModel, UserDefaults) {
        _ = NSApplication.shared
        let suite = "org.songming.BrowserSwitch.SecurityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        if let storedSettings { defaults.set(storedSettings, forKey: "BrowserSwitch.settings.v1") }
        return (AppModel(defaults: defaults), defaults)
    }

    @MainActor
    func testRequestFloodIsBoundedAcrossEventsAndCompletions() throws {
        let (model, defaults) = try makeModel()
        guard let browser = model.defaultBrowser else { throw XCTSkip("Requires an installed browser in Launch Services.") }
        model.settings.defaultBrowserID = browser.id
        let saved = defaults.data(forKey: "BrowserSwitch.settings.v1")
        var completions: [(Bool) -> Void] = []
        let delegate = AppDelegate(model: model, openLink: { _, _, completion in completions.append(completion) })
        let urls = (0..<64).map { URL(string: "https://security.invalid/\($0)?token=TEST_ONLY")! }
        for _ in 0..<5 { delegate.application(NSApplication.shared, open: urls) }
        XCTAssertEqual(completions.count, 64)
        XCTAssertEqual(delegate.inFlightLinkCount, 64)
        XCTAssertEqual(delegate.pendingLinkCount, 0)

        completions.removeFirst()(true)
        delegate.application(NSApplication.shared, open: urls)
        XCTAssertEqual(delegate.inFlightLinkCount, 64)
        XCTAssertEqual(completions.count, 64)
        for completion in completions { completion(false) }
        completions.removeAll()
        XCTAssertEqual(delegate.inFlightLinkCount, 0)
        XCTAssertEqual(delegate.pendingLinkCount, 64)
        delegate.application(NSApplication.shared, open: urls)
        XCTAssertTrue(completions.isEmpty)
        XCTAssertEqual(delegate.pendingLinkCount, 64)
        XCTAssertEqual(defaults.data(forKey: "BrowserSwitch.settings.v1"), saved)
    }

    @MainActor
    func testCorruptSettingsRequireConfirmationInsteadOfAutomaticRouting() throws {
        for stored in [Data("invalid".utf8) as Any, "invalid" as Any] {
            let (model, _) = try makeModel(storedSettings: stored)
            XCTAssertTrue(model.settingsRequireReview)
            var opened = false
            let delegate = AppDelegate(model: model, openLink: { _, _, _ in opened = true })
            delegate.application(NSApplication.shared, open: [URL(string: "https://security.invalid")!])
            XCTAssertFalse(opened)
            XCTAssertEqual(delegate.pendingLinkCount, 1)
            model.settings.showsMenuBarIcon.toggle()
            XCTAssertFalse(model.settingsRequireReview)
        }
    }

    @MainActor
    func testInvalidLinksAndUnregisteredApplicationsAreNotOpened() throws {
        let (model, _) = try makeModel()
        var opened = false
        let delegate = AppDelegate(model: model, openLink: { _, _, _ in opened = true })
        delegate.application(NSApplication.shared, open: [URL(string: "javascript:alert(1)")!, URL(string: "https://%65xample.com")!])
        XCTAssertFalse(opened)
        XCTAssertEqual(delegate.pendingLinkCount, 0)

        let fake = InstalledBrowser(id: "org.songming.NotRegistered", name: "Unregistered", url: URL(fileURLWithPath: "/tmp/unregistered.app"), icon: NSImage())
        var result: Bool?
        model.open(URL(string: "https://security.invalid")!, in: fake) { result = $0 }
        XCTAssertEqual(result, false)
    }

    @MainActor
    func testDomainPreferencesExcludePastedPathsAndTokens() throws {
        let (model, defaults) = try makeModel()
        XCTAssertNil(model.addDomain("https://example.com/private/callback?token=TEST_ONLY#session"))
        XCTAssertEqual(model.settings.rules.map(\.domain), ["example.com"])
        let data = try XCTUnwrap(defaults.data(forKey: "BrowserSwitch.settings.v1"))
        let saved = try XCTUnwrap(String(data: data, encoding: .utf8))
        for privateValue in ["private", "callback", "token", "TEST_ONLY", "session", "https://"] {
            XCTAssertFalse(saved.contains(privateValue))
        }
    }

    @MainActor
    func testSystemHandoffDisablesRecentItemsAndDoesNotExposeErrorURLs() throws {
        let (_, defaults) = try makeModel()
        let url = URL(string: "https://user:secret@security.invalid/private?token=TEST_ONLY")!
        var called = false
        let model = AppModel(defaults: defaults, workspaceOpen: { urls, _, configuration, completion in
            called = true
            XCTAssertEqual(urls, [url])
            XCTAssertFalse(configuration.addsToRecentItems)
            XCTAssertFalse(configuration.allowsRunningApplicationSubstitution)
            XCTAssertFalse(configuration.promptsUserIfNeeded)
            completion(NSError(domain: NSCocoaErrorDomain, code: 256, userInfo: [NSLocalizedDescriptionKey: url.absoluteString]))
        })
        guard let browser = model.defaultBrowser else { throw XCTSkip("Requires an installed browser in Launch Services.") }
        var result: Bool?
        model.open(url, in: browser) { result = $0 }
        XCTAssertTrue(called)
        XCTAssertEqual(result, false)
        let message = try XCTUnwrap(model.errorMessage)
        for privateValue in ["secret", "security.invalid", "private", "TEST_ONLY"] {
            XCTAssertFalse(message.contains(privateValue))
        }
        XCTAssertNil(defaults.data(forKey: "BrowserSwitch.settings.v1"))
    }
}
