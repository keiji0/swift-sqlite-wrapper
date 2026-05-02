import Foundation

/// SQLiteのカラム値
/// Bind時とSelectからの値を共通して扱う値を表す
public enum DatabaseValue: Equatable, Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null

    public init(_ value: Int) {
        self = .integer(Int64(value))
    }

    public init(_ value: Int64) {
        self = .integer(value)
    }

    public init(_ value: Int32) {
        self = .integer(Int64(value))
    }

    public init(_ value: Double) {
        self = .real(value)
    }

    public init(_ value: String) {
        self = .text(value)
    }

    public init(_ value: Data) {
        self = .blob(value)
    }

    /// 値に対応するSQLiteのプリミティブな型
    public var columnType: ColumnType {
        switch self {
        case .integer:
            return .integer
        case .real:
            return .real
        case .text:
            return .text
        case .blob:
            return .blob
        case .null:
            return .null
        }
    }

    public func intValue() throws -> Int {
        Int(try int64Value())
    }

    public func int64Value() throws -> Int64 {
        guard case .integer(let value) = self else {
            throw SQLiteError.valueMismatch(expected: "Int64", actual: columnType)
        }
        return value
    }

    public func doubleValue() throws -> Double {
        guard case .real(let value) = self else {
            throw SQLiteError.valueMismatch(expected: "Double", actual: columnType)
        }
        return value
    }

    public func stringValue() throws -> String {
        guard case .text(let value) = self else {
            throw SQLiteError.valueMismatch(expected: "String", actual: columnType)
        }
        return value
    }

    public func dataValue() throws -> Data {
        guard case .blob(let value) = self else {
            throw SQLiteError.valueMismatch(expected: "Data", actual: columnType)
        }
        return value
    }

}

extension DatabaseValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self = .integer(value)
    }
}

extension DatabaseValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) {
        self = .real(value)
    }
}

extension DatabaseValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self = .text(value)
    }
}

extension DatabaseValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) {
        self = .null
    }
}

extension SQLiteError {
    static func valueMismatch(expected: String, actual: ColumnType) -> SQLiteError {
        SQLiteError(
            message: "Expected \(expected), but column contains \(actual).",
            phase: .value
        )
    }
}
