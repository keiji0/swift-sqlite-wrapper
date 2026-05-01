import Foundation
import SQLite3
import os

public final class Connection {
    public init(_ path: String, options: OpenOptions = .default) throws {
        self.path = path
        var openedHandle: OpaquePointer?
        let result = sqlite3_open_v2(path, &openedHandle, options.rawValue, nil)

        guard result == SQLITE_OK else {
            let message = Connection.errorMessage(for: openedHandle)
            if let openedHandle {
                sqlite3_close(openedHandle)
            }
            throw SQLiteError(code: result, message: message, sql: nil, phase: .open)
        }
        guard let openedHandle else {
            throw SQLiteError(message: "SQLite did not return a database handle.", phase: .open)
        }
        handle = openedHandle

        Logger.main.info("Opened SQLite database version=\(Database.version), path=\(path)")
    }

    public convenience init(_ url: URL, options: OpenOptions = .default) throws {
        try self.init(url.path, options: options)
    }

    public convenience init(options: OpenOptions = .default) throws {
        try self.init(":memory:", options: options)
    }

    deinit {
        statements.removeAll()
        let result = sqlite3_close(handle)
        if result != SQLITE_OK {
            Logger.main.error("Failed to close SQLite database path=\(self.path), result=\(result), message=\(Connection.errorMessage(for: self.handle))")
        }
    }

    public func setBusyTimeout(_ milliseconds: Int32) throws {
        try check(sqlite3_busy_timeout(handle, milliseconds), phase: .step)
    }

    public var changes: Int {
        Int(sqlite3_changes(handle))
    }

    public func execute(_ sql: String, _ parameters: [any DatabaseValueConvertible] = []) throws {
        let statement = try query(sql, parameters)
        let result = try statement.step()
        try statement.reset()
        guard result == .done else {
            throw SQLiteError(message: "Expected statement to finish without returning rows.", sql: sql, phase: .step)
        }
    }

    public func prepare(_ sql: String) throws -> Statement {
        if let statement = statements[sql] {
            return statement
        }

        let statement = try Statement(connection: self, sql: sql)
        statements[sql] = statement
        return statement
    }

    public func query(_ sql: String, _ parameters: [any DatabaseValueConvertible] = []) throws -> Statement {
        Logger.main.trace("query: \(sql)")
        let statement = try prepare(sql)
        try statement.bind(parameters)
        return statement
    }

    public func rows(_ sql: String, _ parameters: [any DatabaseValueConvertible] = []) throws -> [Row] {
        try query(sql, parameters).fetchAll()
    }

    public func scalar<T: DatabaseValueConvertible>(
        _ sql: String,
        _ parameters: [any DatabaseValueConvertible] = [],
        as type: T.Type = T.self
    ) throws -> T? {
        guard let row = try query(sql, parameters).fetchRow() else {
            return nil
        }
        return try row.value(0, as: type)
    }

    public func clearStatementCache() {
        statements.removeAll()
    }

    public func tableNames() throws -> [String] {
        try rows("SELECT tbl_name FROM sqlite_master WHERE type='table' ORDER BY tbl_name").map {
            try $0.value(0, as: String.self)
        }
    }

    public func hasTable(_ tableName: String) throws -> Bool {
        try tableNames().contains(tableName)
    }

    public func cancel() {
        sqlite3_interrupt(handle)
    }

    public func userVersion() throws -> Int64 {
        try scalar("PRAGMA user_version", as: Int64.self) ?? 0
    }

    public func setUserVersion(_ version: Int64) throws {
        try execute("PRAGMA user_version = \(version)")
    }

    @discardableResult
    public func transaction<T>(_ block: () throws -> T) throws -> T {
        try beginTransaction()
        do {
            let value = try block()
            try commitTransaction()
            return value
        } catch {
            let rollbackError = rollbackTransaction()
            if let rollbackError {
                throw rollbackError
            }
            throw error
        }
    }

    let handle: OpaquePointer

    @discardableResult
    func check(_ result: Int32, sql: String? = nil, phase: SQLiteError.Phase) throws -> Int32 {
        switch result {
        case SQLITE_OK, SQLITE_DONE, SQLITE_ROW:
            return result
        default:
            throw SQLiteError(code: result, message: Self.errorMessage(for: handle), sql: sql, phase: phase)
        }
    }

    static func errorMessage(for handle: OpaquePointer?) -> String {
        guard let message = sqlite3_errmsg(handle) else {
            return "Unknown SQLite error."
        }
        return String(cString: message)
    }

    private let path: String
    private var transactionDepth = 0
    private var statements: [String: Statement] = [:]

    private func beginTransaction() throws {
        if transactionDepth == 0 {
            try execute("BEGIN")
        }
        transactionDepth += 1
    }

    private func commitTransaction() throws {
        guard transactionDepth > 0 else {
            throw SQLiteError(message: "No active transaction.", phase: .step)
        }
        transactionDepth -= 1
        if transactionDepth == 0 {
            try execute("COMMIT")
        }
    }

    private func rollbackTransaction() -> Error? {
        guard transactionDepth > 0 else {
            return nil
        }
        transactionDepth = 0
        do {
            try execute("ROLLBACK")
            return nil
        } catch {
            return error
        }
    }
}
