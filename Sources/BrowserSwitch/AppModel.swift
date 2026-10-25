import AppKit
import CoreServices
import SwiftUI
#if SWIFT_PACKAGE
import BrowserSwitchCore
#endif

struct InstalledBrowser: Identifiable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage
}

enum AppStyle {
    static var accent: Color { Color(nsColor: .controlAccentColor) }
}

@MainActor
final class AppModel: ObservableObject {
    typealias WorkspaceOpener = ([URL], URL, NSWorkspace.OpenConfiguration, @escaping (Error?) -> Void) -> Void
    static let bundleID = "org.songming.BrowserSwitch"
    @Published var settings: AppSettings {
        didSet {
            guard settings.isValid else { settingsRequireReview = true; return }
            settingsRequireReview = false
            save()
            onSettingsChange?()
        }
    }
    @Published private(set) var browsers: [InstalledBrowser] = []
    @Published private(set) var isSystemDefault = false
    @Published var errorMessage: String?
    @Published var isSettingDefault = false
    @Published private(set) var settingsRequireReview = false
    var onSettingsChange: (() -> Void)?
    private let defaults: UserDefaults
    private let workspaceOpen: WorkspaceOpener
    private static let settingsKey = "BrowserSwitch.settings.v1"

    init(defaults: UserDefaults = .standard, workspaceOpen: WorkspaceOpener? = nil) {
        self.defaults = defaults
        self.workspaceOpen = workspaceOpen ?? { urls, applicationURL, configuration, completion in
            NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration) { _, error in
                Task { @MainActor in completion(error) }
            }
        }
        if let data = defaults.data(forKey: Self.settingsKey), let saved = AppSettings.decode(data) {
            settings = saved
        } else {
            settings = AppSettings()
            if defaults.object(forKey: Self.settingsKey) != nil {
                settingsRequireReview = true
                errorMessage = "Saved settings could not be read. Automatic routing is paused until you update your settings."
            }
        }
        refreshBrowsers()
    }

    var orderedBrowsers: [InstalledBrowser] {
        Routing.orderedBrowserIDs(available: browsers.map(\.id), preferences: settings.browsers)
            .compactMap { id in browsers.first { $0.id == id } }
    }

    var visibleBrowsers: [InstalledBrowser] {
        let visible = Routing.visibleBrowserIDs(available: browsers.map(\.id), preferences: settings.browsers)
        return visible.compactMap { id in browsers.first { $0.id == id } }
    }

    var defaultBrowser: InstalledBrowser? {
        guard let id = Routing.fallbackBrowser(preferred: settings.defaultBrowserID, available: browsers.map(\.id)) else { return nil }
        return browsers.first { $0.id == id }
    }

    func refreshBrowsers() {
        let workspace = NSWorkspace.shared
        let http = Set(workspace.urlsForApplications(toOpen: URL(string: "http://example.com")!).map(\.standardizedFileURL))
        let https = Set(workspace.urlsForApplications(toOpen: URL(string: "https://example.com")!).map(\.standardizedFileURL))
        // System browser candidates must also handle HTML. Read identities from the
        // registry: sandboxed apps cannot inspect every registered bundle's Info.plist.
        let htmlIDs = LSCopyAllRoleHandlersForContentType("public.html" as CFString, .all)?.takeRetainedValue() as? [String] ?? []
        var seen = Set<String>()
        browsers = htmlIDs.compactMap { id in
            guard id != Self.bundleID, seen.insert(id).inserted,
                  let url = workspace.urlForApplication(withBundleIdentifier: id),
                  url.resolvingSymlinksInPath().standardizedFileURL != Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL,
                  http.contains(url.standardizedFileURL), https.contains(url.standardizedFileURL) else { return nil }
            let bundle = Bundle(url: url)
            let name = (bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            return InstalledBrowser(id: id, name: name, url: url, icon: workspace.icon(forFile: url.path))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        refreshDefaultStatus()
    }

    func refreshDefaultStatus() {
        isSystemDefault = ["http", "https"].allSatisfy { scheme in
            guard let url = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(scheme)://example.com")!) else { return false }
            return Bundle(url: url)?.bundleIdentifier == Self.bundleID
        }
    }

    func makeSystemDefault() {
        guard !isSettingDefault else { return }
        isSettingDefault = true
        Task {
            defer { isSettingDefault = false; refreshDefaultStatus() }
            do {
                for scheme in ["http", "https"] {
                    let probe = URL(string: "\(scheme)://example.com")!
                    if NSWorkspace.shared.urlForApplication(toOpen: probe).flatMap({ Bundle(url: $0)?.bundleIdentifier }) != Self.bundleID {
                        try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
                    }
                }
            } catch {
                refreshDefaultStatus()
                if !isSystemDefault {
                    errorMessage = "Browser Switch was not set as the default browser. You can also choose it in System Settings → Desktop & Dock → Default web browser."
                }
            }
        }
    }

    func setVisibility(_ visible: Bool, for browser: InstalledBrowser) {
        var preferences = orderedBrowsers.map { BrowserPreference(bundleID: $0.id, isVisible: isVisible($0)) }
        if let index = preferences.firstIndex(where: { $0.bundleID == browser.id }) {
            preferences[index].isVisible = visible
        }
        preferences += settings.browsers.filter { item in !preferences.contains { $0.bundleID == item.bundleID } }
        settings.browsers = preferences
    }

    func isVisible(_ browser: InstalledBrowser) -> Bool {
        settings.browsers.first { $0.bundleID == browser.id }?.isVisible ?? true
    }

    func moveBrowser(_ browser: InstalledBrowser, by offset: Int) {
        var ordered = orderedBrowsers.map { BrowserPreference(bundleID: $0.id, isVisible: isVisible($0)) }
        guard let index = ordered.firstIndex(where: { $0.bundleID == browser.id }), ordered.indices.contains(index + offset) else { return }
        ordered.swapAt(index, index + offset)
        // Preserve preferences for temporarily uninstalled browsers.
        ordered += settings.browsers.filter { item in !ordered.contains { $0.bundleID == item.bundleID } }
        settings.browsers = ordered
    }

    @discardableResult
    func addDomain(_ input: String, includesSubdomains: Bool = true) -> String? {
        guard settings.rules.count < AppSettings.maximumRules else { return "The domain list is full. Remove a domain before adding another." }
        guard let domain = DomainName.parse(input) else { return "Enter a valid domain, such as example.com, or paste a web address." }
        guard !settings.rules.contains(where: { $0.domain == domain }) else { return "This domain is already in your list." }
        settings.rules.append(DomainRule(domain: domain, includesSubdomains: includesSubdomains))
        return nil
    }

    func open(_ url: URL, in browser: InstalledBrowser, completion: @escaping (Bool) -> Void) {
        let applicationURL = browser.url.resolvingSymlinksInPath().standardizedFileURL
        guard Routing.accepts(url), browser.id != Self.bundleID, browser.url.isFileURL,
              applicationURL != Bundle.main.bundleURL.resolvingSymlinksInPath().standardizedFileURL,
              let registeredURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browser.id),
              registeredURL.resolvingSymlinksInPath().standardizedFileURL == applicationURL else {
            completion(false)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.allowsRunningApplicationSubstitution = false
        configuration.promptsUserIfNeeded = false
        workspaceOpen([url], browser.url, configuration) { [weak self] error in
            if error != nil {
                // System error descriptions can contain the destination URL.
                self?.errorMessage = "Could not open \(browser.name). Try again or choose another browser."
                self?.refreshBrowsers()
                completion(false)
            } else { completion(true) }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings), data.count <= AppSettings.maximumDataBytes {
            defaults.set(data, forKey: Self.settingsKey)
        }
    }
}
