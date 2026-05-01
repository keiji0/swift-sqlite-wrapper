import Foundation
import Testing
@testable import SQLiteWrapper

@Suite
struct DatabaseTests {
    @Test
    func open() throws {
        let dbFile = temporaryFile()
        _ = try Connection(dbFile)
        #expect(FileManager.default.fileExists(atPath: dbFile.path))
    }

    @Test("DB接続失敗")
    func databaseConnectionFailure() {
        let dbFile = URL(fileURLWithPath: "/").appendingPathComponent(UUID().uuidString)
        #expect(throws: SQLiteError.self) {
            _ = try Connection(dbFile)
        }
    }

    @Test("テーブル一覧を取得できる")
    func fetchesTableNames() throws {
        let db = try Connection()
        try db.execute("CREATE TABLE TestTable (date DATETIME)")
        #expect(try db.tableNames() == ["TestTable"])
    }

    @Test("テーブル有無を取得できる")
    func checksTableExistence() throws {
        let db = try Connection()
        try db.execute("CREATE TABLE TestTable (date DATETIME)")
        #expect(try db.hasTable("TestTable"))
        #expect(try !db.hasTable("Missing"))
    }

    @Test("インメモリで開くことができる")
    func opensInMemoryDatabase() throws {
        let db = try Connection()
        try db.execute("CREATE TABLE TestTable (date DATETIME)")
        #expect(try db.tableNames() == ["TestTable"])
    }

    @Test("busy timeoutを設定できる")
    func setsBusyTimeout() throws {
        let db = try Connection()
        try db.setBusyTimeout(100)
    }

    private func temporaryFile() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
    }
}
