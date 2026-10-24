import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import BrowserSwitchCore
#endif

@main
@MainActor
struct BrowserSwitchApplication {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        if CommandLine.arguments.contains("--diagnostics") {
            delegate.printDiagnostics()
            return
        }
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private let model = AppModel()
    private let chooser = ChooserState()
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private var chooserWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private var receivedURLs = false
    private var finishedLaunching = false
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        finishedLaunching = true
        model.onSettingsChange = { [weak self] in self?.updatePresence() }
        updatePresence()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refreshBrowsers), name: NSWorkspace.didLaunchApplicationNotification, object: nil
        )
        // URL events may arrive immediately after launch. Give them the first turn.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if !self.chooser.urls.isEmpty { self.showChooser() }
            else if !self.receivedURLs && !self.launchedAtLogin { self.showSettings() }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        receivedURLs = true
        model.refreshBrowsers()
        for url in urls.prefix(Routing.maximumPendingLinks) {
            guard Routing.accepts(url) else { continue }
            if Routing.shouldAsk(for: url, rules: model.settings.rules) || model.defaultBrowser == nil {
                enqueue(url)
            } else if let browser = model.defaultBrowser {
                model.open(url, in: browser) { [weak self] success in
                    if !success { self?.enqueue(url) }
                }
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationDidBecomeActive(_ notification: Notification) { model.refreshBrowsers() }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window === chooserWindow {
            chooser.urls = []
            chooser.failure = nil
        }
        DispatchQueue.main.async { [weak self] in self?.updatePresence() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if sender === chooserWindow { return !chooser.isOpening }
        return true
    }

    @objc private func refreshBrowsers() { model.refreshBrowsers() }

    private func enqueue(_ url: URL) {
        guard chooser.urls.count < Routing.maximumPendingLinks else { return }
        chooser.urls.append(url)
        if finishedLaunching { showChooser() }
    }

    private func showChooser() {
        guard !chooser.urls.isEmpty else { return }
        model.refreshBrowsers()
        if chooserWindow == nil {
            let view = ChooserView(model: model, state: chooser, choose: { [weak self] in self?.choose($0) },
                                   cancel: { [weak self] in self?.advanceQueue() },
                                   openSettings: { [weak self] in self?.showSettings() })
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Open Link — Browser Switch"
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            chooserWindow = window
        }
        chooserWindow?.center()
        chooserWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func choose(_ browser: InstalledBrowser) {
        guard !chooser.isOpening, let url = chooser.urls.first else { return }
        chooser.isOpening = true
        chooser.failure = nil
        model.open(url, in: browser) { [weak self] success in
            guard let self else { return }
            self.chooser.isOpening = false
            if success {
                self.advanceQueue()
            } else {
                self.chooser.failure = "Couldn’t open \(browser.name). Try again or choose another browser."
                self.model.errorMessage = nil
                self.showChooser()
            }
        }
    }

    private func advanceQueue() {
        guard !chooser.isOpening else { return }
        if !chooser.urls.isEmpty { chooser.urls.removeFirst() }
        chooser.failure = nil
        if chooser.urls.isEmpty { chooserWindow?.close() }
        else { showChooser() }
    }

    @objc func showSettings() {
        model.refreshBrowsers()
        if settingsWindow == nil {
            let hosting = NSHostingController(rootView: SettingsView(model: model))
            hosting.sizingOptions = []
            let window = NSWindow(contentViewController: hosting)
            window.title = "Browser Switch"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 860, height: 640))
            window.minSize = NSSize(width: 780, height: 580)
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Browser Switch",
            .applicationVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "26.1024.1",
            .version: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        ])
        aboutWindow = NSApp.keyWindow
        if aboutWindow !== settingsWindow, aboutWindow !== chooserWindow {
            aboutWindow?.isRestorable = false
            aboutWindow?.delegate = self
        }
    }

    private func updatePresence() {
        guard finishedLaunching else { return }
        let hasSettings = settingsWindow?.isVisible == true || aboutWindow?.isVisible == true
        NSApp.setActivationPolicy(model.settings.keepsDockIcon || hasSettings ? .regular : .accessory)
        if model.settings.showsMenuBarIcon {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
                let image = NSImage(systemSymbolName: "arrow.triangle.branch", accessibilityDescription: "Browser Switch")
                image?.isTemplate = true
                statusItem?.button?.image = image
                statusItem?.button?.toolTip = "Browser Switch"
            }
            let menu = NSMenu()
            let heading = NSMenuItem(title: "Browser Switch", action: nil, keyEquivalent: "")
            heading.isEnabled = false
            menu.addItem(heading)
            let defaultItem = NSMenuItem(title: "Default: \(model.defaultBrowser?.name ?? "No browser available")", action: nil, keyEquivalent: "")
            defaultItem.isEnabled = false
            menu.addItem(defaultItem)
            menu.addItem(.separator())
            addItem(to: menu, title: "Settings…", action: #selector(showSettings), key: ",", symbol: "gearshape")
            addItem(to: menu, title: "About Browser Switch", action: #selector(showAbout), symbol: "info.circle")
            menu.addItem(.separator())
            addItem(to: menu, title: "Quit Browser Switch", action: #selector(NSApplication.terminate(_:)), key: "q", symbol: "power", target: NSApp)
            statusItem?.menu = menu
        } else if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    private func buildMainMenu() {
        let main = NSMenu()
        let appMenu = NSMenu(title: "Browser Switch")
        addItem(to: appMenu, title: "About Browser Switch", action: #selector(showAbout), symbol: "info.circle")
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "Settings…", action: #selector(showSettings), key: ",", symbol: "gearshape")
        appMenu.addItem(.separator())
        let services = NSMenu()
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = services
        appMenu.addItem(servicesItem)
        NSApp.servicesMenu = services
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "Hide Browser Switch", action: #selector(NSApplication.hide(_:)), key: "h", target: NSApp)
        let hideOthers = addItem(to: appMenu, title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), key: "h", target: NSApp)
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        addItem(to: appMenu, title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), target: NSApp)
        appMenu.addItem(.separator())
        addItem(to: appMenu, title: "Quit Browser Switch", action: #selector(NSApplication.terminate(_:)), key: "q", symbol: "power", target: NSApp)
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        main.addItem(appItem)

        let file = NSMenu(title: "File")
        addItem(to: file, title: "Close Window", action: #selector(NSWindow.performClose(_:)), key: "w", symbol: "xmark", target: nil)
        let fileItem = NSMenuItem(title: "File", action: nil, keyEquivalent: "")
        fileItem.submenu = file
        main.addItem(fileItem)

        let edit = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            addItem(to: edit, title: title, action: NSSelectorFromString(selector), key: key, target: nil)
        }
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editItem.submenu = edit
        main.addItem(editItem)

        let window = NSMenu(title: "Window")
        addItem(to: window, title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), key: "m", target: nil)
        addItem(to: window, title: "Zoom", action: #selector(NSWindow.performZoom(_:)), target: nil)
        window.addItem(.separator())
        addItem(to: window, title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), target: NSApp)
        let windowItem = NSMenuItem(title: "Window", action: nil, keyEquivalent: "")
        windowItem.submenu = window
        main.addItem(windowItem)
        NSApp.windowsMenu = window
        NSApp.mainMenu = main
    }

    @discardableResult
    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "", symbol: String? = nil, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target ?? ([#selector(showSettings), #selector(showAbout)].contains(action) ? self : nil)
        if let symbol { item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil) }
        menu.addItem(item)
        return item
    }

    func printDiagnostics() {
        let result: [String: Any] = [
            "browsers": model.orderedBrowsers.map { ["id": $0.id, "name": $0.name, "path": $0.url.path] },
            "defaultBrowser": model.defaultBrowser?.id ?? "",
            "isSystemDefault": model.isSystemDefault
        ]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) { print(text) }
    }
}
