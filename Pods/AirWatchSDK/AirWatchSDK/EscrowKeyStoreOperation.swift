//
//  KeyEscrowOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

extension ApplicationDataStore {

    var cryptKeyWaitingToEscrow: Data? {
        get {
            return self.masterDataStore.fetch(itemQueryProvider.CryptKeyToEscrow)
        }
        set {
            _ = self.masterDataStore.set(itemQueryProvider.CryptKeyToEscrow, value: newValue)
        }
    }
}

class EscrowKeyStoreOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        log(debug: "➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸➸")
        log(debug: "Starting Escrow Store Key operation:")
        log(debug: "Enabled Single Sign On: \(self.dataStore.enabledSingleSignOn)")
        log(debug: "Profile says single sign on is enabled: \(self.dataStore.profileRequiredSingleSignOn)")

        let shouldEscrowPasscode = self.dataStore.needToEscrowPasscode
        guard shouldEscrowPasscode else {
            log(info: "Passcode Escrow not needed!")
            self.markOperationComplete()
            return
        }
        guard let applicationDataStore = self.dataStore as? ApplicationDataStore else {
            log(error: "Current store is not Application data Store can not retrieve the key. failing the operation")
            self.markOperationFailed()
            return
        }


        guard let cryptKeyRequiredToEscrow = applicationDataStore.cryptKeyWaitingToEscrow else {
            log(error: "There is no Crypt Key stored in Application Data Store. Either No crypt Key is available(highly unlikely) or key have already been escrowed")
            self.markOperationFailed()
            return
        }
        
        log(info: "Trying to Escrow the key to the server.")
        let passcodeToEscrow = self.createPayloadForKeyEscrow(cryptKey: cryptKeyRequiredToEscrow)
        let deviceServices = self.dataStore.profileRequiredSingleSignOn ? self.dataStore.commonDeviceServices : self.dataStore.deviceServices
        guard let services = deviceServices else {
            log(error: "Can not escrow Key as Device Services are empty")
            self.dataStore.needToEscrowPasscode = true
            self.markOperationComplete()
            return
        }
        
        services.storeKeyWithEscrowService(EscrowStoreKey: passcodeToEscrow, enrollmentUserId: "-1") { [weak self] (isEscrowKeyStored, error) in
            if let error  = error {
                 log(error: "Error Escrowing Key to Server: \(error)" )
                self?.markOperationComplete()
                return
            }

            log(error: "Key Escrowed To Server Successfully: \(isEscrowKeyStored)" )
            self?.dataStore.needToEscrowPasscode = !isEscrowKeyStored
            if isEscrowKeyStored {
                applicationDataStore.cryptKeyWaitingToEscrow = nil
            }
            self?.markOperationComplete()
        }
    }

    private func createPayloadForKeyEscrow(cryptKey: Data) -> EscrowKey {
        struct EscrowPasscodeKey: EscrowKey {
            var usage = AWServices.KeyStoreUser.sdk
            var algorithm = AWServices.KeyAlgorithm.AES256
            var keyData: Data
        }
        return EscrowPasscodeKey(usage: AWServices.KeyStoreUser.sdk, algorithm: AWServices.KeyAlgorithm.AES256, keyData: cryptKey)
    }

}
