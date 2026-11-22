import Foundation
import Testing
@testable import SpendKitNative

@Test func poundsAreParsedInPence() {
    #expect(Currency.parse("250.99") == 25099)
    #expect(Currency.parse("12.5") == 1250)
    #expect(Currency.parse("600") == 60000)
    #expect(Currency.parse("12.999") == nil)
    #expect(Currency.parse("10,50") == nil)
    #expect(Currency.parse("-1.00") == nil)
    #expect(Currency.format(842560) == "£8,425.60")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["SPENDKIT_TEST_API"] != nil))
func useTheSpendKitBackend() async throws {
    let address = try #require(ProcessInfo.processInfo.environment["SPENDKIT_TEST_API"])
    let api = BankAPI(base: try #require(URL(string: address)))

    do {
        _ = try await api.signIn("0000")
        Issue.record("An incorrect code should be rejected.")
    } catch let failure as BankAPI.Failure {
        #expect(failure.status == 401)
    }

    let session = try await api.signIn("2048")
    let token = session.token
    #expect(session.account.availablePence == 842560)
    let rows = try await api.transactions(token)
    #expect(rows.count == 48)

    let declined = try await api.simulate(pence: 60000, channel: .purchase, token: token)
    #expect(declined.reason == .overLimit)
    do {
        _ = try await api.setFrozen(true, code: "0000", token: token)
        Issue.record("A protected card change should require the access code.")
    } catch let failure as BankAPI.Failure {
        #expect(failure.status == 403)
    }

    let updated = try await api.setControls(limit: 25099, atmBlocked: true, code: "2048", token: token)
    #expect(updated.transactionLimitPence == 25099)
    #expect(updated.atmBlocked)
    let atm = try await api.simulate(pence: 10000, channel: .atm, token: token)
    #expect(atm.reason == .atmBlocked)
    let purchase = try await api.simulate(pence: 10000, channel: .purchase, token: token)
    #expect(purchase.reason == .approved)
    let frozen = try await api.setFrozen(true, code: "2048", token: token)
    #expect(frozen.frozen)
    let blocked = try await api.simulate(pence: 10000, channel: .purchase, token: token)
    #expect(blocked.reason == .cardFrozen)
    #expect(blocked.account.availablePence == 842560)
    await api.revoke(token)
}
