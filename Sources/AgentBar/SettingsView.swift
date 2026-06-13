import AgentBarCore
import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AgentBarModel

    @State private var refreshIntervalSeconds = "300"
    @State private var monthlyTokenBudget = ""
    @State private var monthlyCostBudget = ""
    @State private var autosaveTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                compactSection("Menu Bar") {
                    HStack(alignment: .top, spacing: 8) {
                        menuBarLabels
                        menuBarControls
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    compactSection("Updates") {
                        VStack(alignment: .leading, spacing: 8) {
                            settingRow("Refresh", labelWidth: 58) {
                                HStack(spacing: 6) {
                                    TextField("", text: $refreshIntervalSeconds)
                                        .textFieldStyle(.roundedBorder)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 64)

                                    Stepper("", value: refreshBinding, in: 30...(24 * 60 * 60), step: 30)
                                        .labelsHidden()

                                    Text("sec")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            settingRow("Login", labelWidth: 58) {
                                Toggle("", isOn: launchAtLoginBinding)
                                    .labelsHidden()
                                    .toggleStyle(.switch)
                            }
                        }
                    }

                    compactSection("Budgets") {
                        VStack(alignment: .leading, spacing: 8) {
                            settingRow("Tokens", labelWidth: 58) {
                                HStack(spacing: 6) {
                                    TextField("", text: $monthlyTokenBudget)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 98)
                                    Text("tokens")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            settingRow("Cost", labelWidth: 58) {
                                HStack(spacing: 6) {
                                    TextField("", text: $monthlyCostBudget)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 98)
                                    Text("USD")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                compactSection("Maintenance") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Button {
                                saveSettingsFromFields()
                            } label: {
                                Label("Save", systemImage: "square.and.arrow.down")
                            }
                            .keyboardShortcut("s", modifiers: [.command])

                            Button {
                                Task { await model.refresh(force: true) }
                            } label: {
                                Label("Scan", systemImage: "arrow.clockwise")
                            }
                            .disabled(model.isRefreshing)
                        }

                        HStack(spacing: 10) {
                            Button {
                                model.recalculateCosts()
                            } label: {
                                Label("Recalculate", systemImage: "dollarsign.arrow.circlepath")
                            }

                            Button {
                                model.resetPricing()
                            } label: {
                                Label("Reset pricing", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }

                footer
            }
            .padding(16)
        }
        .controlSize(.small)
        .onAppear(perform: loadFields)
        .onDisappear {
            autosaveTask?.cancel()
            saveSettingsFromFields()
        }
        .onChange(of: refreshIntervalSeconds) {
            scheduleSettingsAutosave()
        }
        .onChange(of: monthlyTokenBudget) {
            scheduleSettingsAutosave()
        }
        .onChange(of: monthlyCostBudget) {
            scheduleSettingsAutosave()
        }
    }

    private var menuBarModeBinding: Binding<CodexMenuBarMode> {
        Binding(
            get: { model.settings.codexMenuBarMode },
            set: { mode in
                model.settings.codexMenuBarMode = mode
                model.persistSettings()
            }
        )
    }

    private var menuBarMetricBinding: Binding<MenuBarMetric> {
        Binding(
            get: { model.settings.menuBarMetric },
            set: { metric in
                model.settings.menuBarMetric = metric
                model.persistSettings()
            }
        )
    }

    private var refreshBinding: Binding<Int> {
        Binding(
            get: { Int(refreshIntervalSeconds) ?? model.settings.codexRefreshIntervalSeconds },
            set: { refreshIntervalSeconds = String($0) }
        )
    }

    private var databaseLocationText: String {
        "~/Library/Application Support/AgentBar/agentbar.db"
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { model.settings.launchAtLogin },
            set: { model.setLaunchAtLogin($0) }
        )
    }

    private var showQuotaLabelsBinding: Binding<Bool> {
        Binding(
            get: { model.settings.codexMenuBarShowsQuotaLabels },
            set: { showsLabels in
                model.settings.codexMenuBarShowsQuotaLabels = showsLabels
                model.persistSettings()
            }
        )
    }

    private var menuBarLabels: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuBarLabel("Display")

            if model.settings.codexMenuBarMode == .iconOnly {
                menuBarLabel("Usage metric")
            }

            if model.settings.codexMenuBarMode == .plan {
                menuBarLabel("Labels")
                ForEach(CodexMenuBarQuotaItem.supportedKeys) { key in
                    menuBarLabel("\(key.label) quota")
                }
            }
        }
        .frame(width: 76, alignment: .leading)
    }

    private var menuBarControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            menuBarControlRow {
                Picker(selection: menuBarModeBinding) {
                    ForEach(CodexMenuBarMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(width: 260, alignment: .leading)
            }

            if model.settings.codexMenuBarMode == .iconOnly {
                menuBarControlRow {
                    Picker(selection: menuBarMetricBinding) {
                        ForEach(MenuBarMetric.allCases) { metric in
                            Text(metric.title).tag(metric)
                        }
                    } label: {
                        EmptyView()
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260, alignment: .leading)
                }
            }

            if model.settings.codexMenuBarMode == .plan {
                menuBarControlRow {
                    Toggle(isOn: showQuotaLabelsBinding) {
                        EmptyView()
                    }
                        .toggleStyle(.checkbox)
                        .fixedSize()
                    Text("Show 5h / 7d")
                }

                ForEach(CodexMenuBarQuotaItem.supportedKeys) { key in
                    menuBarControlRow {
                        Toggle(isOn: enabledBinding(for: key)) {
                            EmptyView()
                        }
                            .toggleStyle(.checkbox)
                            .fixedSize()

                        Picker(selection: basisBinding(for: key)) {
                            ForEach(CodexQuotaPercentBasis.allCases) { basis in
                                Text(basis.title).tag(basis)
                            }
                        } label: {
                            EmptyView()
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 154, alignment: .leading)
                        .disabled(!quotaItem(for: key).isEnabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(databaseLocationText)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let error = model.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else {
                Text(model.statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }

    private func compactSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.5)
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func settingRow<Content: View>(
        _ title: String,
        labelWidth: CGFloat = 96,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: labelWidth, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func menuBarLabel(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(height: 26, alignment: .center)
    }

    private func menuBarControlRow<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            content()
            Spacer(minLength: 0)
        }
        .frame(height: 26, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func quotaItem(for key: CodexQuotaKey) -> CodexMenuBarQuotaItem {
        model.settings.codexMenuBarQuotaItems.first { $0.key == key } ?? CodexMenuBarQuotaItem(key: key)
    }

    private func enabledBinding(for key: CodexQuotaKey) -> Binding<Bool> {
        Binding(
            get: { quotaItem(for: key).isEnabled },
            set: { isEnabled in
                updateQuotaItem(for: key) { item in
                    item.isEnabled = isEnabled
                }
            }
        )
    }

    private func basisBinding(for key: CodexQuotaKey) -> Binding<CodexQuotaPercentBasis> {
        Binding(
            get: { quotaItem(for: key).basis },
            set: { basis in
                updateQuotaItem(for: key) { item in
                    item.basis = basis
                }
            }
        )
    }

    private func loadFields() {
        refreshIntervalSeconds = String(model.settings.codexRefreshIntervalSeconds)
        monthlyTokenBudget = model.settings.monthlyTokenBudget.map(String.init) ?? ""
        monthlyCostBudget = model.settings.monthlyCostBudgetUSD.map { String(format: "%.2f", $0) } ?? ""
    }

    private func saveSettingsFromFields() {
        autosaveTask?.cancel()
        saveSettingsFromFields(reloadFields: true)
    }

    private func saveSettingsFromFields(reloadFields: Bool) {
        let refreshText = refreshIntervalSeconds.trimmingCharacters(in: .whitespacesAndNewlines)
        let tokenText = monthlyTokenBudget.trimmingCharacters(in: .whitespacesAndNewlines)
        let costText = monthlyCostBudget.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let refreshInterval = Int(refreshText),
              tokenText.isEmpty || Int(tokenText) != nil,
              costText.isEmpty || Double(costText) != nil else {
            model.statusMessage = "Invalid settings"
            return
        }

        model.settings.codexRefreshIntervalSeconds = refreshInterval
        model.settings.monthlyTokenBudget = tokenText.isEmpty ? nil : Int(tokenText)
        model.settings.monthlyCostBudgetUSD = costText.isEmpty ? nil : Double(costText)
        model.persistSettings()
        if reloadFields {
            loadFields()
        }
    }

    private func scheduleSettingsAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                saveSettingsFromFields(reloadFields: false)
            }
        }
    }

    private func updateQuotaItem(
        for key: CodexQuotaKey,
        update: (inout CodexMenuBarQuotaItem) -> Void
    ) {
        var items = CodexMenuBarQuotaItem.normalized(model.settings.codexMenuBarQuotaItems)
        guard let index = items.firstIndex(where: { $0.key == key }) else { return }
        update(&items[index])
        model.settings.codexMenuBarQuotaItems = items
        model.persistSettings()
    }
}
