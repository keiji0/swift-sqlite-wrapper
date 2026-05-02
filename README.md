# SQLiteWrapper

SQLiteWrapper is a small synchronous Swift wrapper around SQLite.

It keeps SQL visible, while adding explicit SQLite value binding, row reads,
statement reuse, transactions, and structured SQLite errors.

## Usage

```swift
import SQLiteWrapper

let db = try Connection(options: .default)

try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, note TEXT)")
try db.execute(
    "INSERT INTO items (name, note) VALUES (?, ?)",
    [.init("Keyboard"), .null]
)

let rows = try db.rows("SELECT id, name, note FROM items ORDER BY id")
for row in rows {
    let id = try row.databaseValue(0).intValue()
    let name = try row.databaseValue(1).stringValue()
    let note = try row.databaseValue(2)
    print(id, name, note as Any)
}
```

## Scalar Values

```swift
let count = try db.scalar("SELECT COUNT(*) FROM items")?.intValue()
```

## Prepared Statements

```swift
let statement = try db.query("SELECT name FROM items WHERE id = ?", [.init(1)])
let row = try statement.fetchRow()
let name = try row?.databaseValue(0).stringValue()
```

Statements are cached by SQL string inside `Connection`. Clear the cache before
reusing SQL across schema changes.

```swift
db.clearStatementCache()
```

## Transactions

```swift
try db.transaction {
    try db.execute("INSERT INTO items (name) VALUES (?)", [.init("A")])
    try db.execute("INSERT INTO items (name) VALUES (?)", [.init("B")])
}
```

Nested transactions are committed by the outermost transaction. Any thrown error
rolls back the whole transaction.

## Errors

SQLite failures throw `SQLiteError`, including the SQLite result code when one is
available, a message, the SQL string, and the phase that failed.
