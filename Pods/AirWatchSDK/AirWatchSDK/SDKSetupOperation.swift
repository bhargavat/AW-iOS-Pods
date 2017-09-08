//
//  SDKSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension SDKSetupAsyncOperation {
    func createOperation<T : SDKSetupAsyncOperation>() -> T {
        return T(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
    }
}

class SDKSetupOperation: SDKSetupAsyncOperation {
    
    public private(set) static var sdkSetupInProgress = false

    @discardableResult
    private func performOperation(type OperationType: SDKOperation.Type, shouldCallSetupComplete: Bool = true) -> Bool {
        let operation = OperationType.init(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore)
        let operationName = operation.name ?? "\(OperationType)"
        log(debug: "--------------------------------------------------------------------------------------------------------------")
        log(debug: "Starting: \(operationName)")
        SDKOperationQueue.workerQueue.addOperations([operation], waitUntilFinished: true)
        log(debug: "Completed: \(operationName): \(operation.operationCompletedSuccessfully ? "Success" : "Failed")" )
        log(debug: "--------------------------------------------------------------------------------------------------------------")

        if self.isCancelled {
            self.markOperationFailed()
            log(debug: "SDKSetupOperation is cancelled.")
            return false
        }
        
        if operation.operationCompletedSuccessfully == false && shouldCallSetupComplete {
            if self.sdkController.sdkSetupOperationError == nil {
                self.sdkController.sdkSetupOperationError = .internalError
            }
            self.sdkController.updateDelegateBasicCheckDone()
            self.markOperationFailed()
            return false
        }
        
        return operation.operationCompletedSuccessfully
    }

    @discardableResult
    private func performConcurrentOperations(type OperationTypes: [SDKOperation.Type], shouldCallSetupComplete: Bool = true) -> Bool {
        let operations = OperationTypes.map { $0.init(sdkController: self.sdkController, presenter: self.presenter, dataStore: self.dataStore) }
        let operationName = operations.map { $0.name ?? String(describing: $0) }
        log(debug: "--------------------------------------------------------------------------------------------------------------")
        log(debug: "Concurrently starting: \(operationName)")
        SDKOperationQueue.workerQueue.addOperations(operations, waitUntilFinished: true)
        operations.forEach { (operation) in
            log(debug: "Completed: \(operation.name ?? String(describing: operation)): \(operation.operationCompletedSuccessfully ? "Success" : "Failed")" )
        }
        log(debug: "--------------------------------------------------------------------------------------------------------------")
        let failedOperations = operations.filter{ $0.operationCompletedSuccessfully == false }

        if self.isCancelled {
            self.markOperationFailed()
            log(debug: "SDKSetupOperation is cancelled. Will exit setup!")
            return false
        }

        if failedOperations.count > 0 && shouldCallSetupComplete {

            if self.sdkController.sdkSetupOperationError == nil {
                self.sdkController.sdkSetupOperationError = .internalError
            }
            self.sdkController.updateDelegateBasicCheckDone()
            self.markOperationFailed()
            return false
        }

        return failedOperations.count == 0
    }


    override func startOperation() {
        log(debug: "🚦🚦🚦 Started SDK(v\(self.sdkController.AWSDKVersion))🚦🚦🚦")

        SDKOperationQueue.sharedQueue.maxConcurrentOperationCount = 1
        var informedDelegateAboutInitialCheckCompletion = false

        guard
            self.performConcurrentOperations(type: [JailbreakDetectionOperation.self,
                                                    LogLevelSetupOperation.self,
                                                    CheckPendingUnenrollmentReportOperation.self])
        else { return }


        guard performOperation(type: SDKAccessControlSetupOperation.self) else { return }
        //This will help applications to be back in business faster.

        if self.didSecureApplicationInPreviousLaunch() {
            guard
                self.performConcurrentOperations(type: [ApplyNonAuthenticatedSettingsOperation.self,
                                                        ApplyAuthenticatedSettingsOperation.self])
            else { return }

            informedDelegateAboutInitialCheckCompletion = true
            self.sdkController.updateDelegateBasicCheckDone()
        } else {
            guard performOperation(type: ApplyNonAuthenticatedSettingsOperation.self) else { return }
        }

        guard performOperation(type: EnrollmentInformationVerificationOperation.self) else { return }
        guard performOperation(type: ConsoleVersionVerificationOperation.self) else { return }
        guard performOperation(type: ConfigurationProfilesVerificationOperation.self) else { return }
        guard performOperation(type: ApplyNonAuthenticatedSettingsOperation.self) else { return }
        guard performOperation(type: VerifyApplicationIdentityOperation.self) else { return }
        guard performOperation(type: SDKAccessControlSetupOperation.self) else { return }
        guard performOperation(type: ApplyAuthenticatedSettingsOperation.self) else { return }
        guard performOperation(type: SDKAccessControlSetupOperation.self) else { return }

        if informedDelegateAboutInitialCheckCompletion == false {
            informedDelegateAboutInitialCheckCompletion = true
            self.sdkController.updateDelegateBasicCheckDone()
        }
        
        self.sdkController.updateDelegateThoroughCheckDone()
        self.performConcurrentOperations(type: [EscrowKeyStoreOperation.self,
                                                SendBeaconOperation.self,
                                                PollForSSLCertsToPinOperation.self,
                                                FetchConsoleCommandsOperation.self], shouldCallSetupComplete: false)
        self.markOperationComplete()
        SDKOperationQueue.sharedQueue.maxConcurrentOperationCount = -1
    }
}


fileprivate extension SDKSetupOperation {
    @discardableResult
    fileprivate func didSecureApplicationInPreviousLaunch() -> Bool {

        guard let enrollmentInformation = self.dataStore.enrollmentInformation else {
            log(info: "Missing Enrollment information. Should wait until SDK initialization Completion")
            return false
        }

        guard enrollmentInformation.lastKnownEnrollmentStatus == AWSDK.EnrollmentStatus.enrolled else {
            log(info: "Last Known Enrollment Status: \(enrollmentInformation.lastKnownEnrollmentStatus) is not enrolled. Should wait until SDK initialization Completion")
            return false
        }

        guard self.dataStore.SDKProfile != nil else {
            log(info: "SDK Profile is Empty. Should wait until SDK initialization Completion")
            return false
        }

        guard let applicationIdentity =  self.dataStore.applicationIdentity else {
            log(info: "applicationIdentity is Emtpy. Should wait until SDK initialization Completion")
            return false
        }

        guard applicationIdentity.authorization?.hmacToken != nil else {
            log(info: "Application Identity HMAC Token is Empty. Should wait until SDK initialization Completion")
            return false
        }
        
        return true
    }
}
