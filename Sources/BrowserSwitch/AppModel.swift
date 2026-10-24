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
    static let bundleID = "org.songming.BrowserSwitch"
    @Published var settings: AppSettings { didSet { save(); onSettingsChange?() } }
    @Published private(set) var browsers: [InstalledBrowser] = []
    @Published private(set) var isSystemDefault = false
    @Published var errorMessage: String?
    @Published var isSettingDefault = false
    var onSettingsChange: (() -> Void)?
    private let defaults: UserDefaults
    private static let settingsKey = "BrowserSwitch.settings.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.settingsKey), let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved
        } else {
            settings = AppSettings()
            if defaults.data(forKey: Self.settingsKey) != nil {
                errorMessage = "Saved settings could not be read. Default settings are in use."
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
        guard let domain = DomainName.parse(input) else { return "Enter a valid domain, such as example.com, or paste a web address." }
        guard !settings.rules.contains(where: { $0.domain == domain }) else { return "This domain is already in your list." }
        settings.rules.append(DomainRule(domain: domain, includesSubdomains: includesSubdomains))
        return nil
    }

    func open(_ url: URL, in browser: InstalledBrowser, completion: @escaping (Bool) -> Void) {
        guard Routing.accepts(url), browser.id != Self.bundleID,
              browser.url.standardizedFileURL != Bundle.main.bundleURL.standardizedFileURL else {
            completion(false)
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: browser.url, configuration: configuration) { [weak self] _, error in
            Task { @MainActor in
                if let error {
                    self?.errorMessage = "Could not open \(browser.name). \(error.localizedDescription)"
                    self?.refreshBrowsers()
                    completion(false)
                } else { completion(true) }
            }
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
    }
}
