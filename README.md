# SQLiteWrapper

SQLiteWrapper is a small synchronous Swift wrapper around SQLite.

It keeps SQL visible, while adding typed parameter binding, typed row reads,
statement reuse, transactions, and structured SQLite errors.

## Usage

```swift
import SQLiteWrapper

let db = try Connection(options: .default)

try db.execute("CREATE TABLE items (id INTEGER PRIMARY KEY, name TEXT, note TEXT)")
try db.execute(
    "INSERT INTO items (name, note) VALUES (?, ?)",
    ["Keyboard", Optional<String>.none]
)

let rows = try db.rows("SELECT id, name, note FROM items ORDER BY id")
for row in rows {
    let id = try row.value(0, as: Int.self)
    let name = try row.value(1, as: String.self)
    let note = try row.value(2, as: String?.self)
    print(id, name, note as Any)
}
```

## Scalar Values

```swift
let count = try db.scalar("SELECT COUNT(*) FROM items", as: Int.self)
```

## Prepared Statements

```swift
let statement = try db.query("SELECT name FROM items WHERE id = ?", [1])
let row = try statement.fetchRow()
let name = try row?.value(0, as: String.self)
```

Statements are cached by SQL string inside `Connection`. Clear the cache before
reusing SQL across schema changes.

```swift
db.clearStatementCache()
```

## Transactions

```swift
try db.transaction {
    try db.execute("INSERT INTO items (name) VALUES (?)", ["A"])
    try db.execute("INSERT INTO items (name) VALUES (?)", ["B"])
}
```

Nested transactions are committed by the outermost transaction. Any thrown error
rolls back the whole transaction.

## Errors

SQLite failures throw `SQLiteError`, including the SQLite result code when one is
available, a message, the SQL string, and the phase that failed.
