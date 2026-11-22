import SwiftUI

@main
struct SpendKitNativeApp: App {
    @State private var workspace = Workspace()
    @AppStorage("darkTheme") private var darkTheme = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("biometricUnlock") private var biometricUnlock = false

    var body: some Scene {
        WindowGroup {
            Group {
                if let account = workspace.account {
                    TabView {
                        NavigationStack { Overview(account: account, workspace: workspace) }
                            .tabItem { Label("Home", systemImage: "house") }
                        NavigationStack { Activity(workspace: workspace) }
                            .tabItem { Label("Activity", systemImage: "list.bullet.rectangle") }
                        NavigationStack { CardScreen(account: account, workspace: workspace) }
                            .tabItem { Label("Card", systemImage: "creditcard") }
                        NavigationStack {
                            Settings(
                                darkTheme: $darkTheme, highContrast: $highContrast,
                                biometricUnlock: $biometricUnlock, workspace: workspace
                            )
                        }
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                    }
                    .task { await workspace.refreshTransactions() }
                } else {
                    SignIn(workspace: workspace, biometricUnlock: biometricUnlock)
                }
            }
            .tint(highContrast ? Color.primary : Color(red: 0.08, green: 0.45, blue: 0.32))
            .preferredColorScheme(darkTheme ? .dark : nil)
        }
    }
}

struct SignIn: View {
    let workspace: Workspace
    let biometricUnlock: Bool
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("SpendKit").font(.largeTitle.bold()).accessibilityAddTraits(.isHeader)
                Text("Business spending, all in one place.")
                Text("Demo access code: 2048").foregroundStyle(.secondary)
                SecureField("Access code", text: $code)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { if !busy && !code.isEmpty { signIn() } }
                Button("Sign in", action: signIn)
                    .buttonStyle(.borderedProminent)
                    .disabled(busy || code.isEmpty)
                if biometricUnlock && workspace.canUnlock {
                    Button("Unlock with biometrics") {
                        run { try await workspace.unlock() }
                    }.disabled(busy)
                }
                if busy { ProgressView("Signing in") }
                if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
            }
            .padding(28)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity)
        }
    }

    private func signIn() {
        let enteredCode = code.trimmingCharacters(in: .whitespaces)
        run { try await workspace.signIn(code: enteredCode) }
    }

    private func run(_ action: @escaping () async throws -> Void) {
        busy = true
        error = nil
        Task {
            defer { busy = false }
            do { try await action() }
            catch { self.error = error.localizedDescription }
        }
    }
}

struct CreditSummary: View {
    let account: BankAccount

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Business credit •• 4821", systemImage: "creditcard")
                .font(.headline)
            Text(account.frozen ? "Frozen" : "Active")
                .font(.subheadline.bold())
            Text("Available credit")
            Text(Currency.format(account.availablePence))
                .font(.largeTitle.bold().monospacedDigit())
                .accessibilityLabel("Available credit")
                .accessibilityValue(Currency.format(account.availablePence))
            ProgressView(
                value: Double(account.limitPence - account.availablePence),
                total: Double(account.limitPence)
            ) { Text("Credit used") }
                .tint(.white)
            Text("\(Currency.format(account.limitPence - account.availablePence)) used of \(Currency.format(account.limitPence))")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .foregroundStyle(.white)
        .background(
            LinearGradient(
                colors: [Color(red: 0.06, green: 0.26, blue: 0.20), Color(red: 0.06, green: 0.41, blue: 0.29)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
    }
}

private enum CalendarLabels {
    static let format = Date.ISO8601FormatStyle().year().month().day()
    static let utc = TimeZone(secondsFromGMT: 0)!

    static func key(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
    }

    static func monthName(_ month: String, short: Bool = false) -> String {
        guard let number = Int(month.suffix(2)), (1...12).contains(number) else { return month }
        let calendar = Calendar(identifier: .gregorian)
        let name = (short ? calendar.shortMonthSymbols : calendar.monthSymbols)[number - 1]
        return short ? name : "\(name) \(month.prefix(4))"
    }

    static func months(ending today: String) -> [String] {
        guard let end = try? format.parse(today) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let start = calendar.dateInterval(of: .month, for: end)?.start ?? end
        return (0..<6).reversed().compactMap { offset in
            calendar.date(byAdding: .month, value: -offset, to: start)
                .map { String($0.formatted(format).prefix(7)) }
        }
    }
}

struct Overview: View {
    let account: BankAccount
    let workspace: Workspace
    @State private var selectedMonth: String?

    var body: some View {
        let months = CalendarLabels.months(ending: account.today)
        let current = selectedMonth ?? months.last ?? ""
        let monthRows = workspace.transactions.filter { $0.date.hasPrefix(current) }
        let monthTotals = months.map { month in
            workspace.transactions.filter { $0.date.hasPrefix(month) }.reduce(0) { $0 + $1.pence }
        }
        let maximum = max(1, monthTotals.max() ?? 0)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Studio North Ltd").font(.headline).foregroundStyle(.secondary)
                CreditSummary(account: account)
                NavigationLink {
                    Simulator(workspace: workspace, account: account)
                } label: {
                    Label("Test a card payment", systemImage: "creditcard.and.123")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                GroupBox("Monthly spending") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !current.isEmpty { Text(CalendarLabels.monthName(current)).foregroundStyle(.secondary) }
                        Text(Currency.format(monthRows.reduce(0) { $0 + $1.pence }))
                            .font(.title.bold().monospacedDigit())
                        if !months.isEmpty {
                            HStack(alignment: .bottom, spacing: 8) {
                                ForEach(Array(months.indices), id: \.self) { index in
                                    let month = months[index]
                                    Button {
                                        selectedMonth = month
                                    } label: {
                                        VStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 5)
                                                .fill(month == current ? Color.accentColor : Color.secondary.opacity(0.25))
                                                .frame(
                                                    width: 20,
                                                    height: 4 + 68 * Double(monthTotals[index]) / Double(maximum)
                                                )
                                                .frame(height: 72, alignment: .bottom)
                                            Text(CalendarLabels.monthName(month, short: true))
                                                .font(.caption.monospacedDigit())
                                        }
                                        .frame(maxWidth: .infinity)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(CalendarLabels.monthName(month)), \(Currency.format(monthTotals[index]))")
                                    .accessibilityAddTraits(month == current ? .isSelected : [])
                                }
                            }
                        }
                        ForEach(SpendCategory.allCases) { category in
                            let total = monthRows.filter { $0.category == category }.reduce(0) { $0 + $1.pence }
                            LabeledContent(category.title, value: Currency.format(total))
                        }
                    }
                    .padding(.top, 8)
                }
                if workspace.loadingTransactions { ProgressView("Loading activity") }
                if let error = workspace.transactionError {
                    Text(error).foregroundStyle(.red)
                    Button("Retry activity") { Task { await workspace.refreshTransactions() } }
                }
            }
            .padding(22)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Business overview")
        .refreshable { await workspace.refreshTransactions() }
    }
}

