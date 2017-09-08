//
//  IdentityPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWError
import AWServices

class IdentityPolicyEnforcer: PolicyEnforcementOperation {

    override var payloadType: String { return IdentityPayload.type }

    var identityPayload: IdentityPayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {
        
        guard let authPayload = self.profile?.authenticationPayload else {
            log(error: "No auth payload present. Completing enforcement")
            self.enforcementComplete()
            return
        }
        
        guard authPayload.enableIntegratedAuthentication else {
            log(info: "IntegratedAuthentication is not enabled. Completing enforcement")
            self.enforcementComplete()
            return
        }
        
        guard let identitypayload = self.identityPayload else {
            log(info: "No identity payload present. Completing enforcement")
            self.enforcementComplete()
            return
        }
        
        guard let guid = identityPayload?.guid, guid.isEmpty == false else {
            log(error: "Not a valid identity payload guid missing. Completing enforcement")
            self.enforcementComplete()
            return
        }
        
        guard let token = identityPayload?.issuerToken,
            token.isEmpty == false else {
            log(error: "Not a valid identity payload token missing. Completing enforcement")
            self.enforcementComplete()
            return;
        }
        
        let store = CertificateStore(with: dataStore)
        store.allowedSites = authPayload.allowedSites

        //verify if certs are already downloaded,
        if store.certificateIssuerExists(guid) {
            log(info: "No need to fetch, certificate already present")
            self.enforcementComplete()
            return
        }

        //delete current certificates if exist
        store.clearCert()

        //fetch new certificates
        store.fetchCertificates(forIdentity: identitypayload) { [weak self] (success, _ , error) in
            
            guard let weakSelf = self else {
                log(error: "IdentityPolicyEnforcer self was not found")
                return
            }
            guard success, error == nil else {
                log(error: "Failed to fetch IA client certificates")
                weakSelf.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.integratedAuthenticationCertificatesNotDownloaded)
                weakSelf.enforcementComplete(AWSDKError.Setup.integratedAuthenticationCertificatesNotDownloaded)
                return
            }

            log(info: "Fetched IA client certififcates successfully")
            weakSelf.enforcementComplete()
        }

    }
    
}
