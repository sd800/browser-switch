# Changelog

## 26.1024.5 — 2026-10-24

### Added

- Product website with an interactive routing preview, automatic light and dark appearance, installation instructions, and GitHub Pages deployment.
- Universal macOS download and SHA-256 checksum on GitHub Releases.

### Changed

- Refine website download navigation and installation copy.

### Fixed

- Correct browser picker placement when first opening and reopening the window.
- Keep queued links in a stable position when longer addresses change the window height.
- Exclude filesystem metadata from distribution archives so extracted app signatures remain valid.

## 26.1024.4 — 2026-10-24

### Changed

- Open the browser picker slightly above screen center and keep its position stable between queued links.
- Organize project documentation.

### Fixed

- Keep newly added domains fully visible when alphabetical sorting inserts them above existing entries.

## 26.1024.3 — 2026-10-24

### Fixed

- Leave domain inputs unfocused when opening the Domains page or add-domain window.
- Clear domain input focus when clicking outside the field or completing an inline addition.

## 26.1024.2 — 2026-10-24

### Changed

- Add domains directly from the Domains page with Return or Add Domain, without a separate sheet.
- Include subdomains when adding a domain inline; show each rule's matching scope without a per-row switch.
- Simplify domain entry by hiding search.
- Keep the Command-N add-domain window for choosing whether a new rule includes subdomains.

### Fixed

- Improve local app packaging reliability.

## 26.1024.1 — 2026-10-24

### Added

- Native macOS app registered for HTTP, HTTPS, and HTML documents.
- Domain-based browser selection with optional subdomain matching and an initially empty domain list.
- Configurable default browser with Google Chrome and Safari fallbacks.
- System-discovered browser options with visibility controls and custom ordering.
- Browser picker with per-link choices, number keys followed by letter keys in keyboard order, and a bounded queue.
- Independent menu bar and Dock preferences, optional launch at login, and Spotlight reopening.
- English interface with native system controls, the system accent color, and automatic light and dark appearance.
- App Sandbox, Hardened Runtime, URL validation, and local-only preferences without browsing history or analytics.
- Universal build script, Xcode project, and routing and security tests.
