//
//  Abstct.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension AbstractDataStoreItemLoader {

    var sharedDataAvailable: Bool {
        mutating get {
            return self.commonIdentity?.authorization != nil
        }
    }

    var sharedKeychainSetup: Bool {
        get {
            if let setup: Bool = self.commonDataStore.fetch(itemQueryProvider.SharedKeychainAvailable) {
                return setup
            }
            return false
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.SharedKeychainAvailable, value: newValue)
        }
    }


    var currentAnchorScheme: String? {
        get {
            return self.commonDataStore.fetch(itemQueryProvider.AnchorScheme)
        }
        set {
            _ = self.commonDataStore.set(itemQueryProvider.AnchorScheme, value: newValue)
        }
    }
}
