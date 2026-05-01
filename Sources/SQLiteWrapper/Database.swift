//
//  Database.swift
//  SQLiteWrapper
//
//  Created by keiji0 on 2020/12/26.
//

import SQLite3

public enum Database {
    public static var version: String {
        guard let cString = sqlite3_libversion() else { return "unknown" }
        return String(cString: cString)
    }
}
