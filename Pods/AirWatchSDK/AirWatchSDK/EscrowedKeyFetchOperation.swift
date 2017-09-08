//
//  KeyFetchOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWError
import Foundation


class EscrowedKeyFetchOperation: SDKSetupAsyncOperation {

    var fetchedCryptKey: Data? = nil
    var error: Error? = nil
    var identity: Identity? = nil


    override func startOperation() {
        guard let authorization = self.identity?.authorization else {
            log(error: "no identity set for escrow operation")
            self.markOperationFailed()
            return
        }

        log(info: "Trying to fetch the key Escrowed to the server.")

        let storeConfig: ConsoleServicesConfig?
        if (self.dataStore.profileRequiredSingleSignOn && authorization.authorizationGroup == IdentityType.common.authenticationGroup) {
            storeConfig = self.dataStore.commonConsoleServicesConfig
        } else {
            storeConfig = self.dataStore.consoleServicesConfig
        }
        
        guard let config = storeConfig else {
            log(error: "console serviceconfig not set, returning")
            self.markOperationFailed()
            return
        }

        let deviceServices = DeviceServices(config: config, authorizer: SDKHMACAuthorizer(identity: identity))
        deviceServices.fetchEscrowedKey(AWServices.KeyStoreUser.sdk, enrollmentUserId: "-1") {[weak self] (keytData, error) in
            guard let fetchOperation = self else {
                log(debug: "Operation is not around. not going to do anything with the result.")
                return
            }

            if let error = error {
                //TODO: Display error here, if there is somethign wrong with network.
                log(debug: "Failed to fetch passcode from server: \(error)")
                self?.error = error
                fetchOperation.markOperationFailed()
                return
            }

            guard let data = keytData else {
                log(debug: "☛ Did not get any key from server. Resetting current key. 🤔")
                self?.error = AWError.SDK.Operation.EscrowedKeyFetch.empty
                fetchOperation.markOperationFailed()
                return
            }

            self?.fetchedCryptKey = data
            fetchOperation.markOperationComplete()
        }
    }

}
