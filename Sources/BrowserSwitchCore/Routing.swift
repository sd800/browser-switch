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
        guard let host = DomainName.validatedHost(host), let domain = DomainName.validatedHost(domain) else { return false }
        return host == domain || (includesSubdomains && !DomainName.isIPAddress(domain) && host.hasSuffix("." + domain))
    }
}

public enum DomainName {
    private static let labelCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
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
        guard input.utf8.count <= Routing.maximumURLBytes else { return nil }
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.contains("*"), !value.contains(where: { $0.isWhitespace }) else { return nil }
        let candidate = value.contains("://") ? value : "https://" + value
        guard let components = URLComponents(string: candidate),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
              components.user == nil, components.password == nil,
              let url = components.url else { return nil }
        return Routing.webHost(url)
    }

    public static func validatedHost(_ input: String) -> String? {
        let host = canonicalHost(input)
        // IPv6 literals are valid URL hosts. DNS labels must not be empty or malformed.
        if host.contains(":") {
            var address = in6_addr()
            guard inet_pton(AF_INET6, host, &address) == 1 else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
            guard inet_ntop(AF_INET6, &address, &buffer, socklen_t(buffer.count)) != nil else { return nil }
            return String(cString: buffer)
        }
        guard !host.isEmpty, host.count <= 253 else { return nil }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            !label.isEmpty && label.count <= 63 && label.first != "-" && label.last != "-" &&
            label.unicodeScalars.allSatisfy { labelCharacters.contains($0) }
        }) else { return nil }
        // Browsers interpret short, octal, hexadecimal, and integer IPv4 forms.
        // Accept only unambiguous dotted-decimal addresses for numeric hosts.
        if let last = labels.last,
           last.allSatisfy({ $0.isASCII && $0.isNumber }) ||
            (last.hasPrefix("0x") && last.dropFirst(2).allSatisfy({ $0.isHexDigit })) {
            var address = in_addr()
            guard inet_pton(AF_INET, host, &address) == 1 else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            guard inet_ntop(AF_INET, &address, &buffer, socklen_t(buffer.count)) != nil,
                  String(cString: buffer) == host else { return nil }
        }
        return host
    }

    public static func isIPAddress(_ host: String) -> Bool {
        var ipv4 = in_addr()
        var ipv6 = in6_addr()
        return inet_pton(AF_INET, host, &ipv4) == 1 || inet_pton(AF_INET6, host, &ipv6) == 1
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
    private static let identifierCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-")
    public static let maximumDataBytes = 1_048_576
    public static let maximumRules = 1_024
    public static let maximumBrowsers = 256
    public var schemaVersion = 1
    public var rules: [DomainRule] = []
    public var browsers: [BrowserPreference] = []
    public var defaultBrowserID = "com.google.Chrome"
    public var showsMenuBarIcon = true
    public var keepsDockIcon = false

    public init() {}

    public static func decode(_ data: Data) -> AppSettings? {
        guard data.count <= maximumDataBytes,
              var saved = try? JSONDecoder().decode(Self.self, from: data),
              saved.schemaVersion == 1, saved.rules.count <= maximumRules,
              saved.browsers.count <= maximumBrowsers else { return nil }
        for index in saved.rules.indices {
            guard let domain = DomainName.validatedHost(saved.rules[index].domain) else { return nil }
            saved.rules[index].domain = domain
        }
        guard saved.isValid else { return nil }
        return saved
    }

    public var isValid: Bool {
        guard schemaVersion == 1, rules.count <= Self.maximumRules, browsers.count <= Self.maximumBrowsers,
              Set(rules.map(\.id)).count == rules.count,
              Set(rules.map(\.domain)).count == rules.count,
              Set(browsers.map(\.bundleID)).count == browsers.count,
              Self.validBrowserID(defaultBrowserID) else { return false }
        return rules.allSatisfy { DomainName.validatedHost($0.domain) == $0.domain } &&
            browsers.allSatisfy { Self.validBrowserID($0.bundleID) }
    }

    private static func validBrowserID(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 255 && value.unicodeScalars.allSatisfy {
            identifierCharacters.contains($0)
        }
    }
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
            return webHost(url) != nil
        }
        // Only locally associated HTML files are accepted. Never dispatch arbitrary schemes.
        guard url.isFileURL, let authority = authority(of: url),
              authority.isEmpty || authority.lowercased() == "localhost",
              !url.path.hasPrefix("//"),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let path = components.percentEncodedPath.removingPercentEncoding,
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              ["html", "htm", "xhtml"].contains(url.pathExtension.lowercased()) else { return false }
        return true
    }

    public static func webHost(_ url: URL) -> String? {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              url.absoluteString.utf8.count <= maximumURLBytes,
              let authority = authority(of: url),
              !authority.contains("\\"), !authority.lowercased().contains("%5c"),
              let hostPort = authority.split(separator: "@", omittingEmptySubsequences: false).last,
              !hostPort.isEmpty else { return nil }
        let rawHost: String
        let suffix: Substring
        if hostPort.hasPrefix("[") {
            guard let end = hostPort.firstIndex(of: "]") else { return nil }
            rawHost = String(hostPort[...end])
            suffix = hostPort[hostPort.index(after: end)...]
        } else {
            let parts = hostPort.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            rawHost = String(parts[0])
            suffix = hostPort.dropFirst(parts[0].count)
        }
        // Inspect the original authority: URLComponents.port returns nil both
        // for an absent port and for integer overflow, which must be rejected.
        if !suffix.isEmpty {
            let portText = suffix.dropFirst()
            guard suffix.first == ":", !portText.isEmpty,
                  portText.allSatisfy({ $0.isASCII && $0.isNumber }),
                  let port = Int(portText), (1...65535).contains(port) else { return nil }
        }
        guard !rawHost.contains("%"), let host = DomainName.validatedHost(rawHost),
              let parsedHost = url.host, DomainName.validatedHost(parsedHost) == host else { return nil }
        return host
    }

    private static func authority(of url: URL) -> Substring? {
        let value = url.absoluteString
        guard let scheme = url.scheme, value.dropFirst(scheme.count).hasPrefix("://"),
              !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return nil }
        return value.dropFirst(scheme.count + 3).prefix { $0 != "/" && $0 != "?" && $0 != "#" }
    }

    public static func shouldAsk(for url: URL, rules: [DomainRule]) -> Bool {
        guard let host = webHost(url) else { return false }
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
