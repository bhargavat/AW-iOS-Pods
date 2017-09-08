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
import AWCrypto
import AWStorage

private let ApplicationKeySize = 32
private let SharedContainerKeySize = 32

private let SharedContainerKeyDigestSize = Int(Digest.sha512.digestLength)

internal struct SDKSharedContainerKey: DataRepresentable {
    let keyData: Data
    let keyVerificationData: Data

    var isValidKey: Bool {
        let computedHash = self.keyData.sha512
        let providedHash = self.keyVerificationData
        return computedHash == providedHash
    }

    init?(keySize: Int) {
        guard keySize > 0 else {
            log(warning:"container key size must be greater than 0")
            return nil
        }
        self.keyData = Data.randomData(count: keySize)
        guard let keyVerificationData = self.keyData.sha512 else {
            log(warning:"container key verification data is nil")
            return nil
        }
        self.keyVerificationData = keyVerificationData
    }

    init?(keyData: Data, keyVerificationData: Data) {
        guard keyData.count > 0, keyVerificationData.count > 0 else {
            log(warning: "key data and key verification data cannot be empty")
            return nil
        }
        self.keyData = keyData
        self.keyVerificationData = keyVerificationData
    }

    func toData() -> Data? {
        var data = self.keyVerificationData
        data.append(self.keyData)
        return data
    }

    static func fromData(_ data: Data?) -> SDKSharedContainerKey? {
        guard let data = data else { return nil }
        guard data.count == (SharedContainerKeyDigestSize + SharedContainerKeySize) else { return nil}
        let keyVerificationData = data.subdata(in: 0..<SharedContainerKeyDigestSize)
        let keyData = data.subdata(in: SharedContainerKeyDigestSize..<data.count)

        guard let sharedKey = SDKSharedContainerKey(keyData: keyData, keyVerificationData: keyVerificationData) else {
            return nil
        }
        if sharedKey.isValidKey {
            log(verbose: "Successfully parsed container key from the given data")
            return sharedKey
        }

        log(error: "Unable to decrypt the Container Key with provided data. Key Verification failed")
        return nil
    }
}

extension AbstractDataStoreItemLoader {

    public var applicationKey: Data? {
        mutating get {
            guard AWController.sharedInstance.canAccessProtectedData() else {
                log(error: "Trying to access Application key while Store is locked")
                return nil
            }

            let existingApplicationKey: Data? = self.masterDataStore.fetch(itemQueryProvider.AppKey)
            if let existingKey = existingApplicationKey {
                return existingKey
            }

            let generatedKey = Data.randomData(count: ApplicationKeySize)
            self.applicationKey = generatedKey
            return generatedKey
        }

        set {
            _ = self.masterDataStore.set(itemQueryProvider.AppKey, value: newValue)
        }
    }

    public var sharedContainerKey: Data? {
        mutating get {

            guard AWController.sharedInstance.canAccessProtectedData() else {
                log(error: "Trying to access Container key while Store is locked")
                return nil
            }

            let existingSharedKey: SDKSharedContainerKey? = self.masterDataStore.fetch(itemQueryProvider.SharedContainerKey)
            if let existingKey = existingSharedKey {
                log(debug: "Returning previously generated shared container key")
                return existingKey.keyData
            }

            log(info: "Shared Container Key was never generated for this Container or can not parse the existing key for current container. Going to generate a new one.")

            guard let generatedKey = SDKSharedContainerKey(keySize: SharedContainerKeySize), generatedKey.isValidKey else{
                log(error: "Cannot generate a valid key for shared container. Returning nil")
                return nil
            }

            _ = self.masterDataStore.set(itemQueryProvider.SharedContainerKey, value: generatedKey)
            return generatedKey.keyData
        }

        set {
            let clearingContainerKey = (newValue != nil) ? "new value" : "clearing value"
            log(info: "Setting new shared container key. \(clearingContainerKey)")
            var containerKey: SDKSharedContainerKey? = nil
            if let newKey = newValue {
                containerKey = SDKSharedContainerKey(keyData: newKey, keyVerificationData: newKey.sha512 ?? Data())
            }
            _ = self.masterDataStore.set(itemQueryProvider.SharedContainerKey, value: containerKey)
        }
    }


}

extension Data {

    internal var hasValidApplicationKeySize: Bool {
        return self.count == ApplicationKeySize
    }

}
