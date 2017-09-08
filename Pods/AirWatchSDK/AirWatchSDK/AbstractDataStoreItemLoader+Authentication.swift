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
import AWServices

extension AbstractDataStoreItemLoader {

    var enrollmentAccount: AWEnrollmentAccount? {
        get {
            return self.masterDataStore.fetch(itemQueryProvider.EnrollmentAccount)
        }
        set {
            _ = self.masterDataStore.set(itemQueryProvider.EnrollmentAccount, value: newValue)
        }

    }

    var username: String? {
        get {
            return self.vendorStore.fetch(itemQueryProvider.Username)
        }
        set {
            _ = self.vendorStore.set(itemQueryProvider.Username, value: newValue)
        }
    }

    var appliedAuthenticationPayload: AuthenticationPayload? {
        get {
            let data: Data? = self.commonDataStore.fetch(itemQueryProvider.AuthenticationPayload)
            let payloadDict = NSDictionary.fromData(data)
            if let dict = payloadDict  as? [String: AnyObject] {
                return AuthenticationPayload(dictionary: dict)
            }
            return nil
        }
        set {
            var data: Data? = nil
            if let dict  = newValue?.toDictionary() {
                data = (dict as NSDictionary).toData()
            }
            _ = self.commonDataStore.set(itemQueryProvider.AuthenticationPayload, value: data)
        }
    }

    var appliedAuthenticationPayloadIdentifier: String? {
        get {
            return self.SSOStore.fetch(itemQueryProvider.AuthenticationPayloadIdentifier)

        }

        set {
            _ = self.SSOStore.set(itemQueryProvider.AuthenticationPayloadIdentifier, value: newValue)
        }
    }

}
