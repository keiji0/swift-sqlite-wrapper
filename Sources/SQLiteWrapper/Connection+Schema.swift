/// スキーマ情報を扱う補助API
public extension Connection {
    /// 定義されている全てのテーブル名を取得
    func tableNames() throws -> [String] {
        try rows("SELECT tbl_name FROM sqlite_master WHERE type='table' ORDER BY tbl_name").map {
            try $0.databaseValue(0).stringValue()
        }
    }

    /// 指定テーブルが定義されているか？
    func hasTable(_ tableName: String) throws -> Bool {
        try tableNames().contains(tableName)
    }
}