struct Activity: View {
    let workspace: Workspace
    @State private var query = ""
    @State private var category: SpendCategory?
    @State private var filterDates = false
    @State private var start = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var end = Date.now

    var body: some View {
        let first = CalendarLabels.key(start)
        let last = CalendarLabels.key(end)
        let merchant = query.trimmingCharacters(in: .whitespaces)
        let rows = workspace.transactions.filter {
            (merchant.isEmpty || $0.merchant.localizedCaseInsensitiveContains(merchant))
                && (category == nil || $0.category == category)
                && (!filterDates || ($0.date >= first && $0.date <= last))
        }
        List {
            Section("Filters") {
                Picker("Category", selection: $category) {
                    Text("All categories").tag(nil as SpendCategory?)
                    ForEach(SpendCategory.allCases) { Text($0.title).tag(Optional($0)) }
                }
                Toggle("Filter by date", isOn: $filterDates)
                if filterDates {
                    DatePicker("From", selection: $start, in: ...end, displayedComponents: .date)
                    DatePicker("To", selection: $end, in: start..., displayedComponents: .date)
                }
            }
            Section("Transactions") {
                if workspace.loadingTransactions { ProgressView("Loading transactions") }
                else if let error = workspace.transactionError {
                    Text(error).foregroundStyle(.red)
                    Button("Try again") { Task { await workspace.refreshTransactions() } }
                } else if rows.isEmpty {
                    ContentUnavailableView("No matching transactions", systemImage: "magnifyingglass")
                }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, entry in
                    HStack(alignment: .top) {
                        Image(systemName: entry.category.icon).foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(entry.merchant).font(.headline)
                            Text("\(entry.category.title) · \(entry.date)").font(.caption).foregroundStyle(.secondary)
                            Text(Currency.format(-entry.pence)).monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .searchable(text: $query, prompt: "Search merchant")
        .navigationTitle("Activity")
        .refreshable { await workspace.refreshTransactions() }
    }
}

struct Settings: View {
    @Binding var darkTheme: Bool
    @Binding var highContrast: Bool
    @Binding var biometricUnlock: Bool
    let workspace: Workspace
    @State private var biometricError: String?
    @State private var checking = false

    var body: some View {
        Form {
            Section("Appearance") {
                Toggle("Dark theme", isOn: $darkTheme)
                Toggle("High contrast accent", isOn: $highContrast)
            }
            Section("Session") {
                Toggle("Biometric unlock", isOn: Binding(get: { biometricUnlock }, set: { enable in
                    if !enable { biometricUnlock = false; return }
                    checking = true
                    biometricError = nil
                    Task {
                        defer { checking = false }
                        do {
                            try await Workspace.verifyBiometrics(reason: "Enable biometric unlock")
                            biometricUnlock = true
                        } catch { biometricError = error.localizedDescription }
                    }
                }))
                .disabled(checking)
                if let biometricError { Text(biometricError).foregroundStyle(.red) }
                Button("Lock workspace") { workspace.lock(keepBiometricSession: biometricUnlock) }
            }
        }
        .navigationTitle("Settings")
    }
}
