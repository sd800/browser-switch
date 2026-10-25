# Browser Switch

The right browser for every link.

Browser Switch is a small native macOS utility that acts as your default web browser. Everyday links open in your preferred browser. Links to domains you choose bring up a browser picker instead.

## Features

- **Choose by domain.** Enter domains directly into an initially empty list, including subdomains by default. Use Command-N to add an exact-hostname rule instead.
- **Keep everyday browsing simple.** Choose a default browser for other links. If it is unavailable, Browser Switch tries Google Chrome, then Safari, then another installed browser.
- **Use your installed browsers.** Discover HTTP and HTTPS handlers through macOS Launch Services, excluding Browser Switch itself. Hide browsers from the picker and change their order. The initial order is Google Chrome, Firefox, Safari, Microsoft Edge, then other browsers alphabetically.
- **Make a fresh choice.** Browser selections apply to the current link. Domain choices are never remembered automatically.
- **Stay out of the way.** Independently enable the menu bar icon and persistent Dock icon. With both off, reopen the app from Spotlight, Launchpad, or Applications.
- **Feel at home on macOS.** Native controls, the system accent color, system fonts, automatic light and dark appearance, and standard keyboard shortcuts. The interface is in English (United States).
- **Keep links private.** No analytics, browsing history, embedded browser, or outbound network permission. Settings stay on the Mac.

## Requirements

macOS 14 Sonoma or later. Universal builds support Apple silicon and Intel Macs.

## Download and install

Download the universal macOS app from [GitHub Releases](https://github.com/sd800/browser-switch/releases/latest).

1. Unzip the download and move **Browser Switch.app** to Applications.
2. Open the app. If macOS blocks it, open **System Settings → Privacy & Security**, scroll to **Security**, and click **Open Anyway** beside Browser Switch. Confirm **Open** when prompted. The button appears after you have tried opening the app.
3. Follow the routing setup below. Keep only one installed copy so macOS does not register multiple builds of the same app.

The current download is ad hoc signed with App Sandbox and Hardened Runtime. It is not Developer ID signed or notarized by Apple. Each release includes a SHA-256 checksum file.

## Build from source

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
3. In **Domains**, enter a hostname such as `example.com` or paste a full web address into the field at the top. Press Return or click **Add Domain** to add it immediately, including subdomains. To add an exact-hostname rule, press **Command-N** and turn off **Include subdomains** in the add-domain window. Only the hostname is stored.
4. In **Browsers**, hide unwanted picker options and use the arrow buttons to change their order.

For example, adding `example.com` with subdomains enabled asks where to open both `example.com` and `docs.example.com`. It does not match `anotherexample.com` or `example.com.other.org`. Each rule shows whether it includes subdomains or matches the exact domain only.

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
| `⌘N` | Open the add-domain window with subdomain options while the Domains page is open |
| `1`–`8` | Choose one of the first eight browsers in the picker |
| `qwertyuiopasdfghjklzxcvbnm` | Choose subsequent browsers in keyboard order |
| `Esc` | Cancel the current picker link or close the add-domain window |

Browsers without an assigned shortcut remain available by clicking.

Closing settings keeps routing available. Quitting stops the running process; macOS launches it again when a link is sent to Browser Switch as the default browser. **Open at login** is optional.

## Privacy and security

Browser Switch stores domain rules, browser preferences, and appearance-of-entry-point settings locally using macOS preferences. It does not store incoming links or selections, fetch favicons, inspect browser profiles, or resolve destinations over the network. A browser you select receives the original URL and applies its own privacy settings.

See [SECURITY.md](SECURITY.md) for the security model and reporting guidance.

## Tests

```sh
./Scripts/test.sh
```

The test suite covers domain normalization, internationalized hostnames, matching boundaries, protocol and size restrictions, browser fallback, browser ordering, persistence, and browser picker placement. Window placement checks require a graphical macOS session.

After building, inspect browser discovery without opening a website:

```sh
"dist/Browser Switch.app/Contents/MacOS/Browser Switch" --diagnostics
```

See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Website

The product website lives in [`web/`](web/) and is published at [browser-switch.songming.org](https://browser-switch.songming.org). Double-click `web/index.html` to open it locally, including its interactive routing preview. See the [website README](web/README.md) for deployment details.
