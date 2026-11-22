import Foundation

struct BankAccount: Decodable, Sendable {
    let availablePence: Int
    let limitPence: Int
    let frozen: Bool
    let transactionLimitPence: Int
    let atmBlocked: Bool
    let today: String
}

struct BankSession: Decodable, Sendable {
    let token: String
    let account: BankAccount
}

enum SpendCategory: String, CaseIterable, Codable, Identifiable, Sendable {
    case software, travel, food, operations
    var id: Self { self }
    var title: String { self == .food ? "Food & drink" : rawValue.capitalized }
    var icon: String {
        switch self {
        case .software: "square.grid.2x2"
        case .travel: "train.side.front.car"
        case .food: "cup.and.saucer"
        case .operations: "shippingbox"
        }
    }
}

struct BankTransaction: Decodable, Hashable, Sendable {
    let merchant: String
    let category: SpendCategory
    let date: String
    let pence: Int
}

enum CardChannel: String, CaseIterable, Identifiable, Sendable {
    case purchase, atm
    var id: Self { self }
    var title: String { self == .purchase ? "Purchase" : "ATM withdrawal" }
}

enum CardDecision: String, Decodable, Sendable {
    case approved, cardFrozen, atmBlocked, overLimit, insufficientCredit

    var explanation: String {
        switch self {
        case .approved: "The amount is within the card limit and available credit."
        case .cardFrozen: "The virtual card is frozen."
        case .atmBlocked: "ATM withdrawals are blocked for this card."
        case .overLimit: "The amount exceeds the per-transaction limit."
        case .insufficientCredit: "The amount exceeds the available credit."
        }
    }
}

struct CardSimulation: Decodable, Sendable {
    let reason: CardDecision
    let account: BankAccount
}

struct Currency {
    static func format(_ pence: Int) -> String {
        (Decimal(pence) / 100).formatted(.currency(code: "GBP").locale(Locale(identifier: "en_GB")))
    }

    static func parse(_ text: String) -> Int? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ".", omittingEmptySubsequences: false)
        guard (1...2).contains(parts.count),
              (1...8).contains(parts[0].count),
              parts.allSatisfy({ $0.utf8.allSatisfy { (48...57).contains($0) } }),
              let pounds = Int(parts[0]) else { return nil }
        if parts.count == 1 { return pounds * 100 }
        guard (1...2).contains(parts[1].count), let fraction = Int(parts[1]) else { return nil }
        return pounds * 100 + fraction * (parts[1].count == 1 ? 10 : 1)
    }
}

struct BankAPI: Sendable {
    struct Failure: LocalizedError {
        let status: Int
        let message: String
        var errorDescription: String? { message }
    }

    private struct ErrorBody: Decodable { let error: String }
    private let base: URL

    init(base: URL? = nil) {
        self.base = base
            ?? ProcessInfo.processInfo.environment["SPENDKIT_API_URL"].flatMap(URL.init(string:))
            ?? URL(string: "http://localhost:8787")!
    }

    private func request(
        _ path: String, method: String = "GET", token: String? = nil,
        body: [String: Any]? = nil
    ) async throws -> Data {
        var request = URLRequest(url: base.appending(path: path), timeoutInterval: 8)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data).error)
                ?? "SpendKit could not complete the request."
            throw Failure(status: status, message: message)
        }
        return data
    }

    func signIn(_ code: String) async throws -> BankSession {
        let data = try await request("session", method: "POST", body: ["code": code])
        return try JSONDecoder().decode(BankSession.self, from: data)
    }

    func account(_ token: String) async throws -> BankAccount {
        let data = try await request("account", token: token)
        return try JSONDecoder().decode(BankAccount.self, from: data)
    }

    func transactions(_ token: String) async throws -> [BankTransaction] {
        let data = try await request("transactions", token: token)
        return try JSONDecoder().decode([BankTransaction].self, from: data)
    }

    func setFrozen(_ frozen: Bool, code: String, token: String) async throws -> BankAccount {
        let data = try await request("card", method: "PUT", token: token,
                                     body: ["code": code, "frozen": frozen])
        return try JSONDecoder().decode(BankAccount.self, from: data)
    }

    func setControls(limit: Int, atmBlocked: Bool, code: String, token: String) async throws -> BankAccount {
        let data = try await request("card/controls", method: "PUT", token: token, body: [
            "code": code, "transactionLimitPence": limit, "atmBlocked": atmBlocked,
        ])
        return try JSONDecoder().decode(BankAccount.self, from: data)
    }

    func simulate(pence: Int, channel: CardChannel, token: String) async throws -> CardSimulation {
        let data = try await request("card/simulations", method: "POST", token: token,
                                     body: ["pence": pence, "channel": channel.rawValue])
        return try JSONDecoder().decode(CardSimulation.self, from: data)
    }

    func revoke(_ token: String) async {
        _ = try? await request("session", method: "DELETE", token: token)
    }
}
