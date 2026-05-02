import Foundation
import Testing
@testable import SQLiteWrapper

@Suite
struct QueryTests {
    @Test("Intを保存できる")
    func storesInt() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value INTEGER)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init(123)])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.intValue() == 123)
    }

    @Test("Int64を保存できる")
    func storesInt64() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value INTEGER)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init(Int64.max)])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.int64Value() == Int64.max)
    }

    @Test("Doubleを保存できる")
    func storesDouble() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value REAL)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init(123.25)])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.doubleValue() == 123.25)
    }

    @Test("Stringを保存できる")
    func storesString() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("123")])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.stringValue() == "123")
    }

    @Test("Dataを保存できる")
    func storesData() throws {
        let connection = try makeConnection()
        let data = try #require("123".data(using: .utf8))
        try connection.execute("CREATE TABLE TestTable (value BLOB)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init(data)])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.dataValue() == data)
    }

    @Test("NULLを保存し読み取れる")
    func storesAndReadsNull() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.null])

        let row = try #require(try connection.query("SELECT value FROM TestTable").fetchRow())
        #expect(row.isNull(0))
        #expect(row.value(0) == .null)
    }

    @Test("NULLを基本型として読むと型不一致エラー")
    func throwsWhenReadingNullAsBasicType() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value INTEGER)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.null])

        let row = try #require(try connection.query("SELECT value FROM TestTable").fetchRow())
        #expect(throws: SQLiteError.self) {
            _ = try row.value(0).intValue()
        }
    }

    @Test("型不一致エラーを返す")
    func throwsOnTypeMismatch() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("text")])
        let row = try #require(try connection.query("SELECT value FROM TestTable").fetchRow())

        #expect(throws: SQLiteError.self) {
            _ = try row.value(0).intValue()
        }
    }

    @Test("カラム数と型を取得できる")
    func fetchesColumnMetadata() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value1 INTEGER, value2 TEXT, value3 BLOB)")
        try connection.execute("INSERT INTO TestTable VALUES (?, ?, ?)", [.init(1), .init("2"), .init(Data())])

        let row = try #require(try connection.query("SELECT value1, value2, value3 FROM TestTable").fetchRow())
        #expect(row.count == 3)
        #expect(row.type(0) == .integer)
        #expect(row.type(1) == .text)
        #expect(row.type(2) == .blob)
    }

    @Test("リテラルでDatabaseValueを指定できる")
    func acceptsDatabaseValueLiterals() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (intValue INTEGER, realValue REAL, textValue TEXT, nullValue TEXT)")
        try connection.execute("INSERT INTO TestTable VALUES (?, ?, ?, ?)", [123, 4.5, "text", nil])

        let row = try #require(try connection.query("SELECT intValue, realValue, textValue, nullValue FROM TestTable").fetchRow())
        #expect(try row.value(0).intValue() == 123)
        #expect(try row.value(1).doubleValue() == 4.5)
        #expect(try row.value(2).stringValue() == "text")
        #expect(row.isNull(3))
    }

    @Test("配列として行を取得できる")
    func fetchesRowsAsArray() throws {
        let connection = try makeConnection()
        let records = ["1", "2", "3"]

        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        for record in records {
            try connection.execute("INSERT INTO TestTable VALUES (?)", [.init(record)])
        }

        let values = try connection.rows("SELECT value FROM TestTable ORDER BY value").map {
            try $0.value(0).stringValue()
        }
        #expect(values == records)
    }

    @Test("行シーケンスはエラーをResultで返す")
    func fetchesRowsAsResultSequence() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("1")])

        let results = Array(try connection.query("SELECT value FROM TestTable").rows())
        let row = try #require(try results.first?.get())
        #expect(try row.value(0).stringValue() == "1")
    }

    @Test("トランザクションをコミットできる")
    func commitsTransaction() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")

        try connection.transaction {
            try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("123")])
        }

        #expect(try connection.scalar("SELECT COUNT(*) FROM TestTable")?.intValue() == 1)
    }

    @Test("ロールバックできる")
    func rollsBackTransaction() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")

        #expect(throws: DummyError.self) {
            try connection.transaction {
                try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("123")])
                throw DummyError()
            }
        }

        #expect(try connection.scalar("SELECT COUNT(*) FROM TestTable")?.intValue() == 0)
    }

    @Test("ネストしたトランザクションをまとめてコミットできる")
    func commitsNestedTransaction() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")

        try connection.transaction {
            try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("1")])
            try connection.transaction {
                try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("2")])
            }
        }

        #expect(try connection.scalar("SELECT COUNT(*) FROM TestTable")?.intValue() == 2)
    }

    @Test("ネストしたトランザクションをまとめてロールバックできる")
    func rollsBackNestedTransaction() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")

        #expect(throws: DummyError.self) {
            try connection.transaction {
                try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("1")])
                try connection.transaction {
                    try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("2")])
                    throw DummyError()
                }
            }
        }

        #expect(try connection.scalar("SELECT COUNT(*) FROM TestTable")?.intValue() == 0)
    }

    @Test("statement cacheを明示的にクリアできる")
    func clearsStatementCache() throws {
        let connection = try makeConnection()
        let first = try connection.prepare("SELECT 1")
        let second = try connection.prepare("SELECT 1")
        #expect(first === second)

        connection.clearStatementCache()
        let third = try connection.prepare("SELECT 1")
        #expect(first !== third)
    }

    @Test("スキーマ変更後にstatement cacheをクリアして再利用できる")
    func reusesAfterSchemaChangeWhenCacheIsCleared() throws {
        let connection = try makeConnection()
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        _ = try connection.prepare("SELECT value FROM TestTable")
        try connection.execute("DROP TABLE TestTable")
        try connection.execute("CREATE TABLE TestTable (value TEXT)")
        connection.clearStatementCache()

        try connection.execute("INSERT INTO TestTable VALUES (?)", [.init("ok")])
        #expect(try connection.scalar("SELECT value FROM TestTable")?.stringValue() == "ok")
    }

    @Test("Cancelできる")
    func cancelsQuery() throws {
        let dbFile = temporaryFile()

        do {
            let connection = try Connection(dbFile)
            try connection.execute("CREATE TABLE Hoge (val INTEGER)")
        }

        do {
            let connection = try Connection(dbFile)
            let cancellableConnection = CancellableConnection(connection)

            let count = 500_000
            let values = (0..<count).map { _ in "(?)" }.joined(separator: ",")
            let params = (0..<count).map { _ in DatabaseValue(Int.random(in: 0...Int.max)) }

            try connection.execute("INSERT INTO Hoge VALUES \(values)", params)

            Task {
                try await Task.sleep(nanoseconds: 5_000_000)
                cancellableConnection.cancel()
            }

            let error = try #require(throws: SQLiteError.self) {
                _ = try connection.scalar("SELECT COUNT(*) FROM Hoge WHERE val = ?", [.init("33")])?.intValue()
            }
            #expect(error.code == .interrupt)
        }
    }

    @Test("UserVersionはデフォルトは0")
    func defaultUserVersionIsZero() throws {
        let connection = try makeConnection()
        #expect(try connection.userVersion() == 0)
    }

    @Test("UserVersionが使用できる")
    func usesUserVersion() throws {
        let connection = try makeConnection()
        try connection.setUserVersion(8)
        #expect(try connection.userVersion() == 8)
    }

    private func makeConnection() throws -> Connection {
        try Connection(temporaryFile())
    }

    private func temporaryFile() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
    }

    private struct DummyError: Error {
    }

    private struct CancellableConnection: @unchecked Sendable {
        let connection: Connection

        init(_ connection: Connection) {
            self.connection = connection
        }

        func cancel() {
            connection.cancel()
        }
    }
}
