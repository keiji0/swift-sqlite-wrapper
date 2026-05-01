//
//  DatabaseError.swift
//  
//  
//  Created by keiji0 on 2022/06/30
//  
//

import Foundation
import SQLite3

public struct DatabaseError : Error {
    public let code: DatabaseErrorCode
    public let message: String
    
    init(code: Int32, message: String) {
        self.code = .init(rawValue: code) ?? .error
        self.message = message
    }
}

/// データベースからのエラー
public enum DatabaseErrorCode: Int32, Sendable {
    case error = 1 /* Generic error */
    case `internal` =     2   /* Internal logic error in SQLite */
    case perm =         3   /* Access permission denied */
    case abort =        4   /* Callback routine requested an abort */
    case busy =         5   /* The database file is locked */
    case locked =       6   /* A table in the database is locked */
    case nomem =        7   /* A malloc() failed */
    case readonly =     8   /* Attempt to write a readonly database */
    case interrupt =    9   /* Operation terminated by sqlite3_interrupt()*/
    case ioerr =       10   /* Some kind of disk I/O error occurred */
    case corrupt =     11   /* The database disk image is malformed */
    case notfound =    12   /* Unknown opcode in sqlite3_file_control() */
    case full =        13   /* Insertion failed because database is full */
    case cantopen =    14   /* Unable to open the database file */
    case `protocol` =    15   /* Database lock protocol error */
    case empty =       16   /* Internal use only */
    case schema =      17   /* The database schema changed */
    case toobig =      18   /* String or BLOB exceeds size limit */
    case constraint =  19   /* Abort due to constraint violation */
    case mismatch =    20   /* Data type mismatch */
    case misuse =      21   /* Library used incorrectly */
    case nolfs =       22   /* Uses OS features not supported on host */
    case auth =        23   /* Authorization denied */
    case format =      24   /* Not used */
    case range =       25   /* 2nd parameter to sqlite3_bind out of range */
    case notadb =      26   /* File opened that is not a database file */
    case notice =      27   /* Notifications from sqlite3_log() */
    case warning =     28   /* Warnings from sqlite3_log() */
}
