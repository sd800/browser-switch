import AppKit
import XCTest
@testable import BrowserSwitch

final class LaunchTests: XCTestCase {
    @MainActor
    private func makeDelegate(launchEvent: @escaping () -> NSAppleEventDescriptor?,
                              openLink: AppDelegate.LinkOpener? = nil) throws -> AppDelegate {
        let application = NSApplication.shared
        guard !NSScreen.screens.isEmpty else { throw XCTSkip("Launch tests require a graphical macOS session.") }
        let initialWindows = Set(application.windows.map(ObjectIdentifier.init))
        let initialMenu = application.mainMenu
        let suite = "org.songming.BrowserSwitch.LaunchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let model = AppModel(defaults: defaults)
        model.settings.showsMenuBarIcon = false
        model.settings.keepsDockIcon = false
        let delegate = AppDelegate(model: model, openLink: openLink, launchEvent: launchEvent)
        addTeardownBlock { @MainActor in
            NSWorkspace.shared.notificationCenter.removeObserver(delegate)
            for window in application.windows where !initialWindows.contains(ObjectIdentifier(window)) {
                window.close()
            }
            application.mainMenu = initialMenu
            defaults.removePersistentDomain(forName: suite)
        }
        return delegate
    }

    @MainActor
    private func openEvent(atLogin: Bool = false) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(eventClass: kCoreEventClass, eventID: kAEOpenApplication,
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        if atLogin {
            event.setParam(NSAppleEventDescriptor(enumCode: keyAELaunchedAsLogInItem), forKeyword: keyAEPropData)
        }
        return event
    }

    @MainActor
    private var settingsVisible: Bool {
        NSApplication.shared.windows.contains { $0.title == "Browser Switch" && $0.isVisible }
    }

    @MainActor
    private func finishLaunch(_ delegate: AppDelegate) {
        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.35))
    }

    @MainActor
    func testLoginEventArrivingAfterWillFinishLaunchKeepsSettingsHiddenUntilManualReopen() throws {
        var event: NSAppleEventDescriptor?
        var eventReads = 0
        let delegate = try makeDelegate(launchEvent: { eventReads += 1; return event })
        delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
        XCTAssertEqual(eventReads, 0)
        event = openEvent(atLogin: true)
        finishLaunch(delegate)
        XCTAssertEqual(eventReads, 1)
        XCTAssertFalse(settingsVisible)

        XCTAssertTrue(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        XCTAssertTrue(settingsVisible)
    }

    @MainActor
    func testManualLaunchShowsSettings() throws {
        let event = openEvent()
        let delegate = try makeDelegate(launchEvent: { event })
        delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
        finishLaunch(delegate)
        XCTAssertTrue(settingsVisible)
    }

    @MainActor
    func testLinkLaunchRoutesWithoutOpeningSettings() throws {
        let event = NSAppleEventDescriptor(eventClass: AEEventClass(kInternetEventClass), eventID: AEEventID(kAEGetURL),
                                          targetDescriptor: nil, returnID: AEReturnID(kAutoGenerateReturnID),
                                          transactionID: AETransactionID(kAnyTransactionID))
        var opened = false
        let delegate = try makeDelegate(launchEvent: { event }, openLink: { _, _, completion in
            opened = true
            completion(true)
        })
        delegate.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
        delegate.application(NSApplication.shared, open: [URL(string: "https://launch.invalid")!])
        finishLaunch(delegate)
        XCTAssertTrue(opened)
        XCTAssertFalse(settingsVisible)
    }
}
