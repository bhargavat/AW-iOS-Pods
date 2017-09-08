    //
//  CheckPasscodeValidation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWPresentation

class PasscodeValidation: PasscodeValidationProtocol {
    //NOTE: Reason numberOfFailedPasscodeUnlockAttempts, maximumFailedAttemptsAllowed, and isPasscodeValid is wrapped is for simplification of unit testing logic rather than mocking all those individual objects
    
    var dataStore: SDKContext
    internal var numberOfFailedPasscodeUnlockAttempts: Int {
        get {
            return self.dataStore.failedPasscodeUnlockAttempts
        }
        set {
            self.dataStore.failedPasscodeUnlockAttempts = newValue
        }
    }
    /** 
     @brief Get authentication's payload value for max failed attempts allowed, if nil the value 4 is returned
     @description Console in the past has returned a null authenticationPayload and the minimum setting on console is 4 and thus this default will be returned
     @return If the SDKProfile or authenticationPalyoad is nil, then 4 is returned
     */
    internal var maximumFailedAttemptsAllowed: Int {
        get {
            return self.dataStore.SDKProfile?.authenticationPayload?.maximumFailedAttempts ?? 4
        }
    }
    
    init(dataStore: SDKContext) {
        self.dataStore = dataStore
    }

    func isValid(passcode: String) -> Bool{
        return self.dataStore.isValid(passcode: passcode)
    }
    
    /**
     This function will validate the passcode against storage and if depending on the number of failed attempts is made, then two possible exceptions may be thrown.
     Exceptions:
     - When max attempts has been reached, then SDKPresenterError.ValidationThrowsException is thrown
     - When max - 1 failed attempts has been reached, then SDKPresenterError.ValidationTimeoutException is thrown

     If the function is called with the correct passcode, then the failed attempts is reset to 0 and the function returns true, else if the passcode is wrong the function returns false
     */
    func validatePasscode(_ passcode: String) -> PasscodeValidationResult {
        let isPasscodeValid = self.isValid(passcode: passcode)
        let failedAttempts = self.numberOfFailedPasscodeUnlockAttempts
        
        if isPasscodeValid && failedAttempts < self.maximumFailedAttemptsAllowed {
            return PasscodeValidationResult.ok
        }
        
        if failedAttempts == self.maximumFailedAttemptsAllowed {
            return PasscodeValidationResult.maxFailedAttemptsMade
        }
        if failedAttempts <= self.maximumFailedAttemptsAllowed {
            return PasscodeValidationResult.wrongPasscode
        }
        // Just in case something goes terrible wrong we'll handle the case that they attempted too many times
        else {
            return PasscodeValidationResult.maxFailedAttemptsMade
        }
    }
    
}
