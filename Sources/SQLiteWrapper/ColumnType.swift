import SQLite3

/// カラムのプリミティブな型
/// https://www.sqlite.org/c3ref/c_blob.html
/// 基本型は全部で5つ
public enum ColumnType: Equatable, Sendable {
    case integer
    case real
    case text
    case blob
    case null

    /// APIの値からカラムインスタンスを生成
    init(sqliteType: Int32) throws {
        switch sqliteType {
        case SQLITE_INTEGER:
            self = .integer
        case SQLITE_FLOAT:
            self = .real
        case SQLITE_TEXT:
            self = .text
        case SQLITE_BLOB:
            self = .blob
        case SQLITE_NULL:
            self = .null
        default:
            throw SQLiteError(message: "Unknown SQLite column type: \(sqliteType).", phase: .value)
        }
    }
}
