import Foundation

public enum DatabaseValue: Equatable, Sendable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null

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
}

public protocol DatabaseValueConvertible {
    var databaseValue: DatabaseValue { get }
    init(databaseValue: DatabaseValue) throws
}

extension Int: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .integer(Int64(self)) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .integer(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Int", actual: databaseValue.columnType)
        }
        self = Int(value)
    }
}

extension Int64: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .integer(self) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .integer(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Int64", actual: databaseValue.columnType)
        }
        self = value
    }
}

extension Int32: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .integer(Int64(self)) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .integer(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Int32", actual: databaseValue.columnType)
        }
        self = Int32(value)
    }
}

extension Double: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .real(self) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .real(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Double", actual: databaseValue.columnType)
        }
        self = value
    }
}

extension String: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .text(self) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .text(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "String", actual: databaseValue.columnType)
        }
        self = value
    }
}

extension Data: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .blob(self) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .blob(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Data", actual: databaseValue.columnType)
        }
        self = value
    }
}

extension Bool: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue { .integer(self ? 1 : 0) }

    public init(databaseValue: DatabaseValue) throws {
        guard case .integer(let value) = databaseValue else {
            throw SQLiteError.valueMismatch(expected: "Bool", actual: databaseValue.columnType)
        }
        self = value != 0
    }
}

extension Optional: DatabaseValueConvertible where Wrapped: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        switch self {
        case .some(let value):
            return value.databaseValue
        case .none:
            return .null
        }
    }

    public init(databaseValue: DatabaseValue) throws {
        if case .null = databaseValue {
            self = .none
        } else {
            self = .some(try Wrapped(databaseValue: databaseValue))
        }
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
