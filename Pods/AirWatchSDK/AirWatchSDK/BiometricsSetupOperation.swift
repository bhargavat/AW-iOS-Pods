//
//  SetupBiometricsOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import LocalAuthentication

public struct BiometricsHelper {
    public static func isTouchIDSupported() -> Bool {
        let context = LAContext()
        var error: NSError? = nil
        let supported = context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error )
        log(info: "policy evaluation for TouchID returned: \(supported) with error: \(String(describing: error))")
        return supported
    }
}

class BiometricsSetupOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        guard BiometricsHelper.isTouchIDSupported() else {
            log(error: "Biometrics is not supported. closing the operations")
            self.markOperationComplete()
            return
        }

        let requiredMethod = self.dataStore.profileRequiredBiometricMethod
        
        if requiredMethod == AWSDK.BiometricMethod.touchID
        {
            self.dataStore.enableTouchIDAuthentication { (success, error) in

                guard success else {
                    log(error: "Biometric error recieved \(error.debugDescription) when attempting to setup touch ID Authentication")
                    self.markOperationFailed()
                    return
                }

                self.dataStore.isTouchIDConfigured = true
                self.dataStore.currentBiometricMethod = requiredMethod
                self.markOperationComplete()
            }
        }
    }
}
