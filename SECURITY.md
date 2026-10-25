# Security

## Security model

Browser Switch is a local URL router. It treats incoming URLs as untrusted input and delegates navigation to an explicitly selected, installed browser using `NSWorkspace`. It does not download, render, or execute page content.

The release build enables **App Sandbox** and **Hardened Runtime**. Its entitlement file grants only the sandbox entitlement: no network client or server access, Apple Events automation, user-selected file access, JIT, unsigned executable memory, or disabled library validation. Opening a URL in a browser does not grant Browser Switch access to that browser's data.

### Input handling

- Only HTTP, HTTPS, and associated local HTML documents are accepted. Script, data, custom application schemes, and remote file URLs are rejected.
- URLs are limited to 64 KiB; each incoming batch and the pending picker queue are limited to 64 links. Overflow links are discarded.
- Routing examines the parsed hostname, never a substring of a full URL. Subdomain matches require a dot boundary, preventing matches such as `notexample.com` and `example.com.evil.org`.
- Domain inputs are normalized to lowercase ASCII hostnames, including internationalized domains. Embedded credentials, wildcards, malformed labels, and unsupported schemes are rejected in domain rules.
- Browser Switch excludes its own bundle identifier and application path from dispatch to prevent direct routing loops.
- URLs are passed directly to system application-opening APIs. No shell commands, AppleScript, dynamic code, URL rewriting, or command interpolation is involved.

### Data handling

- Domain rules and browser preferences are stored in the app's local macOS preferences container.
- Incoming URLs are kept only in memory while waiting in the routing queue or being handed off to a browser. A queued URL is removed after a handoff, when the user cancels that link, or when the picker closes.
- Per-link browser selections are used only for the current handoff and are not saved. Incoming URLs and per-link selections are not written to history or diagnostic logs.
- The app contains no analytics, update service, remote configuration, web view, or third-party dependencies.
- The optional diagnostics command reports installed browser metadata and default-browser status. It does not print domain rules or incoming URLs.

### Trust boundaries

The operating system supplies registered browser applications. Installing an application that claims HTTP, HTTPS, and HTML support can add it to that registry. Browser Switch does not certify those applications or their extensions. The selected browser receives the original URL, including its path, query, fragment, and any credentials already present.

Browser Switch does not inspect redirects, resolve DNS, filter website content, or provide phishing or malware protection. A rule applies to the original link's hostname; later redirects are handled by the selected browser. Configuring another URL router to send links back to Browser Switch can create an indirect routing loop and should be avoided.

Local ad hoc signatures protect bundle integrity after signing but do not establish a publisher identity or notarization. Public distribution should use Developer ID signing and notarization. Keep macOS and installed browsers updated.

## Reporting a vulnerability

Use this repository's GitHub private vulnerability reporting feature if it is available. Do not post exploitable details, private browsing URLs, credentials, or personal domain lists in a public issue. For ordinary bugs, include the macOS version, Browser Switch version, and reproduction steps with placeholder URLs.
