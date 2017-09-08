//
//  AbstractKeyValueStoreItemQuery.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//
import Foundation
import AWStorage

public protocol AbstractKeyValueStoreItemQuery {
    var group: String { get }
    var key: String { get }
    init (group: String, key: String)

    var SessionItem: Self { get }
    var LegacyItem: Self? { get }
}

public extension AbstractKeyValueStore {
    
    public func fetch<DR: DataRepresentable, ItemQuery: AbstractKeyValueStoreItemQuery>(_ query: ItemQuery) -> DR? {
        return self.get(query.group, key: query.key)
    }

    public mutating func set<DR: DataRepresentable, ItemQuery: AbstractKeyValueStoreItemQuery>(_ query: ItemQuery, value: DR?) -> Bool {
        return self.set(query.group, key: query.key, value: value)
    }
}


extension AbstractKeyValueStoreItemQuery {

    var SessionItem: Self {
        return Self(group: self.group, key: "\(self.key).session")
    }

    var LegacyItem: Self? {
        if self.key.hasSuffix(".v1") {
            return Self(group: self.group, key: key.replacingOccurrences(of: ".v1", with: ""))
        }
        return nil
    }
}
