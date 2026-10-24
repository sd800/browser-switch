# Changelog

## 26.1024.2 — 2026-10-24

### Changed

- Add domains directly from the Domains page with Return or Add Domain, without a separate sheet.
- Include subdomains when adding a domain inline; show each rule's matching scope without a per-row switch.
- Disable domain search while retaining its code for future use.
- Keep the Command-N add-domain window for choosing whether a new rule includes subdomains.

### Fixed

- Sign packaged apps in a temporary folder to avoid file-provider metadata breaking local builds.

## 26.1024.1 — 2026-10-24

### Added

- Native macOS app registered for HTTP, HTTPS, and HTML documents.
- Domain-based browser selection with optional subdomain matching and an initially empty domain list.
- Configurable default browser with Google Chrome and Safari fallbacks.
- System-discovered browser options with visibility controls and custom ordering.
- Browser picker with per-link choices, number keys followed by letter keys in keyboard order, and a bounded queue.
- Independent menu bar and Dock preferences, optional launch at login, and Spotlight reopening.
- English interface with native system controls, 15 pt body text, the system accent color, and automatic light and dark appearance.
- App Sandbox, Hardened Runtime, URL validation, and local-only preferences without browsing history or analytics.
- Universal build script, Xcode project, and routing and security tests.
