import Foundation
import SQLite3

/// SQLiteのエラー
/// SQLiteの結果コード、メッセージ、実行SQL、失敗した処理フェーズを保持する
public struct SQLiteError: Error, LocalizedError, Sendable {
    /// SQLiteの結果コード
    public let code: SQLiteErrorCode?

    /// SQLiteまたはラッパーが返すエラーメッセージ
    public let message: String

    /// エラー発生時に実行していたSQL
    public let sql: String?

    /// エラーが発生した処理フェーズ
    public let phase: Phase

    /// SQLite操作のどの段階で失敗したか
    public enum Phase: String, Sendable {
        case open
        case prepare
        case bind
        case step
        case reset
        case clearBindings
        case close
        case value
    }

    public var errorDescription: String? {
        var parts = ["SQLite \(phase.rawValue) failed: \(message)"]
        if let code {
            parts.append("code=\(code.rawValue)")
        }
        if let sql {
            parts.append("sql=\(sql)")
        }
        return parts.joined(separator: ", ")
    }

    init(code: Int32, message: String, sql: String? = nil, phase: Phase) {
        self.code = SQLiteErrorCode(rawValue: code)
        self.message = message
        self.sql = sql
        self.phase = phase
    }

    init(message: String, sql: String? = nil, phase: Phase) {
        self.code = nil
        self.message = message
        self.sql = sql
        self.phase = phase
    }
}

/// データベースからのエラー
public enum SQLiteErrorCode: Int32, Sendable {
    case error = 1
    case `internal` = 2
    case perm = 3
    case abort = 4
    case busy = 5
    case locked = 6
    case nomem = 7
    case readonly = 8
    case interrupt = 9
    case ioerr = 10
    case corrupt = 11
    case notfound = 12
    case full = 13
    case cantopen = 14
    case `protocol` = 15
    case empty = 16
    case schema = 17
    case toobig = 18
    case constraint = 19
    case mismatch = 20
    case misuse = 21
    case nolfs = 22
    case auth = 23
    case format = 24
    case range = 25
    case notadb = 26
    case notice = 27
    case warning = 28
}
