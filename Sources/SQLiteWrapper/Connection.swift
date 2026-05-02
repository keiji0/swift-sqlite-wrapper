import Foundation
import SQLite3
import os

/// データベースとの接続
/// クエリはこのクラスから行う。参照が切れると自動的にデータベースはクローズされます。
public final class Connection {
    /// 接続を開始
    /// - Parameters:
    ///   - path: SQLiteのファイルパス
    ///   - options: 接続オプション一覧
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

    /// URL指定で接続を開始
    public convenience init(_ url: URL, options: OpenOptions = .default) throws {
        try self.init(url.path, options: options)
    }

    /// インメモリでデータベースに接続
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

    /// テーブルがロックされている時のビジータイムを設定
    /// - Parameter milliseconds: ビジータイム（ミリ秒）
    /// マルチスレッド接続の場合にこの設定がないとSQLITE_BUSYが発生する
    public func setBusyTimeout(_ milliseconds: Int32) throws {
        try check(sqlite3_busy_timeout(handle, milliseconds), phase: .step)
    }

    /// 変更された行の数を取得する
    public var changes: Int {
        Int(sqlite3_changes(handle))
    }

    /// 値を取得しないSQLをPrepared Statementとして実行する
    /// 複数ステートメントの実行には対応していない
    public func execute(_ sql: String, _ parameters: [DatabaseValue] = []) throws {
        let statement = try query(sql, parameters)
        let result = try statement.step()
        try statement.reset()
        guard result == .done else {
            throw SQLiteError(message: "Expected statement to finish without returning rows.", sql: sql, phase: .step)
        }
    }

    /// SQLからステートメントを作成する
    /// 同一SQL文のステートメントはキャッシュして再利用する
    public func prepare(_ sql: String) throws -> Statement {
        if let statement = statements[sql] {
            return statement
        }

        let statement = try Statement(connection: self, sql: sql)
        statements[sql] = statement
        return statement
    }

    /// クエリ送信
    /// ステートメントはキャッシュされるため、スキーマ変更前のタイミングではclearStatementCacheしておくと安全
    public func query(_ sql: String, _ parameters: [DatabaseValue] = []) throws -> Statement {
        Logger.main.trace("query: \(sql)")
        let statement = try prepare(sql)
        try statement.bind(parameters)
        return statement
    }

    /// 取得した行一覧を配列として取得
    public func rows(_ sql: String, _ parameters: [DatabaseValue] = []) throws -> [Row] {
        try query(sql, parameters).fetchAll()
    }

    /// 単一の値を取得
    public func scalar(_ sql: String, _ parameters: [DatabaseValue] = []) throws -> DatabaseValue? {
        guard let row = try query(sql, parameters).fetchRow() else {
            return nil
        }
        return try row.value(0)
    }

    /// ステートメントキャッシュの削除
    public func clearStatementCache() {
        statements.removeAll()
    }

    /// キャンセル
    /// どのスレッドから実行しても問題ない
    public func cancel() {
        sqlite3_interrupt(handle)
    }

    /// トランザクション処理
    /// トランザクションが入れ子になっている場合はトップレベルのトランザクションが閉じられないとCommitされない
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

    /// SQLiteのAPIをコールした結果を検査する
    /// エラーが発生するとSQLiteErrorを投げる
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

    // MARK: - Private

    private let path: String
    private var transactionDepth = 0
    private var statements: [String: Statement] = [:]

    /// トランザクションの開始
    private func beginTransaction() throws {
        if transactionDepth == 0 {
            try execute("BEGIN")
        }
        transactionDepth += 1
    }

    /// トランザクションの終了
    private func commitTransaction() throws {
        guard transactionDepth > 0 else {
            throw SQLiteError(message: "No active transaction.", phase: .step)
        }
        transactionDepth -= 1
        if transactionDepth == 0 {
            try execute("COMMIT")
        }
    }

    /// ロールバックする
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
