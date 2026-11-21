#if canImport(XCTest)
import XCTest
@testable import MacTouchCore

final class ConnectionHistoryTests: XCTestCase {
    private func makeStore(limit: Int = 100) -> ConnectionHistoryStore {
        ConnectionHistoryStore(defaults: UserDefaults(suiteName: "mactouch.history.\(UUID().uuidString)")!, limit: limit)
    }

    func testNewestFirstAndFieldsSurvive() {
        let store = makeStore()
        store.append(.paired, device: "Pixel", date: Date(timeIntervalSince1970: 100))
        store.append(.connected, device: "Pixel", detail: "from 192.168.1.50", date: Date(timeIntervalSince1970: 200))
        let all = store.all()
        XCTAssertEqual(all.map(\.kind), [.connected, .paired])
        XCTAssertEqual(all.first?.device, "Pixel")
        XCTAssertEqual(all.first?.detail, "from 192.168.1.50")
        XCTAssertEqual(all.first?.date.timeIntervalSince1970 ?? 0, 200, accuracy: 1)
    }

    func testLogIsCappedKeepingTheNewest() {
        let store = makeStore(limit: 5)
        for i in 0..<12 { store.append(.connected, device: "d\(i)", date: Date(timeIntervalSince1970: Double(i))) }
        let all = store.all()
        XCTAssertEqual(all.count, 5)
        XCTAssertEqual(all.first?.device, "d11")
        XCTAssertEqual(all.last?.device, "d7")
    }

    func testClearAndCorruptData() {
        let defaults = UserDefaults(suiteName: "mactouch.history.\(UUID().uuidString)")!
        let store = ConnectionHistoryStore(defaults: defaults)
        store.append(.serverStarted)
        store.clear()
        XCTAssertTrue(store.all().isEmpty)
        defaults.set(Data("not json".utf8), forKey: "mactouch.history.v1")
        XCTAssertTrue(store.all().isEmpty, "a corrupt log reads as empty and does not crash")
        store.append(.serverStopped)
        XCTAssertEqual(store.all().count, 1, "and can be written again")
    }

    func testLongTextIsTrimmed() {
        let store = makeStore()
        store.append(.serverFailed, device: String(repeating: "x", count: 500), detail: String(repeating: "y", count: 900))
        XCTAssertEqual(store.all().first?.device?.count, 64)
        XCTAssertEqual(store.all().first?.detail?.count, 200)
    }

    func testEveryKindHasATitle() {
        for k in HistoryKind.allCases { XCTAssertFalse(k.title.isEmpty) }
    }
}
#endif
