//
//  FetchConfigurationProfileOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

internal class ApplyNonAuthenticatedSettingsOperation: SDKSetupAsyncOperation {
    
    override func startOperation() {
        
        let enforcementOperations: [PolicyEnforcementOperation.Type] = [NetworkAccessAndOfflinePolicyEnforcer.self,
                                                                        LoggingPolicyEnforcer.self,
                                                                        DataCollectionPolicyEnforcer.self,
                                                                        RestrictionsPolicyEnforcer.self,
                                                                        BrandingPolicyEnforcer.self]

        let enforcers = createOperationGroup(enforcementOperations)
        SDKOperationQueue.workerQueue.addOperations(enforcers, waitUntilFinished: true)
        
        enforcers.forEach { (enforcer: PolicyEnforcementOperation) in
            let name = enforcer.name ?? "Unknown Policy"

            switch enforcer.enforcementStatus {
            case .enforcementComplete:
                log(info: "Successfully Enforced: \(name)")

            case .enforcementNotStarted:
                log(info: "Not Enforced: \(name) cancelled?: \(enforcer.isCancelled)")

            case .enforcementInProgress:
                log(info: "Enforcement In Progress: \(name) cancelled?: \(enforcer.isCancelled)")

            case .enforcementFailed(let error):
                log(info: "Enforement Failed:  \(name) with error: \(error)")
            }
        }        
        self.markOperationComplete()
    }
}


internal class ApplyAuthenticatedSettingsOperation: SDKSetupAsyncOperation {

    override func startOperation() {

        guard self.dataStore.SDKProfile != nil else {
            log(error: "Can not enforce empty SDK profile even for Apply Non-Authenticated Settings Operation")
            self.markOperationFailed()
            return
        }

        guard self.dataStore.applicationIdentity?.authorization != nil else {
            log(error: "Application Identity is required to setup proxy, IA and Data at rest encryption")
            self.markOperationFailed()
            return
        }

        let policiesToEnforce: [PolicyEnforcementOperation.Type] = [ProxyPolicyEnforcer.self,
                                                                    IdentityPolicyEnforcer.self,
                                                                    AuthenticationPolicyEnforcer.self]

        let enforcers = createOperationGroup(policiesToEnforce)
        SDKOperationQueue.workerQueue.addOperations(enforcers, waitUntilFinished: true)

        enforcers.forEach { (enforcer: PolicyEnforcementOperation) in
            let name = enforcer.name ?? "Unknown Policy"

            switch enforcer.enforcementStatus {
            case .enforcementComplete:
                log(info: "Successfully Enforced: \(name) successfully")

            case .enforcementNotStarted:
                log(info: "Not Enforced: \(name) cancelled?: \(enforcer.isCancelled)")

            case .enforcementInProgress:
                log(info: "Enforcement In Progress: \(name) cancelled?: \(enforcer.isCancelled)")

            case .enforcementFailed(let error):
                log(info: "Enforement Failed:  \(name) with error: \(error)")
            }
        }
        self.markOperationComplete()
    }
}
