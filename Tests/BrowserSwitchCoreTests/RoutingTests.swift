import XCTest
@testable import BrowserSwitchCore

final class RoutingTests: XCTestCase {
    func testDomainInputNormalization() {
        XCTAssertEqual(DomainName.parse(" EXAMPLE.COM. "), "example.com")
        XCTAssertEqual(DomainName.parse("https://Docs.Example.com:8443/path?q=1#part"), "docs.example.com")
        XCTAssertEqual(DomainName.parse("localhost"), "localhost")
        XCTAssertEqual(DomainName.parse("https://bücher.de"), "xn--bcher-kva.de")
        XCTAssertEqual(DomainName.parse("127.0.0.1"), "127.0.0.1")
        XCTAssertEqual(DomainName.parse("[::1]"), "::1")
    }

    func testInvalidDomainsAreRejected() {
        for input in ["", " ", "*.example.com", "https://", "javascript:alert(1)", "file:///tmp/page.html", "ftp://example.com", "user@example.com", "example..com", ".example.com", "example.com..", "-example.com", "example-.com", "exa mple.com", "example.com\n.evil.com", "https://example.com@evil.com"] {
            XCTAssertNil(DomainName.parse(input), input)
        }
        XCTAssertNil(DomainName.parse(String(repeating: "a", count: 64) + ".com"))
    }

    func testSubdomainBoundariesPreventLookalikeMatches() {
        let rule = DomainRule(domain: "example.com")
        for host in ["example.com", "EXAMPLE.COM.", "docs.example.com", "a.b.example.com"] {
            XCTAssertTrue(rule.matches(host: host), host)
        }
        for host in ["notexample.com", "example.com.evil.com", "example-com", "example.org", "evil-example.com"] {
            XCTAssertFalse(rule.matches(host: host), host)
        }
    }

    func testRoutingUsesHostAndIncludesSubdomainsByDefault() {
        let rules = [DomainRule(domain: "example.com")]
        XCTAssertTrue(Routing.shouldAsk(for: URL(string: "https://example.com/a")!, rules: rules))
        XCTAssertTrue(Routing.shouldAsk(for: URL(string: "https://docs.example.com")!, rules: rules))
        XCTAssertFalse(Routing.shouldAsk(for: URL(string: "https://evil.com/example.com")!, rules: rules))
        XCTAssertFalse(Routing.shouldAsk(for: URL(string: "https://example.com@evil.com")!, rules: rules))
        XCTAssertFalse(Routing.shouldAsk(for: URL(string: "ftp://example.com")!, rules: rules))
        XCTAssertFalse(Routing.shouldAsk(for: URL(string: "https://example.com")!, rules: []))
        let exactRules = [DomainRule(domain: "example.com", includesSubdomains: false)]
        XCTAssertTrue(Routing.shouldAsk(for: URL(string: "https://example.com/a")!, rules: exactRules))
        XCTAssertFalse(Routing.shouldAsk(for: URL(string: "https://docs.example.com")!, rules: exactRules))
    }

    func testBrowserFallbackIsDeterministicAndNeverMissing() {
        let installed = ["org.mozilla.firefox", "com.apple.Safari", "com.google.Chrome"]
        XCTAssertEqual(Routing.fallbackBrowser(preferred: "org.mozilla.firefox", available: installed), "org.mozilla.firefox")
        XCTAssertEqual(Routing.fallbackBrowser(preferred: "missing", available: installed), "com.google.Chrome")
        XCTAssertEqual(Routing.fallbackBrowser(preferred: "missing", available: ["com.apple.Safari", "other"]), "com.apple.Safari")
        XCTAssertEqual(Routing.fallbackBrowser(preferred: "missing", available: ["other"]), "other")
        XCTAssertNil(Routing.fallbackBrowser(preferred: "missing", available: []))
    }

    func testOrderingAndVisibilityHandleInstallChanges() {
        let preferences = [BrowserPreference(bundleID: "firefox", isVisible: false), BrowserPreference(bundleID: "removed"), BrowserPreference(bundleID: "safari")]
        let available = ["chrome", "safari", "firefox", "new"]
        XCTAssertEqual(Routing.orderedBrowserIDs(available: available, preferences: preferences), ["firefox", "safari", "chrome", "new"])
        XCTAssertEqual(Routing.visibleBrowserIDs(available: available, preferences: preferences), ["safari", "chrome", "new"])
        XCTAssertEqual(Routing.fallbackBrowser(preferred: "firefox", available: available), "firefox")
    }

