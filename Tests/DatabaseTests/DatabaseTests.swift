import Testing
import Foundation
@testable import SQLiteWapper

@Suite
struct DatabaseTests {
    @Test
    func open() throws {
        let dbFile = getTmpFile()
        _ = try Connection(dbFile)
        #expect(FileManager.default.fileExists(atPath: dbFile.path))
    }

    @Test("DB接続失敗")
    func databaseConnectionFailure() {
        let dbFile = createNotWriteFile()
        #expect(throws: Error.self) {
            _ = try Connection(dbFile)
        }
    }

    @Test("テーブル一覧を取得できる")
    func fetchesTableNames() throws {
        let dbFile = getTmpFile()
        let db = try Connection(dbFile)
        try db.exec("CREATE TABLE TestTable ( date DATETIME );")
        #expect(db.tableNames == ["TestTable"])
    }

    @Test("インメモリで開くことができる")
    func opensInMemoryDatabase() throws {
        let db = try Connection()
        try db.exec("CREATE TABLE TestTable ( date DATETIME );")
        #expect(db.tableNames == ["TestTable"])
    }

    private func getTmpFile() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
    }

    private func createNotWriteFile() -> URL {
        URL(fileURLWithPath: "/").appendingPathComponent(UUID().uuidString)
    }
}
