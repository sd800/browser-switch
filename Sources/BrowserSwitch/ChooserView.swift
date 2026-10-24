import AppKit
import SwiftUI
#if SWIFT_PACKAGE
import BrowserSwitchCore
#endif

@MainActor
final class ChooserState: ObservableObject {
    @Published var urls: [URL] = []
    @Published var isOpening = false
    @Published var failure: String?
}

struct ChooserView: View {
    static let width: CGFloat = 436
    @ObservedObject var model: AppModel
    @ObservedObject var state: ChooserState
    let choose: (InstalledBrowser) -> Void
    let cancel: () -> Void
    let openSettings: () -> Void
    var contentDidChange: () -> Void = {}
    var choices: [InstalledBrowser] {
        model.visibleBrowsers.isEmpty ? model.defaultBrowser.map { [$0] } ?? [] : model.visibleBrowsers
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(AppStyle.accent)
                    .frame(width: 46, height: 46)
                    .background(AppStyle.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Open link with…").font(.system(size: 23, weight: .semibold))
                    Text(state.urls.first?.host ?? "Choose a browser")
                        .foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            if let url = state.urls.first {
                Text(url.absoluteString)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                    .lineLimit(2).truncationMode(.middle).textSelection(.enabled)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
                    .help(url.absoluteString)
            }
            ScrollView {
                VStack(spacing: 7) {
                    ForEach(Array(choices.enumerated()), id: \.element.id) { index, browser in
                        Button { choose(browser) } label: {
                            HStack(spacing: 13) {
                                Image(nsImage: browser.icon).resizable().frame(width: 38, height: 38)
                                    .accessibilityHidden(true)
                                Text(browser.name).fontWeight(.medium)
                                Spacer()
                                if model.defaultBrowser?.id == browser.id {
                                    Text("Default").font(.system(size: 12)).foregroundStyle(.secondary)
                                }
                                if let key = BrowserPickerShortcuts.key(at: index) {
                                    Text(key).font(.system(size: 12, design: .monospaced)).foregroundStyle(.tertiary)
                                }
                                Image(systemName: "arrow.up.right").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                            .contentShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(BrowserChoiceStyle())
                        .modifier(BrowserShortcut(index: index))
                        .disabled(state.isOpening)
                        .accessibilityLabel("Open in \(browser.name)")
                    }
                }
                .padding(2)
            }
            .frame(height: CGFloat(min(choices.count, 5)) * 66 + 4)
            if choices.isEmpty {
                Text("No browsers are available. Install a web browser, then refresh in Settings.")
                    .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let failure = state.failure {
                Label(failure, systemImage: "exclamationmark.circle").font(.system(size: 13)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            HStack {
                Button(action: openSettings) { Image(systemName: "gearshape") }
                    .buttonStyle(.borderless).help("Settings… (⌘,)").accessibilityLabel("Settings")
                if state.urls.count > 1 {
                    Text("\(state.urls.count) links waiting").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                if state.isOpening { ProgressView().controlSize(.small) }
                Button("Cancel", action: cancel).keyboardShortcut(.cancelAction).disabled(state.isOpening)
            }
        }
        .padding(26).frame(width: Self.width)
        .font(.system(size: 15)).tint(AppStyle.accent)
        .onChange(of: choices.map(\.id)) { _, _ in contentDidChange() }
        .onChange(of: state.urls.first) { _, _ in contentDidChange() }
        .onChange(of: state.failure) { _, _ in contentDidChange() }
    }
}

@MainActor
final class BrowserPickerWindow: NSWindow {
    private let hosting: NSHostingController<ChooserView>

    init(rootView: ChooserView) {
        hosting = NSHostingController(rootView: rootView)
        // Resolve content size explicitly before positioning, rather than letting
        // SwiftUI resize an already-centered window on a later layout pass.
        hosting.sizingOptions = []
        super.init(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        contentViewController = hosting
        title = "Open Link — Browser Switch"
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isReleasedWhenClosed = false
        isRestorable = false
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    }

    func prepareForPresentation() {
        let wasVisible = isVisible
        resizeToFitContent()
        if !wasVisible { center() }
    }

    func refreshContentSize() {
        if isVisible { resizeToFitContent() }
    }

    private func resizeToFitContent() {
        let topLeft = NSPoint(x: frame.minX, y: frame.maxY)
        hosting.view.needsLayout = true
        hosting.view.layoutSubtreeIfNeeded()
        let size = hosting.sizeThatFits(in: NSSize(width: ChooserView.width, height: CGFloat.greatestFiniteMagnitude))
        setContentSize(size)
        setFrameTopLeftPoint(topLeft)
        contentView?.layoutSubtreeIfNeeded()
    }
}

private struct BrowserShortcut: ViewModifier {
    let index: Int
    @ViewBuilder func body(content: Content) -> some View {
        if let key = BrowserPickerShortcuts.key(at: index) {
            content.keyboardShortcut(KeyEquivalent(Character(key)), modifiers: [])
        } else { content }
    }
}

private struct BrowserChoiceStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? AppStyle.accent.opacity(0.17) : Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(colorScheme == .dark ? 0.10 : 0.06)))
    }
}
