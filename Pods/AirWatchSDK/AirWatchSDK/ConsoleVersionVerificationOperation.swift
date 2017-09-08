//
//  ConsoleVersionVerificationOperation.swift
//  AirWatchSDK
//
//  Copyright © 2017 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWError

internal class ConsoleVersionVerificationOperation: SDKSetupAsyncOperation {
    
    internal override func startOperation() {
        guard self.checkMinimumConsoleVersionMeetsRequirement() else {
            self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.consoleVersionNotCompatible)
            self.markOperationFailed()
            return
        }
        
        self.markOperationComplete()
    }
    
    
    /**
     If the application is an AW application, then true is returned because AW apps are compatible with all versions
     If EnrollmentInformation's last known console version is nil, then this function will return false
     If a last known version has been found, compare that with ConsoleVersion.minimumSupportedVersion()
     */
    internal func checkMinimumConsoleVersionMeetsRequirement() -> Bool {
        if AWAnchor.isCurrentApplicationAirWatchApplication {
            return true
        }
        
        guard let currentConsoleVersion = self.dataStore.consoleVersion else {
            return false
        }
        
        return currentConsoleVersion >= ConsoleVersion.minimumSupportedVersion
    }
}
