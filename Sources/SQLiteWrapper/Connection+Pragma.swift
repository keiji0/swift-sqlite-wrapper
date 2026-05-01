/// PRAGMAを扱う補助API
public extension Connection {
    /// ユーザーバージョンを取得する
    /// SQLite内部で使用されないユーザーが自由に設定できるバージョン
    /// 独自のバージョン管理を行いたい場合などに使用する
    /// 未設定の場合は0が設定されている
    func userVersion() throws -> Int64 {
        try scalar("PRAGMA user_version", as: Int64.self) ?? 0
    }

    /// ユーザーバージョンを設定する
    func setUserVersion(_ version: Int64) throws {
        try execute("PRAGMA user_version = \(version)")
    }
}
