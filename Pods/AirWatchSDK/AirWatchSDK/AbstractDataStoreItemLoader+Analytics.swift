//
//  Abstract.swift
//  AirWatchSDK
//
//  Copyright © 2017 VMWare, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension KeyValueStoreItemQueryProvider {

    var AnalyticsIdentifier:KeyValueStoreItemQuery {
        return KeyValueStoreItemQueryProvider.sharedItem.createQuery(group: .CommonDetails, key: .ApplicationAnalyticsIdentifier)
    }
}

extension AbstractDataStoreItemLoader {

    var sharedApplicationAnalyticsIdentifier: String {
        var store = self.commonDataStore
        if let analyticsId: String = store.fetch(itemQueryProvider.AnalyticsIdentifier) {
            return analyticsId
        }

        let generatedIdentifier = UUID().uuidString
        _ = store.set(itemQueryProvider.AnalyticsIdentifier, value: generatedIdentifier)
        return generatedIdentifier
    }

}
