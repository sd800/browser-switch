import Foundation
import Darwin

public struct DomainRule: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var domain: String
    public var includesSubdomains: Bool

    public init(id: UUID = UUID(), domain: String, includesSubdomains: Bool = true) {
        self.id = id
        self.domain = domain
        self.includesSubdomains = includesSubdomains
    }

    public func matches(host: String) -> Bool {
        let host = DomainName.canonicalHost(host)
        return host == domain || (includesSubdomains && host.hasSuffix("." + domain))
    }
}

public enum DomainName {
    public static func canonicalHost(_ host: String) -> String {
        var normalized = host.lowercased()
        if normalized.hasSuffix(".") { normalized.removeLast() }
        if normalized.hasPrefix("["), normalized.hasSuffix("]") {
            return String(normalized.dropFirst().dropLast())
        }
        return normalized
    }

    /// Accepts a hostname or a pasted HTTP(S) URL; stores only its ASCII hostname.
    public static func parse(_ input: String) -> String? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("*"), !value.contains(where: { $0.isWhitespace }) else { return nil }
        let candidate = value.contains("://") ? value : "https://" + value
        guard let components = URLComponents(string: candidate),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.user == nil, components.password == nil,
              let url = components.url, let rawHost = url.host, !rawHost.isEmpty else { return nil }
        let host = canonicalHost(rawHost)
        // IPv6 literals are valid URL hosts. DNS labels must not be empty or malformed.
        if host.contains(":") {
            var address = in6_addr()
            return inet_pton(AF_INET6, host, &address) == 1 ? host : nil
        }
        guard host.count <= 253 else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
            label.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-").contains($0) }
        }) else { return nil }
        return host
    }
}

public struct BrowserPreference: Codable, Equatable, Sendable {
    public var bundleID: String
    public var isVisible: Bool

    public init(bundleID: String, isVisible: Bool = true) {
        self.bundleID = bundleID
        self.isVisible = isVisible
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var rules: [DomainRule] = []
    public var browsers: [BrowserPreference] = []
    public var defaultBrowserID = "com.google.Chrome"
    public var showsMenuBarIcon = true
    public var keepsDockIcon = false

    public init() {}
}

public enum BrowserPickerShortcuts {
    private static let keys = Array("12345678qwertyuiopasdfghjklzxcvbnm").map(String.init)

    public static func key(at index: Int) -> String? {
        keys.indices.contains(index) ? keys[index] : nil
    }
}

public enum Routing {
    public static let maximumURLBytes = 65_536
    public static let maximumPendingLinks = 64

    public static func accepts(_ url: URL) -> Bool {
        guard url.absoluteString.utf8.count <= maximumURLBytes else { return false }
        let scheme = url.scheme?.lowercased() ?? ""
        if ["http", "https"].contains(scheme) {
            guard let host = url.host, !host.isEmpty,
                  let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.port.map({ (1...65535).contains($0) }) ?? true else { return false }
            return true
        }
        // Only locally associated HTML files are accepted. Never dispatch arbitrary schemes.
        return url.isFileURL && (url.host == nil || url.host == "" || url.host == "localhost") &&
            ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased())
    }

    public static func shouldAsk(for url: URL, rules: [DomainRule]) -> Bool {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host else { return false }
        return rules.contains { $0.matches(host: host) }
    }

    public static func fallbackBrowser(preferred: String, available: [String]) -> String? {
        ([preferred, "com.google.Chrome", "com.apple.Safari"] + available).first { available.contains($0) }
    }

    public static func orderedBrowserIDs(available: [String], preferences: [BrowserPreference]) -> [String] {
        let saved = preferences.map(\.bundleID).filter { available.contains($0) }
        let preferred = ["com.google.Chrome", "org.mozilla.firefox", "com.apple.Safari", "com.microsoft.edgemac"]
        let initial = preferred.filter { available.contains($0) } + available.filter { !preferred.contains($0) }
        return saved + initial.filter { !saved.contains($0) }
    }

    public static func visibleBrowserIDs(available: [String], preferences: [BrowserPreference]) -> [String] {
        orderedBrowserIDs(available: available, preferences: preferences).filter { id in
            preferences.first(where: { $0.bundleID == id })?.isVisible ?? true
        }
    }
}
