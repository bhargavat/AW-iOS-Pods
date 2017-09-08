//
//  SQLiteDataStore.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


private let CreateTableSQL: String = "CREATE TABLE IF NOT EXISTS '%@'(id INTEGER PRIMARY KEY AUTOINCREMENT, key TEXT, value BLOB)"
private let RetrieveValueFormatSQL: String = "SELECT value FROM '%@' WHERE key = \'%@\'"
private let InsertValueFormatSQL: String = "INSERT INTO '%@'(key, value) VALUES(\"%@\", ?)"
private let UpdateValueFormatSQL: String = "UPDATE '%@' SET VALUE = ? WHERE key = \'%@\'"
private let DeleteValueFormatSQL: String = "DELETE FROM '%@' WHERE key = \'%@\'"
private let AllValueFormatSQL: String = "Select key, value FROM '%@'"
private let ClearFormatSQL: String = "DROP TABLE IF EXISTS '%@'"

private let SQLITE_STATIC = unsafeBitCast(0, to: sqlite3_destructor_type.self)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)


public protocol AbstractSQLiteDataStore: AbstractKeyValueStore {
    var database: OpaquePointer? { get set }
    var group: String { get set }
}

public extension AbstractSQLiteDataStore {

    internal func open(_ sqliteFilePath: String) -> OpaquePointer? {
        var database: OpaquePointer? = nil
        let openDB = sqlite3_open(sqliteFilePath, &database)
        if openDB != SQLITE_OK || database == nil {
            let message = "Open/Create DB failed: \(openDB)"
            AWLogError(message)
            return nil
        }
        return database
    }

    internal func close() -> Bool {
        if sqlite3_close( database ) != SQLITE_OK {
            if let message = String(validatingUTF8: sqlite3_errmsg(database)) {
                AWLogError("Close Database failed with error: \(message)")
            }
            return false
        }
        return true
    }

    internal func createTableIfNotExists(_ tableName: String) -> Bool {
        sqlite3_mutex_enter(sqlite3_db_mutex(self.database))
        defer {
            sqlite3_mutex_leave(sqlite3_db_mutex(self.database))
        }

        let sql = String(format: CreateTableSQL, tableName)
        if sqlite3_exec(self.database, sql, nil, nil, nil) != SQLITE_OK {
            if let message = String(validatingUTF8: sqlite3_errmsg(self.database)) {
                AWLogError("Create table\(tableName) failed with error: \(message)")
            }
            return false
        }

        return true
    }

    func get<DR: DataRepresentable>(_ group: String, key: String) -> DR? {
        guard key.characters.count != 0 else { return nil }
        guard group.characters.count != 0 else { return nil }
        let data = getData(group, key: key)
        if let decryptor = cryptor {
            return decryptor.decryptObject(data)
        }
        return DR.fromData(data)
    }

    @discardableResult mutating func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?) -> Bool {
        guard key.characters.count != 0 else { return false }
        guard group.characters.count != 0 else { return false }
        var givenData = value?.toData()
        if let encryptor = cryptor {
            givenData = encryptor.encryptObject(value)
        }
        return self.setData(group, key: key, data: givenData as Data?)
    }


    internal func setData( _ table: String, key: String, data: Data? ) -> Bool {
        if data == nil {
            return deleteData(table, key: key)
        }

        _ = createTableIfNotExists(table)
        var querySQL = String(format: InsertValueFormatSQL, table, key )
        if getData(table, key: key) != nil {
            querySQL = String(format: UpdateValueFormatSQL, table, key )
        }
        
        var bytes:[UInt8] = []
        if let data = data {
            var dataBytes = [UInt8](repeating: 0x00, count: data.count)
            data.copyBytes(to: &dataBytes, count: dataBytes.count)
            bytes = dataBytes
        }

        var statement: OpaquePointer? = nil
        sqlite3_mutex_enter(sqlite3_db_mutex(self.database))
        defer {
            sqlite3_mutex_leave(sqlite3_db_mutex(self.database))
        }


        if sqlite3_prepare_v2(self.database, querySQL, -1, &statement, nil) != SQLITE_OK {
            sqlite3_finalize(statement)
            AWLogError("Setting Data failed with message: \(String(cString: sqlite3_errmsg(self.database))) ")
            return false
        }

        if sqlite3_bind_blob(statement, 1, bytes, Int32(bytes.count), SQLITE_TRANSIENT ) != SQLITE_OK {
            AWLogError("Setting Data failed with message: \(String(cString: sqlite3_errmsg(self.database))) ")
            return false
        }

        if sqlite3_step(statement) != SQLITE_DONE {
            if let message = String(validatingUTF8: sqlite3_errmsg(self.database)) {
                AWLogError("Setting Data failed with message: \(message)")
            }
            return false
        }

        sqlite3_finalize(statement)
        return true
    }

    internal func getData(_ table: String, key: String ) -> Data? {
        var data: Data?

        let querySQL = String(format: RetrieveValueFormatSQL, table, key )

        var statement: OpaquePointer? = nil
        sqlite3_mutex_enter(sqlite3_db_mutex(self.database))
        defer {
            sqlite3_mutex_leave(sqlite3_db_mutex(self.database))
        }

        if sqlite3_prepare_v2(self.database, querySQL, -1, &statement, nil) != SQLITE_OK {
            AWLogError("Failed to Get Data with message: \(String(cString: sqlite3_errmsg(self.database))) ")
            return nil
        }

        while sqlite3_step(statement) == SQLITE_ROW {
            let settingDataLength = sqlite3_column_bytes(statement, 0)
            if let settingData = sqlite3_column_blob(statement, 0) {
                data = Data(bytes: UnsafeRawPointer(settingData), count: Int(settingDataLength))
            }
            break
        }
        sqlite3_finalize(statement)
        return data
    }

    internal func deleteData(_ table: String, key: String ) -> Bool {
        let querySQL = String(format: DeleteValueFormatSQL, table, key )
        sqlite3_mutex_enter(sqlite3_db_mutex(self.database))
        defer {
            sqlite3_mutex_leave(sqlite3_db_mutex(self.database))
        }

        if sqlite3_exec(self.database, querySQL, nil, nil, nil) != SQLITE_OK {
            AWLogError("Failed to Set Data with message: \(String(cString: sqlite3_errmsg(self.database))) ")
            return false
        }
        return true
    }

    @discardableResult mutating func clearGroup(_ groupName: String) -> Bool {
        let querySQL = String(format: ClearFormatSQL, groupName )
        sqlite3_mutex_enter(sqlite3_db_mutex(self.database))
        defer {
            sqlite3_mutex_leave(sqlite3_db_mutex(self.database))
        }

        if sqlite3_exec(self.database, querySQL, nil, nil, nil) != SQLITE_OK {
            AWLogError("Clear Store failed with error: \(String(cString: sqlite3_errmsg(self.database))) ")
            return false
        }
        return createTableIfNotExists(groupName)
    }

    func getlastUpdatedTimestamp(_ group: String, key: String) -> TimeInterval? {
        return  nil
    }
}
