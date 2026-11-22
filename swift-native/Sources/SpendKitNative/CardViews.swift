import SwiftUI

struct CardScreen: View {
    let account: BankAccount
    let workspace: Workspace
    @State private var action: CardAction?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CreditSummary(account: account)
                GroupBox("Card controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledContent("Per-transaction limit", value: Currency.format(account.transactionLimitPence))
                        LabeledContent("ATM withdrawals", value: account.atmBlocked ? "Blocked" : "Allowed")
                        Button("Edit spending controls") { action = .controls }
                            .buttonStyle(.borderedProminent)
                        Button(account.frozen ? "Unfreeze card" : "Freeze card") { action = .freeze }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                }
                NavigationLink {
                    Simulator(workspace: workspace, account: account)
                } label: {
                    Label("Test card controls", systemImage: "play.circle")
                }
            }
            .padding(22)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Your card")
        .sheet(item: $action) {
            CardVerification(action: $0, account: account, workspace: workspace)
        }
    }
}

private enum CardAction: String, Identifiable {
    case freeze, controls
    var id: Self { self }
}

private struct CardVerification: View {
    let action: CardAction
    let account: BankAccount
    let workspace: Workspace
    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var amount = ""
    @State private var atmBlocked = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                if action == .controls {
                    Section("Spending controls") {
                        TextField("Per-transaction limit (£)", text: $amount)
                        Toggle("Block ATM withdrawals", isOn: $atmBlocked)
                    }
                }
                Section("Verify access") {
                    SecureField("Access code", text: $code)
                    if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                    Button("Verify and save", action: save)
                        .disabled(code.isEmpty || busy)
                    if busy { ProgressView("Saving changes") }
                }
            }
            .padding()
            .navigationTitle(action == .controls ? "Spending controls" : account.frozen ? "Unfreeze card" : "Freeze card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.disabled(busy)
                }
            }
        }
        .frame(minWidth: 300, minHeight: 350)
        .interactiveDismissDisabled(busy)
        .onAppear {
            amount = (Decimal(account.transactionLimitPence) / 100).formatted(.number.locale(Locale(identifier: "en_GB")).grouping(.never))
            atmBlocked = account.atmBlocked
        }
    }

    private func save() {
        let limit = Currency.parse(amount) ?? 0
        if action == .controls && !(1...account.limitPence).contains(limit) {
            error = "Enter an amount from £0.01 to \(Currency.format(account.limitPence))."
            return
        }
        busy = true
        error = nil
        let enteredCode = code.trimmingCharacters(in: .whitespaces)
        Task {
            defer { busy = false }
            do {
                switch action {
                case .freeze: try await workspace.setFrozen(!account.frozen, code: enteredCode)
                case .controls: try await workspace.setControls(limit: limit, atmBlocked: atmBlocked, code: enteredCode)
                }
                dismiss()
            } catch { self.error = error.localizedDescription }
        }
    }
}

struct Simulator: View {
    let workspace: Workspace
    let account: BankAccount
    @State private var amount = "600.00"
    @State private var channel = CardChannel.purchase
    @State private var result: CardSimulation?
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        let current = result?.account ?? workspace.account ?? account
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Test a fictional purchase or ATM withdrawal. No money moves.")
                    .foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Transaction type", selection: $channel) {
                            ForEach(CardChannel.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        TextField("Amount (£)", text: $amount).textFieldStyle(.roundedBorder)
                        Button("Run simulation", action: simulate).buttonStyle(.borderedProminent)
                        if busy { ProgressView("Checking card rules") }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(busy)
                }
                if let error { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.red) }
                if let result {
                    let approved = result.reason == .approved
                    let color = approved ? Color.green : Color.red
                    VStack(alignment: .leading, spacing: 8) {
                        Label(approved ? "Approved" : "Declined", systemImage: approved ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .font(.title2.bold())
                        Text(result.reason.explanation)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 18))
                    .accessibilityElement(children: .combine)
                }
                GroupBox("Rules in effect") {
                    VStack(spacing: 12) {
                        LabeledContent("Card status", value: current.frozen ? "Frozen" : "Active")
                        LabeledContent("Per-transaction limit", value: Currency.format(current.transactionLimitPence))
                        LabeledContent("ATM withdrawals", value: current.atmBlocked ? "Blocked" : "Allowed")
                        LabeledContent("Available credit", value: Currency.format(current.availablePence))
                    }
                    .padding(.top, 8)
                }
            }
            .padding(22)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Card simulator")
        .onChange(of: amount) { _, _ in clearResult() }
        .onChange(of: channel) { _, _ in clearResult() }
    }

    private func clearResult() {
        result = nil
        error = nil
    }

    private func simulate() {
        clearResult()
        guard let pence = Currency.parse(amount), pence > 0 else {
            error = "Enter an amount greater than zero."
            return
        }
        busy = true
        let selectedChannel = channel
        Task {
            defer { busy = false }
            do { result = try await workspace.simulate(pence: pence, channel: selectedChannel) }
            catch { self.error = error.localizedDescription }
        }
    }
}
