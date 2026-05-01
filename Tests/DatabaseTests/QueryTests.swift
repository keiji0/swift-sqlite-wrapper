import Testing
import Foundation
@testable import SQLiteWapper

@Suite
struct QueryTests {
    @Test("Intを保存できる")
    func storesInt() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value INTEGER );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ 123 ])
        #expect(try connection.fetchValue("SELECT value FROM \(tableName)") == 123)
    }

    @Test("Int32を保存できる")
    func storesInt32() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value INTEGER );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ Int32(321) ])
        #expect(try connection.fetchValue("SELECT value FROM \(tableName)") == Int32(321))
    }

    @Test("Doubleを保存できる")
    func storesDouble() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value DOUBLE );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ 123.0 ])
        #expect(try connection.fetchValue("SELECT value FROM \(tableName)") == 123.0)
    }

    @Test("Stringを保存できる")
    func storesString() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value TEXT );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ "123" ])
        #expect(try connection.fetchValue("SELECT value FROM \(tableName)") == "123")
    }

    @Test("Dataを保存できる")
    func storesData() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value1, value2, value3 );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?, ?, ?)", [ 1, 2, 3 ])
        let row1 = try #require(try connection.query("SELECT value1 FROM \(tableName)").fetchRow())
        let row2 = try #require(try connection.query("SELECT value1, value2 FROM \(tableName)").fetchRow())
        let row3 = try #require(try connection.query("SELECT value1, value2, value3 FROM \(tableName)").fetchRow())
        #expect(row1.count == 1)
        #expect(row2.count == 2)
        #expect(row3.count == 3)
    }

    @Test("カラム数を取得")
    func fetchesColumnCount() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        let data = try #require("123".data(using: .utf8))
        try connection.exec("CREATE TABLE \(tableName) ( value BLOB );")
        try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ data ])
        #expect(try connection.fetchValue("SELECT value FROM \(tableName)") == data)
    }

    @Test("ロールバックできる")
    func rollsBackTransaction() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        try connection.exec("CREATE TABLE \(tableName) ( value )")
        try? connection.transaction {
            try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ "123" ])
            throw DummyError()
        }
        #expect(try connection.count("SELECT COUNT(*) FROM \(tableName)") == 0)
    }

    @Test("行をシーケンスとして取得できる")
    func fetchesRowsAsSequence() throws {
        let connection = try makeConnection()
        let tableName = "TestTable"
        let recoerds = ["1", "2", "3"]

        try connection.exec("CREATE TABLE \(tableName) ( value TEXT );")
        for record in recoerds {
            try connection.exec("INSERT INTO \(tableName) VALUES(?)", [ record ])
        }

        do {
            let values: [String] = try connection.query("SELECT value FROM \(tableName) ORDER BY value").fetchRows().map {
                try #require($0.value(0))
            }
            #expect(values == recoerds)
        }
        do {
            let values: [String] = try connection.query("SELECT value FROM \(tableName) ORDER BY value DESC").fetchRows().map {
                try #require($0.value(0))
            }
            #expect(values == recoerds.reversed())
        }
    }

    @Test("Cancelできる")
    func cancelsQuery() throws {
        let dbFile = getTmpFile()

        // 適当なテーブルを作っておく
        do {
            let connection = try Connection(dbFile)
            try connection.exec("CREATE TABLE Hoge ( val );")
        }

        // Commit前にキャンセルする
        do {
            let connection = try Connection(dbFile)
            let cancellableConnection = CancellableConnection(connection)

            let count = 500000
            let values = (0..<count).map{ _ in "(?)" }.joined(separator: ",")
            let params = (0..<count).map { _ in Int.random(in: 0...Int.max) }

            try connection.exec("INSERT INTO Hoge VALUES \(values)", params)

            Task {
                try await Task.sleep(nanoseconds: 5_000_000)
                cancellableConnection.cancel()
            }

            let error = try #require(throws: DatabaseError.self) {
                _ = try connection.count("SELECT COUNT(*) FROM Hoge WHERE val=?", [ "33" ])
            }
            #expect(error.code == DatabaseErrorCode.interrupt)
        }
    }

    @Test("UserVersionはデフォルトは0")
    func defaultUserVersionIsZero() throws {
        let connection = try makeConnection()
        #expect(connection.userVersion == 0)
    }

    @Test("UserVersionが使用できる")
    func usesUserVersion() throws {
        let connection = try makeConnection()
        connection.userVersion = 8
        #expect(connection.userVersion == 8)
    }

    private func makeConnection() throws -> Connection {
        try .init(getTmpFile())
    }

    private func getTmpFile() -> URL {
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

func funcTime(action: () -> Void) {
    let startDate = Date()
    action()
    let endDate = Date()
    print("\(endDate.timeIntervalSince(startDate))")
}
