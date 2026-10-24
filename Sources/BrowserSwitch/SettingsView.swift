import AppKit
import SwiftUI
import ServiceManagement
#if SWIFT_PACKAGE
import BrowserSwitchCore
#endif

enum SettingsPage: String, CaseIterable, Identifiable {
    case general = "General", domains = "Domains", browsers = "Browsers"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .general: "gearshape"
        case .domains: "globe"
        case .browsers: "square.grid.2x2"
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var selection: SettingsPage = .general

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(SettingsPage.allCases, selection: $selection) { page in
                    Label(page.rawValue, systemImage: page.symbol)
                        .padding(.vertical, 5)
                        .tag(page)
                }
                .listStyle(.sidebar)
                HStack(spacing: 7) {
                    Image(systemName: "arrow.triangle.branch").foregroundStyle(AppStyle.accent)
                    Text("Browser Switch").font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .padding(16)
            }
            .frame(width: 182)
            .background(.bar)
            Divider()
            Group {
                switch selection {
                case .general: GeneralView(model: model)
                case .domains: DomainsView(model: model)
                case .browsers: BrowsersView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .font(.system(size: 15))
        .tint(AppStyle.accent)
        .frame(minWidth: 760, maxWidth: .infinity, minHeight: 560, maxHeight: .infinity)
        .alert("Something needs your attention", isPresented: Binding(
            get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

private struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 25, weight: .bold))
            Text(subtitle).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct GeneralView: View {
    @ObservedObject var model: AppModel
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            PageHeader(title: "A better home for every link.", subtitle: "Your everyday browser, with a choice when it matters.")
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

            Section {
                HStack(alignment: .center, spacing: 13) {
                    Image(systemName: model.isSystemDefault ? "checkmark.circle.fill" : "arrow.triangle.branch")
                        .font(.system(size: 25, weight: .medium)).foregroundStyle(AppStyle.accent)
                        .frame(width: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(model.isSystemDefault ? "Browser Switch is your default" : "Make room for a little choice")
                            .fontWeight(.medium)
                        Text(model.isSystemDefault ? "Web links are ready to go where you want." : "Set Browser Switch as your default web browser.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 10)
                    if !model.isSystemDefault {
                        Button(model.isSettingDefault ? "Setting…" : "Set as Default") { model.makeSystemDefault() }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.isSettingDefault)
                    }
                }
                .padding(.vertical, 7)
            }

            Section {
                Picker("Default browser", selection: Binding(
                    get: { model.defaultBrowser?.id ?? "" },
                    set: { model.settings.defaultBrowserID = $0 }
                )) {
                    if model.browsers.isEmpty { Text("No browsers found").tag("") }
                    ForEach(model.orderedBrowsers) { browser in
                        Text(browser.name).tag(browser.id)
                    }
                }
                .disabled(model.browsers.isEmpty)
                if !model.browsers.contains(where: { $0.id == model.settings.defaultBrowserID }), !model.browsers.isEmpty {
                    Label("Your selected browser is unavailable. Using \(model.defaultBrowser?.name ?? "another browser") until it returns.", systemImage: "info.circle")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                }
            } header: { Text("Everyday links") } footer: {
                Text("Links outside your domain list open here automatically. Chrome is preferred, followed by Safari, when your selected browser is unavailable.")
            }

            Section {
                Toggle("Show in menu bar", isOn: $model.settings.showsMenuBarIcon)
                Toggle("Keep in Dock", isOn: $model.settings.keepsDockIcon)
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                        } catch {
                            model.errorMessage = "Could not update Open at Login. \(error.localizedDescription)"
                        }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
            } header: { Text("At your fingertips") } footer: {
                Text("With both icons off, open Browser Switch from Spotlight or Applications to return to settings. Links still work when the app is closed.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onAppear { model.refreshBrowsers(); launchAtLogin = SMAppService.mainApp.status == .enabled }
    }
}

private struct DomainsView: View {
    @ObservedObject var model: AppModel
    @State private var showingAdd = false
    @State private var search = ""
    var filteredRules: [DomainRule] {
        model.settings.rules.filter { search.isEmpty || $0.domain.localizedCaseInsensitiveContains(search) }
            .sorted { $0.domain < $1.domain }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Some links deserve a choice.", subtitle: "Choose a browser each time you open one of these domains.")
            HStack {
                TextField("Search domains", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Search domains")
                Button { showingAdd = true } label: { Label("Add Domain", systemImage: "plus") }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("n", modifiers: .command)
            }
            if model.settings.rules.isEmpty {
                Spacer()
                VStack(spacing: 13) {
                    Image(systemName: "globe").font(.system(size: 42, weight: .light)).foregroundStyle(AppStyle.accent)
                    Text("Your choice starts here").font(.system(size: 19, weight: .semibold))
                    Text("Add a domain like example.com. All other links\nwill keep using your default browser.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Add Your First Domain") { showingAdd = true }.padding(.top, 3)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            } else {
                List {
                    ForEach(filteredRules) { rule in
                        HStack(spacing: 12) {
                            Image(systemName: "globe").foregroundStyle(AppStyle.accent).frame(width: 22)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.domain).fontWeight(.medium).textSelection(.enabled)
                                Text(rule.includesSubdomains ? "Includes subdomains" : "Exact domain only")
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Toggle("Include subdomains", isOn: Binding(
                                get: { rule.includesSubdomains },
                                set: { value in
                                    if let index = model.settings.rules.firstIndex(where: { $0.id == rule.id }) {
                                        model.settings.rules[index].includesSubdomains = value
                                    }
                                }
                            ))
                            .toggleStyle(.switch).labelsHidden()
                            .help("Include subdomains of \(rule.domain)")
                            Button(role: .destructive) { model.settings.rules.removeAll { $0.id == rule.id } } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless).foregroundStyle(.secondary)
                            .help("Remove \(rule.domain)").accessibilityLabel("Remove \(rule.domain)")
                        }
                        .accessibilityElement(children: .contain)
                        .padding(.vertical, 8)
                    }
                }
                .listStyle(.inset)
                .overlay {
                    if filteredRules.isEmpty { Text("No matching domains").foregroundStyle(.secondary) }
                }
                Text("Subdomains match on domain boundaries: example.com includes docs.example.com, but never anotherexample.com.")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .sheet(isPresented: $showingAdd) { AddDomainView(model: model) }
    }
}

private struct AddDomainView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var domain = ""
    @State private var includesSubdomains = true
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a domain").font(.system(size: 21, weight: .semibold))
                Text("You’ll choose a browser each time a link matches.").foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                TextField("example.com", text: $domain).textFieldStyle(.roundedBorder)
                    .focused($focused).accessibilityLabel("Domain")
                    .onChange(of: domain) { _, _ in error = nil }
                Text(error ?? "Paste a full web address or enter a domain.")
                    .font(.system(size: 13)).foregroundStyle(error == nil ? Color.secondary : Color.red)
            }
            Toggle("Include subdomains", isOn: $includesSubdomains)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Domain") {
                    error = model.addDomain(domain, includesSubdomains: includesSubdomains)
                    if error == nil { dismiss() }
                }
                .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                .disabled(domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .font(.system(size: 15)).padding(26).frame(width: 430)
        .onAppear { focused = true }
    }
}

private struct BrowsersView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Your browsers. Your order.", subtitle: "Choose what appears in the picker and move your favorites up.")
            HStack {
                Text("\(model.browsers.count) installed browsers").foregroundStyle(.secondary)
                Spacer()
                Button { model.refreshBrowsers() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    .help("Refresh installed browsers")
            }
            List {
                ForEach(Array(model.orderedBrowsers.enumerated()), id: \.element.id) { index, browser in
                    HStack(spacing: 13) {
                        Image(nsImage: browser.icon).resizable().frame(width: 36, height: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(browser.name).fontWeight(.medium)
                            if model.defaultBrowser?.id == browser.id {
                                Text("Default browser").font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        HStack(spacing: 9) {
                            Button { model.moveBrowser(browser, by: -1) } label: { Image(systemName: "chevron.up") }
                                .disabled(index == 0).help("Move \(browser.name) up")
                                .accessibilityLabel("Move \(browser.name) up")
                            Button { model.moveBrowser(browser, by: 1) } label: { Image(systemName: "chevron.down") }
                                .disabled(index == model.orderedBrowsers.count - 1).help("Move \(browser.name) down")
                                .accessibilityLabel("Move \(browser.name) down")
                        }
                        .buttonStyle(.borderless)
                        Toggle("Show \(browser.name)", isOn: Binding(
                            get: { model.isVisible(browser) }, set: { model.setVisibility($0, for: browser) }
                        ))
                        .toggleStyle(.switch).labelsHidden()
                    }
                    .accessibilityElement(children: .contain)
                    .padding(.vertical, 9)
                }
            }
            .listStyle(.inset)
            .overlay {
                if model.browsers.isEmpty { Text("No web browsers found. Install a browser, then refresh.").foregroundStyle(.secondary).padding() }
            }
            if model.visibleBrowsers.isEmpty, !model.browsers.isEmpty {
                Label("All browsers are hidden. The picker will offer your default browser so links can still open.", systemImage: "info.circle")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Text("Browsers are discovered from the macOS registry for HTTP and HTTPS links. Hiding a browser only removes it from the picker; it can still be your default.")
                .font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .padding(28)
        .onAppear { model.refreshBrowsers() }
    }
}
