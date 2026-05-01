//
//  Logger.swift
//  
//  
//  Created by keiji0 on 2021/08/22
//  
//

import Foundation
import os

extension Logger {
    static let main: Logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "SQLiteWapper",
        category: "SqliteWapper"
    )
}
