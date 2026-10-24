# Browser Switch

The right browser for every link.

Browser Switch is a small native macOS utility that acts as your default web browser. Everyday links open in your preferred browser. Links to domains you choose bring up a browser picker instead.

## Features

- **Choose by domain.** Add domains to an initially empty list. Include subdomains by default, or match an exact hostname.
- **Keep everyday browsing simple.** Choose a default browser for other links. If it is unavailable, Browser Switch tries Google Chrome, then Safari, then another installed browser.
- **Use your installed browsers.** Discover HTTP and HTTPS handlers through macOS Launch Services, excluding Browser Switch itself. Hide browsers from the picker and change their order. The initial order is Google Chrome, Firefox, Safari, Microsoft Edge, then other browsers alphabetically.
- **Make a fresh choice.** Browser selections apply to the current link. Domain choices are never remembered automatically.
- **Stay out of the way.** Independently enable the menu bar icon and persistent Dock icon. With both off, reopen the app from Spotlight, Launchpad, or Applications.
- **Feel at home on macOS.** Native controls, SF Symbols, the system accent color, system fonts with a 15 pt body size, automatic light and dark appearance, and standard keyboard shortcuts. The interface is in English (United States).
- **Keep links private.** No analytics, browsing history, embedded browser, or outbound network permission. Settings stay on the Mac.

## Requirements

macOS 14 Sonoma or later. Universal builds support Apple silicon and Intel Macs.

## Build and install

Install Xcode 15.3 or later, then run:

```sh
git clone https://github.com/sd800/browser-switch.git
cd browser-switch
./Scripts/build.sh
```

The build produces `dist/Browser Switch.app` and a versioned ZIP archive. Copy the app to `/Applications` or `~/Applications`, then open it. Keep one installed copy so macOS does not register multiple builds of the same app.

The script signs local builds with an ad hoc signature, App Sandbox, and Hardened Runtime. These builds are intended for local use and are not notarized. A Developer ID distribution requires an appropriate signing identity and Apple notarization; setting `SIGNING_IDENTITY` signs the build with that identity but does not notarize it.

For development, open `BrowserSwitch.xcodeproj`, choose a signing team if needed, and run the **BrowserSwitch** scheme. The project has no third-party dependencies.

## Set up routing

1. Open **Browser Switch → Settings…** and click **Set as Default**, then accept the macOS confirmation. It can also be selected in **System Settings → Desktop & Dock → Default web browser**.
2. In **General**, select the default browser for everyday links. Google Chrome is preferred on a fresh installation, with Safari as the next choice.
3. In **Domains**, add a hostname such as `example.com` or paste a full web address. Only the hostname is stored. Subdomains are included unless the switch is turned off.
4. In **Browsers**, hide unwanted picker options and use the arrow buttons to change their order.

For example, adding `example.com` with subdomains enabled asks where to open both `example.com` and `docs.example.com`. It does not match `anotherexample.com` or `example.com.other.org`.

The picker shows the destination hostname and URL. Select a browser to open that link, or cancel to discard it. Multiple matching links wait in a bounded queue and are presented one at a time. If every browser is hidden, the picker offers the default browser so links remain usable.

Hiding a browser affects the picker only. It can still be the default browser for other links. If a preferred browser is removed and later reinstalled, its saved preferences remain available. Use **Refresh** if an installation change has not appeared yet.

Browser discovery uses the same macOS application registry that supplies system browser choices, requiring support for HTTP, HTTPS, and HTML documents. Stale system registrations and duplicate app installations can affect what macOS reports.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `⌘,` | Open settings |
| `⌘Q` | Quit Browser Switch |
| `⌘W` | Close the current window |
| `⌘H` | Hide Browser Switch |
| `⌘N` | Add a domain while the Domains page is open |
| `1`–`8` | Choose one of the first eight browsers in the picker |
| `qwertyuiopasdfghjklzxcvbnm` | Choose subsequent browsers in keyboard order |
| `Esc` | Cancel the current picker link or close the add-domain sheet |

The `9` key is reserved and does not select a browser. Browsers after the first 34 remain available by clicking.

Closing settings keeps routing available. Quitting stops the running process; macOS launches it again when a link is sent to Browser Switch as the default browser. **Open at login** is optional.

## Privacy and security

Browser Switch stores domain rules, browser preferences, and appearance-of-entry-point settings locally using macOS preferences. It does not store incoming links or selections, fetch favicons, inspect browser profiles, or resolve destinations over the network. A browser you select receives the original URL and applies its own privacy settings.

See [SECURITY.md](SECURITY.md) for the security model and reporting guidance.

## Tests

```sh
./Scripts/test.sh
```

The test suite covers domain normalization, internationalized hostnames, matching boundaries, protocol and size restrictions, browser fallback, browser ordering, and persistence. For source folders managed by a file provider, place test products outside the synced folder:

```sh
BROWSER_SWITCH_TEST_BUILD_DIR=/tmp/browser-switch-tests ./Scripts/test.sh
```

After building, inspect browser discovery without opening a website:

```sh
"dist/Browser Switch.app/Contents/MacOS/Browser Switch" --diagnostics
```

## Versioning

Releases use `YY.MDD.NUM`: a two-digit year, the unpadded month followed by the two-digit day, and the release sequence within that month. For example, `26.1024.1` is the first release in October 2026, dated October 24. The sequence resets at the start of each month. The separate build number in `BUILD_NUMBER` increases across all releases and never resets; About displays it as `Version 26.1024.1 (1)`. Keep `VERSION`, `BUILD_NUMBER`, and the Xcode project version settings in sync when preparing a release. See [CHANGELOG.md](CHANGELOG.md).

© 2026 Songming.org
