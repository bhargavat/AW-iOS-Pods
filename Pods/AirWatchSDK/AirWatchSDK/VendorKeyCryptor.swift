//
//  VendorKeyHelpers.swift
//  AWSecureSharedStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import UIKit
import AWStorage

protocol VendorKeyMaker {
    func generateVendorKey() -> Data?
}

extension VendorKeyMaker {
    func generateVendorKey() -> Data? {
        return UIDevice.current.identifierForVendor?.uuidString.data(using: String.Encoding.utf8)?.sha256
    }
}

public struct VendorKeyCryptor: StoreCryptor, VendorKeyMaker {
    var key: Data? = nil
    public init() {
        self.key = generateVendorKey()
    }

    public func encryptObject<T: DataRepresentable>(_ object: T?) -> Data? {
        guard let key = self.key else { return object?.toData() }
        return SecureDataMessage.defaultMessage.encryptObject(object, key: key)
    }

    public func decryptObject<T: DataRepresentable>(_ data: Data?) -> T? {
        guard let key = self.key else { return T.fromData(data) }
        return SecureDataMessage.decryptObject(data, key: key)
    }
}
