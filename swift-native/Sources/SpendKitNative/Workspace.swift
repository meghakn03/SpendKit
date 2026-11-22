import Foundation
import LocalAuthentication
import Observation

@MainActor
@Observable
final class Workspace {
    private let api: BankAPI
    private var token: String?
    private var revision = 0
    private(set) var account: BankAccount?
    private(set) var transactions: [BankTransaction] = []
    private(set) var transactionError: String?
    private(set) var loadingTransactions = false

    init(api: BankAPI = BankAPI()) {
        self.api = api
    }

    var canUnlock: Bool { token != nil }

    func signIn(code: String) async throws {
        let previous = token
        let version = revision
        let session = try await api.signIn(code)
        guard revision == version else {
            await api.revoke(session.token)
            return
        }
        token = session.token
        account = session.account
        if let previous { await api.revoke(previous) }
    }

    func lock(keepBiometricSession: Bool) {
        revision += 1
        account = nil
        transactions = []
        transactionError = nil
        loadingTransactions = false
        if !keepBiometricSession, let token {
            self.token = nil
            Task { await api.revoke(token) }
        }
    }

    static func verifyBiometrics(reason: String) async throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw error ?? NSError(domain: "SpendKit", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Biometrics are unavailable on this device.",
            ])
        }
        _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
    }

    func unlock() async throws {
        guard let token, account == nil else { return }
        let version = revision
        try await Self.verifyBiometrics(reason: "Unlock SpendKit")
        do {
            let current = try await api.account(token)
            if revision == version { account = current }
        } catch {
            expireIfNeeded(error, token: token, revision: version)
            throw error
        }
    }

    func refreshTransactions() async {
        guard let token, account != nil else { return }
        let version = revision
        loadingTransactions = true
        transactionError = nil
        defer { if revision == version { loadingTransactions = false } }
        do {
            let rows = try await api.transactions(token)
            if revision == version { transactions = rows.sorted { $0.date > $1.date } }
        } catch {
            if revision == version { transactionError = error.localizedDescription }
            expireIfNeeded(error, token: token, revision: version)
        }
    }

    private func expireIfNeeded(_ error: any Error, token: String, revision: Int) {
        if (error as? BankAPI.Failure)?.status == 401, self.token == token, self.revision == revision {
            lock(keepBiometricSession: false)
        }
    }

    private func useSession<T: Sendable>(_ action: (String) async throws -> T) async throws -> T {
        guard let token, account != nil else {
            throw BankAPI.Failure(status: 401, message: "Sign in to continue.")
        }
        let version = revision
        do {
            let result = try await action(token)
            guard revision == version else { throw CancellationError() }
            return result
        } catch {
            expireIfNeeded(error, token: token, revision: version)
            throw error
        }
    }

    func setFrozen(_ frozen: Bool, code: String) async throws {
        account = try await useSession { try await api.setFrozen(frozen, code: code, token: $0) }
    }

    func setControls(limit: Int, atmBlocked: Bool, code: String) async throws {
        account = try await useSession {
            try await api.setControls(limit: limit, atmBlocked: atmBlocked, code: code, token: $0)
        }
    }

    func simulate(pence: Int, channel: CardChannel) async throws -> CardSimulation {
        let result = try await useSession { try await api.simulate(pence: pence, channel: channel, token: $0) }
        account = result.account
        return result
    }
}
