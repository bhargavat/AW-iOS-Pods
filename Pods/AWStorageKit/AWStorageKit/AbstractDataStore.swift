//
//  KeychainQueryMetadata.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

public protocol AbstractKeyValueStore {

    var cryptor: StoreCryptor? { get set }

    @discardableResult
    mutating func clearGroup(_ groupName: String) -> Bool

    func get<DR: DataRepresentable>(_ group: String, key: String) -> DR?

    @discardableResult
    mutating func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?) -> Bool

    func getlastUpdatedTimestamp(_ group: String, key: String) -> TimeInterval?
}

public protocol AbstractAsyncKeyValueStore
{
    func get<DR:DataRepresentable>(_ group: String, key: String, withCompletionHandler completionBlock: @escaping (_ success: Bool, _ data:DR?, _ error: NSError?) -> Void)

    mutating func set<DR: DataRepresentable>(_ group: String, key: String, value: DR?, withCompletionHandler completionBlock: @escaping (_ success: Bool, _ error: NSError?) -> Void) -> Void
}
