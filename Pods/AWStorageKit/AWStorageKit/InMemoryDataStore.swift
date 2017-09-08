//
//  InMemoryDataStore.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation


public protocol InMemoryDataStore: AbstractKeyValueStore {
    var store: [String: [String: Data]] { get set}
}

public extension InMemoryDataStore {
    @discardableResult mutating func clearGroup(_ group: String) -> Bool {
        self.store[group] = nil
        return true
    }

    func get<DR: DataRepresentable>(_ group: String, key: String) -> DR? {
        guard key.characters.count != 0 else { return nil }
        guard group.characters.count != 0 else { return nil }
        return DR.fromData(self.store[group]?[key])
    }

    @discardableResult mutating func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?) -> Bool {
        guard key.characters.count != 0 else { return false }
        guard group.characters.count != 0 else { return false }

        if let setValue = value?.toData() {
            var table = self.store[group] ?? [:]
            table[key] = setValue as Data
            self.store[group] = table
            return true
        } else if value == nil {
            self.store[group]?[key] = nil
            return true
        }
        return false
    }


    func getlastUpdatedTimestamp(_ group: String, key: String) -> TimeInterval? {
        return nil
    }
}
