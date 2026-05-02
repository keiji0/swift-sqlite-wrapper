import Foundation
import SQLite3

/// 行を表すモデル
public struct Row: Sendable {
    /// カラム数を取得
    public var count: Int {
        values.count
    }

    /// 指定カラムがnilかどうか？
    public func isNull(_ index: Int) -> Bool {
        value(index).columnType == .null
    }

    /// カラムのタイプを取得
    public func type(_ index: Int) -> ColumnType {
        value(index).columnType
    }

    /// 指定カラムの値を取得
    public func value(_ index: Int) -> DatabaseValue {
        precondition(
            values.indices.contains(index),
            "Column index \(index) is out of bounds. Column count is \(values.count)."
        )
        return values[index]
    }

    // MARK: - Internal

    init(_ handle: OpaquePointer) throws {
        let columnCount = Int(sqlite3_column_count(handle))
        values = try (0..<columnCount).map { index in
            try Row.readValue(handle, index: index)
        }
    }

    // MARK: - Private

    private let values: [DatabaseValue]

    private static func readValue(_ handle: OpaquePointer, index: Int) throws -> DatabaseValue {
        let sqliteIndex = Int32(index)
        switch try ColumnType(sqliteType: sqlite3_column_type(handle, sqliteIndex)) {
        case .integer:
            return .integer(sqlite3_column_int64(handle, sqliteIndex))
        case .real:
            return .real(sqlite3_column_double(handle, sqliteIndex))
        case .text:
            guard let pointer = sqlite3_column_text(handle, sqliteIndex) else {
                return .null
            }
            return .text(String(cString: pointer))
        case .blob:
            let length = Int(sqlite3_column_bytes(handle, sqliteIndex))
            guard let pointer = sqlite3_column_blob(handle, sqliteIndex) else {
                return .blob(Data())
            }
            return .blob(Data(bytes: pointer, count: length))
        case .null:
            return .null
        }
    }
}
