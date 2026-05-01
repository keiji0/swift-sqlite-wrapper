import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public final class Statement {
    public let sql: String

    init(connection: Connection, sql: String) throws {
        self.connection = connection
        self.sql = sql

        var preparedHandle: OpaquePointer?
        try connection.check(
            sqlite3_prepare_v2(connection.handle, sql, -1, &preparedHandle, nil),
            sql: sql,
            phase: .prepare
        )

        guard let preparedHandle else {
            throw SQLiteError(message: "SQLite did not return a prepared statement.", sql: sql, phase: .prepare)
        }
        handle = preparedHandle
    }

    deinit {
        sqlite3_finalize(handle)
    }

    public func bind(_ values: some Collection<any DatabaseValueConvertible>) throws {
        try reset()
        for (offset, value) in values.enumerated() {
            try bind(value.databaseValue, at: offset + 1)
        }
    }

    public func fetchRow() throws -> Row? {
        switch try step() {
        case .row:
            return try Row(handle)
        case .done:
            return nil
        }
    }

    public func fetchAll() throws -> [Row] {
        var rows: [Row] = []
        while let row = try fetchRow() {
            rows.append(row)
        }
        return rows
    }

    public func rows() -> RowSequence {
        RowSequence(statement: self)
    }

    public func reset() throws {
        try connection.check(sqlite3_reset(handle), sql: sql, phase: .reset)
        try clearBindings()
    }

    public func clearBindings() throws {
        try connection.check(sqlite3_clear_bindings(handle), sql: sql, phase: .clearBindings)
    }

    enum StepResult {
        case row
        case done
    }

    func step() throws -> StepResult {
        let result = try connection.check(sqlite3_step(handle), sql: sql, phase: .step)
        switch result {
        case SQLITE_ROW:
            return .row
        case SQLITE_DONE:
            return .done
        default:
            throw SQLiteError(code: result, message: "Unexpected SQLite step result.", sql: sql, phase: .step)
        }
    }

    private let handle: OpaquePointer
    private unowned let connection: Connection

    private func bind(_ value: DatabaseValue, at index: Int) throws {
        let result: Int32
        switch value {
        case .integer(let value):
            result = sqlite3_bind_int64(handle, Int32(index), value)
        case .real(let value):
            result = sqlite3_bind_double(handle, Int32(index), value)
        case .text(let value):
            result = sqlite3_bind_text(handle, Int32(index), value, -1, sqliteTransient)
        case .blob(let value):
            result = value.withUnsafeBytes { pointer in
                sqlite3_bind_blob(handle, Int32(index), pointer.baseAddress, Int32(value.count), sqliteTransient)
            }
        case .null:
            result = sqlite3_bind_null(handle, Int32(index))
        }
        try connection.check(result, sql: sql, phase: .bind)
    }
}

public struct RowSequence: Sequence {
    public typealias Element = Result<Row, Error>

    fileprivate let statement: Statement

    public func makeIterator() -> Iterator {
        Iterator(statement: statement)
    }

    public struct Iterator: IteratorProtocol {
        fileprivate let statement: Statement
        private var isFinished = false

        fileprivate init(statement: Statement) {
            self.statement = statement
        }

        public mutating func next() -> Result<Row, Error>? {
            guard !isFinished else {
                return nil
            }

            do {
                guard let row = try statement.fetchRow() else {
                    isFinished = true
                    return nil
                }
                return .success(row)
            } catch {
                isFinished = true
                return .failure(error)
            }
        }
    }
}
