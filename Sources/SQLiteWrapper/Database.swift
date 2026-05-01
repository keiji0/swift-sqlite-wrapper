//
//  Database.swift
//  SQLiteWrapper
//
//  Created by keiji0 on 2020/12/26.
//

import SQLite3

/// Connectionに依存しないSQLite APIを叩く場合にここから生やす
public enum Database {
    /// SQLiteのバージョンを取得
    public static var version: String {
        guard let cString = sqlite3_libversion() else { return "unknown" }
        return String(cString: cString)
    }
}
