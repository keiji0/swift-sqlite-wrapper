//
//  Connection.swift
//  
//  
//  Created by keiji0 on 2022/06/29
//  
//

import Foundation
import SQLite3
import os

/// データベースとの接続
/// クエリはこのクラスから行う。参照が切れると自動的にデータベースはクローズされます
public final class Connection {
    
    /// 接続を開始
    /// - Parameters:
    ///   - fileURL: sqliteのファイルパス
    ///   - options: 接続オプション一覧
    public init(_ path: String, _ options: OpenOptions = .default) throws {
        self.path = path
        self.options = options
        do {
            Logger.main.info("Opening version=\(Database.version ?? "<nil>"), path=\(path), thread=\(Thread.current)")
            try call { sqlite3_open_v2(path, &handle, options.rawValue, nil) }
            Logger.main.trace("Open success: path=\(path)")
        } catch {
            throw error
        }
    }
    
    /// URL指定で接続を開始
    public convenience init(_ url: URL, _ options: OpenOptions = .default) throws {
        try self.init(url.path, options)
    }
    
    /// インメモリでデータベースに接続
    public convenience init(_ options: OpenOptions = .default) throws {
        try self.init(":memory:", options)
    }
    
    deinit {
        Logger.main.trace("Close \(self.path), thread=\(Thread.current)")
        statements.removeAll()
        do {
            try call {
                sqlite3_close(handle)
            }
        } catch let e {
            fatalError(e.localizedDescription)
        }
    }
    
    /// テーブルがロックされている時のビジータイムを設定
    /// - Parameter ms: ビジータイム（マイクロ秒）
    /// マルチスレッド接続の場合にこの設定がないとSQLITE_BUSYが発生する
    public func setBusyTimeout(_ ms: Int32) {
        try! call { sqlite3_busy_timeout(handle, ms) }
    }
    
    /// 変更された行の数を取得する
    public func changes() -> Int32 {
        sqlite3_changes(handle)
    }
    
    ///  値の取得がないクエリ
    public func exec(_ sql: String, _ params: [Value] = []) throws {
        let stmt = try query(sql, params)
        try _ = stmt.step()
        try stmt.reset()
    }
    
    /// ステートメントの削除
    public func clearStatement() {
        statements.removeAll()
    }
    
    /// クエリ送信
    /// ステートメントはキャッシュされるため、スキーマ変更前のタイミングではclearStatementしておくと安全
    public func query(_ sql: String, _ params: [Value] = []) throws -> Statement {
        Logger.main.trace("query(\(Thread.current)): \(sql), \(params)")
        let stmt = try prepareSql(sql)
        try stmt.bind(params)
        return stmt
    }
    
    /// 単一の値を取得
    public func fetchValue<T: Value>(_ sql: String, _ params: [Value] = []) throws -> T? {
        let stmt = try query(sql, params)
        return try stmt.fetchRow()?.value(0)
    }
    
    /// 取得した行一覧から値一覧を取得
    public func fetchValues<T: Value>(_ sql: String, _ params: [Value] = []) throws -> [T] {
        let stmt = try query(sql, params)
        return try stmt.fetchRows().compactMap {
            $0.value(0)
        }
    }
    
    /// クエリ結果行数を取得
    public func count(_ sql: String, _ params: [Value] = []) throws -> Int {
        try fetchValue(sql, params) ?? 0
    }
    
    /// 定義されている全てのテーブル名を取得
    /// システムよりの処理なので失敗しても例外は発生せず、空配列を返す
    public var tableNames: [String] {
        (try? fetchValues("SELECT tbl_name FROM sqlite_master WHERE type='table'")) ?? []
    }
    
    /// 指定テーブルが定義されているか？
    public func hasTable(_ tableName: String) -> Bool {
        tableNames.contains(tableName)
    }
    
    /// キャンセル
    /// どのスレッドから実行しても問題ない
    public func cancel() {
        sqlite3_interrupt(handle)
    }
    
    /// ユーザーバージョン
    /// SQLite内部で使用されないユーザーが自由に設定できるバージョン
    /// 独自のバージョン管理を行いたい場合などに使用する
    /// 未設定の場合は0が設定されている
    public var userVersion: Int64 {
        get {
            (try? fetchValue("PRAGMA user_version")) ?? 0
        }
        set {
            try! exec("PRAGMA user_version = \(newValue)")
        }
    }
    
    /// トランザクション処理
    public func transaction(_ block: () throws -> Void) throws {
        try beginTransaction()
        do {
            try block()
            try end()
        } catch let e {
            rollback()
            throw e
        }
    }
    
    /// トランザクション(値を返す)
    public func transaction<T>(_ block: () throws -> T) throws -> T {
        var res: T?
        try transaction {
            res = try block()
        }
        return res!
    }
    
    // MARK: - Internal
    
    var handle: OpaquePointer?
    
    /// sqliteのAPIをコールする
    /// エラーが発生すると例外を投げる
    @discardableResult
    func call(block: () -> (Int32)) throws -> QueryResult {
        let result = QueryResult.code(for: block())
        switch result {
        case .ok, .done, .row:
            return result
        case .error(let code):
            throw DatabaseError(code: code, message: String(cString: sqlite3_errmsg(handle)))
        }
    }
    
    // MARK: - Private
    
    private let path: String
    private let options: OpenOptions
    private var transactionNestLevel: Int = 0
    private var statements = [String: Statement]()
    
    /// 同一SQL文のステートメントはキャッシュする。これによって10-20%ほど早くなった
    private func prepareSql(_ sql: String) throws -> Statement {
        if let statement = statements[sql] {
            return statement
        } else {
            let statement = try prepare(sql)
            statements[sql] = statement
            return statement
        }
    }
    
    /// ステートメントの削除
    private func removeStatement(_ sql: String) {
        statements[sql] = nil
    }
    
    /// ステートメントを作成する
    private func prepare(_ sql: String) throws -> Statement {
        try Statement(self, sql: sql)
    }
    
    /// トランザクション中か？
    private var isTransaction: Bool {
        0 < transactionNestLevel
    }
    
    /// トランザクションの開始
    /// トランザクションが入れ子になっている場合はトップレベルのトランザクションが閉じられないとCommitされない
    private func beginTransaction() throws {
        defer { transactionNestLevel += 1 }
        guard transactionNestLevel == 0 else { return }
        try exec("BEGIN")
    }
    
    /// ロールバックする
    private func rollback() {
        guard isTransaction else {
            return
        }
        try? exec("ROLLBACK")
        transactionNestLevel = 0
    }
    
    /// トランザクションの終了
    private func end() throws {
        assert(isTransaction)
        defer { transactionNestLevel -= 1 }
        guard transactionNestLevel == 1 else { return }
        try exec("COMMIT")
    }
}
