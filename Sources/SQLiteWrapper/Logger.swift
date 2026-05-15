//
//  Logger.swift
//  
//  
//  Created by keiji0 on 2021/08/22
//  
//

import Foundation
import Logging

extension Logger {
    static let main = Logger(label: Bundle.main.bundleIdentifier ?? "SQLiteWrapper")
}