    func testSettingsRoundTripAndInitialDefaults() throws {
        var settings = AppSettings()
        XCTAssertTrue(settings.rules.isEmpty)
        XCTAssertTrue(settings.showsMenuBarIcon)
        XCTAssertFalse(settings.keepsDockIcon)
        XCTAssertEqual(settings.defaultBrowserID, "com.google.Chrome")
        settings.rules = [DomainRule(domain: "example.com")]
        settings.browsers = [BrowserPreference(bundleID: "firefox", isVisible: false)]
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)), settings)
        XCTAssertThrowsError(try JSONDecoder().decode(AppSettings.self, from: Data("broken".utf8)))
    }

    func testExistingExactDomainRulesAndBrowserPreferencesArePreserved() throws {
        let legacy = Data(#"{"schemaVersion":1,"rules":[{"id":"D7B39451-63B4-4D6C-9E37-A69C4B93F866","domain":"example.com","includesSubdomains":false}],"browsers":[{"bundleID":"org.mozilla.firefox","isVisible":false}],"defaultBrowserID":"com.apple.Safari","showsMenuBarIcon":false,"keepsDockIcon":true}"#.utf8)
        let saved = try JSONDecoder().decode(AppSettings.self, from: legacy)
        let rule = try XCTUnwrap(saved.rules.first)
        XCTAssertEqual(rule.id.uuidString, "D7B39451-63B4-4D6C-9E37-A69C4B93F866")
        XCTAssertFalse(rule.matches(host: "docs.example.com"))
        XCTAssertTrue(rule.matches(host: "example.com"))
        XCTAssertFalse(rule.matches(host: "example.com.evil.org"))
        XCTAssertEqual(saved.defaultBrowserID, "com.apple.Safari")
        XCTAssertEqual(saved.browsers, [BrowserPreference(bundleID: "org.mozilla.firefox", isVisible: false)])
        XCTAssertFalse(saved.showsMenuBarIcon)
        XCTAssertTrue(saved.keepsDockIcon)
        XCTAssertEqual(try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(saved)), saved)
    }

    func testInitialBrowserOrderAndUserOverride() {
        let available = ["brave", "com.microsoft.edgemac", "com.apple.Safari", "org.mozilla.firefox", "com.google.Chrome", "zeta"]
        XCTAssertEqual(Routing.orderedBrowserIDs(available: available, preferences: []),
                       ["com.google.Chrome", "org.mozilla.firefox", "com.apple.Safari", "com.microsoft.edgemac", "brave", "zeta"])
        let custom = [BrowserPreference(bundleID: "com.apple.Safari"), BrowserPreference(bundleID: "brave", isVisible: false)]
        XCTAssertEqual(Routing.orderedBrowserIDs(available: available, preferences: custom),
                       ["com.apple.Safari", "brave", "com.google.Chrome", "org.mozilla.firefox", "com.microsoft.edgemac", "zeta"])
    }

    func testPickerShortcutsFollowNumberAndKeyboardOrder() {
        let keys = (0..<40).compactMap { BrowserPickerShortcuts.key(at: $0) }
        XCTAssertEqual(keys.count, 34)
        XCTAssertEqual(Set(keys).count, 34)
        XCTAssertFalse(keys.contains("9"))
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 0), "1")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 7), "8")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 8), "q")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 17), "p")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 18), "a")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 26), "l")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 27), "z")
        XCTAssertEqual(BrowserPickerShortcuts.key(at: 33), "m")
        XCTAssertNil(BrowserPickerShortcuts.key(at: -1))
        XCTAssertNil(BrowserPickerShortcuts.key(at: 34))
    }

    func testOnlyBoundedWebLinksAndLocalHTMLAreAccepted() {
        for input in ["https://example.com", "http://localhost:8080/a?b=c#d", "file:///tmp/page.html", "file:///tmp/page.XHTML"] {
            XCTAssertTrue(Routing.accepts(URL(string: input)!), input)
        }
        for input in ["javascript:alert(1)", "data:text/html,test", "mailto:user@example.com", "browser-switch://open", "file:///tmp/run.sh", "file://remote/share/page.html", "https://example.com:65536", "http://example.com:0"] {
            XCTAssertFalse(Routing.accepts(URL(string: input)!), input)
        }
        XCTAssertFalse(Routing.accepts(URL(string: "https://example.com/" + String(repeating: "a", count: 65_536))!))
    }
}
