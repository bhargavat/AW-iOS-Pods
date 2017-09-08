//
//  DefaultCryptKeyMaker.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWCrypto
import AWStorage

protocol DefaultKeyMaker: CryptKeyMaker {

    var defaultPin: String? { get set }

    var defaultCryptKey: Data? { get }

    mutating func createDefaultPasscode()

}

extension DefaultKeyMaker {

    var defaultPin: String? {
        get {
            let fetchedData: Data? = self.datastore.fetch(itemQueryProvider.DefaultPasscode)
            let defaultPin = fetchedData?.base64EncodedString(options: Data.Base64EncodingOptions.lineLength64Characters)
            log(debug: "Fetching Default Passcode from datastore (\(self.datastore)).")
            return defaultPin
        }
        set {
            _ = self.datastore.set(itemQueryProvider.DefaultPasscode, value: newValue)
        }
    }

    var defaultCryptKey: Data? {
        if let _ = self.getCryptKeySalt(),
            let pin = self.defaultPin {
            return self.cryptKeyWithPin(pin)
        }
        return nil
    }

    mutating func createDefaultPasscode() {

        if self.getCryptKeySalt() == nil {
            _ = self.createCryptKeySalt()
        }

        if self.defaultPin == nil {
            self.defaultPin = nil
            self.defaultPin = UUID().uuidString
        }
    }
}

struct DefaultKeyProvider: DefaultKeyMaker {
    var itemQueryProvider: KeyValueStoreItemQueryProvider
    var datastore: AbstractKeyValueStore
}
