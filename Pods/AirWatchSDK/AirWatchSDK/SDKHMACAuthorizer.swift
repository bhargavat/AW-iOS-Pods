//
//  AuthenticationChallengeHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWNetwork
import AWError
import AWServices

class CommonHMACRefreshOperation: SDKSetupAsyncOperation {

    private(set) var refreshedCommonHMAC = false
    private(set) var refreshError: NSError? = nil

    override func startOperation() {
        log(error: "Going to Refresh Common HMAC due to 403 on registration")
        log(error: "Cleared Enrollment Account to refresh HMAC (on 403 from Console)")
        log(error: "Cleared Common Identity to refresh HMAC (on 403 from Console)")
        self.dataStore.enrollmentAccount = nil
        self.dataStore.commonIdentity?.authorization = nil
        let commonIdentitySetupOperation: CoreIdentitySetupOperation = self.createOperation()
        commonIdentitySetupOperation.requiredIdentityType = .common
        log(info: "Refreshing Common Identity through Core Identity setup operation")

        let currentOptions = AWController.sharedInstance.applicationEventsMonitoringOptions
        AWController.sharedInstance.applicationEventsMonitoringOptions = .sdkSetupInProgressOptions
        SDKOperationQueue.workerQueue.addOperations([commonIdentitySetupOperation], waitUntilFinished: true)
        AWController.sharedInstance.applicationEventsMonitoringOptions = currentOptions

        guard commonIdentitySetupOperation.operationCompletedSuccessfully,
        let identity = commonIdentitySetupOperation.identity,
        let account = commonIdentitySetupOperation.account
        else {
            log(error: "Failed to refresh common identity as well.")
            //Message the user for possible recovery options
            self.refreshedCommonHMAC = false
            self.refreshError = commonIdentitySetupOperation.identitySetupError?.error
            self.markOperationFailed()
            return
        }

        self.dataStore.commonIdentity = identity
        self.dataStore.enrollmentAccount = account
        self.refreshedCommonHMAC = true
        commonIdentitySetupOperation.markOperationComplete()
        self.presenter.dismissNonBlockingViewControllers()
        self.markOperationComplete()
    }
}

class ApplicationHMACRefreshOperation: SDKSetupAsyncOperation {
    private(set) var refreshedApplicationHMAC = false
    private(set) var refreshError: NSError? = nil

    override func startOperation() {
        log(error: "Going to Refresh Application HMAC due to 403 on registration")
        log(error: "Cleared Application Identity to refresh HMAC (on 403 from Console)")
        self.dataStore.applicationIdentity = nil

        let applicationIdentitySetupOperation: ApplicationIdentitySetupOperation = self.createOperation()
        log(info: "Refreshing Common Identity through Core Identity setup operation")
        let currentOptions = AWController.sharedInstance.applicationEventsMonitoringOptions
        AWController.sharedInstance.applicationEventsMonitoringOptions = .sdkSetupInProgressOptions
        SDKOperationQueue.workerQueue.addOperations([applicationIdentitySetupOperation], waitUntilFinished: true)
        AWController.sharedInstance.applicationEventsMonitoringOptions = currentOptions
        
        guard applicationIdentitySetupOperation.operationCompletedSuccessfully
            else {
                log(error: "Failed to refresh Application HMAC.")
                //Message the user for possible recovery options
                self.refreshedApplicationHMAC = false
                self.markOperationFailed()
                return
        }
        self.refreshedApplicationHMAC = true
        DataChangeNotification.HMACRefreshed.post()
        applicationIdentitySetupOperation.markOperationComplete()
        self.presenter.dismissNonBlockingViewControllers()
        self.markOperationComplete()
    }
}

@objc
public class AWHMACSigner: NSObject, HMACAuthorizer {
    public var hmacKey: Data
    public var authGroup: String
    public var deviceId: String
    static let CommonHMACRefreshQueue = DispatchQueue(label: "com.air-watch.authentication.main.refresh")
    static var commonHMACRefreshOperation: CommonHMACRefreshOperation? = nil
    static var commonHMACRefreshCallbackQueue = OperationQueue()

    static let ApplicationHMACRefreshQueue = DispatchQueue(label: "com.air-watch.authentication.application.refresh")
    static var applicationHMACRefreshOperation: ApplicationHMACRefreshOperation? = nil
    static var applicationHMACRefreshCallbackQueue = OperationQueue()

    init?(identity: Identity?) {
        guard let currentIdentity = identity,
            let deviceId = currentIdentity.enrollment?.deviceIdentifier,
            let authGroup = currentIdentity.authorization?.authorizationGroup,
            let hmacToken = currentIdentity.authorization?.hmacToken,
            let hmacTokenData = hmacToken.data(using: String.Encoding.utf8) else {
                return nil
        }

        self.hmacKey = hmacTokenData
        self.authGroup = authGroup
        self.deviceId = deviceId
    }

    public static func sharedSigner() -> AWHMACSigner? {
        return AWHMACSigner(identity: AWController.sharedInstance.context.applicationIdentity)
    }
    
    public typealias HMACRefreshCompletion = (_ refreshedAuthorizer: CTLAuthorizationProtocol?, _ error: NSError?) -> Void
    public func refreshAuthorization(completion: @escaping HMACRefreshCompletion) {
        if self.authGroup == IdentityType.common.authenticationGroup {
            self.refreshCommonHMACToken(completion: completion)
        } else {
            self.refreshApplicationHMACToken(completion: completion)
        }
    }

    private func refreshCommonHMACToken(completion: @escaping HMACRefreshCompletion) {
        SDKHMACAuthorizer.CommonHMACRefreshQueue.sync {
            let operation = SDKHMACAuthorizer.commonHMACRefreshOperation ?? self.createCommonHMACRefreshOperation()
            if SDKHMACAuthorizer.commonHMACRefreshOperation == nil {
                SDKHMACAuthorizer.commonHMACRefreshOperation = operation
                SDKHMACAuthorizer.commonHMACRefreshCallbackQueue.addOperation(operation)
            }

            let callbackOperation = BlockOperation {
                guard operation.refreshedCommonHMAC else {
                    completion(nil, operation.refreshError)
                    return
                }

                guard
                    let commonIdentityHMACInfo = AWController.sharedInstance.context.commonIdentity?.authorization,
                    let refreshedHMACToken = commonIdentityHMACInfo.hmacToken,
                    let token = refreshedHMACToken.data(using: String.Encoding.utf8) else {
                    completion(nil, operation.refreshError)
                    return
                }

                self.hmacKey = token
                completion(self, nil)
            }
            callbackOperation.addDependency(operation)
            callbackOperation.completionBlock = {
                SDKHMACAuthorizer.CommonHMACRefreshQueue.sync {
                    if SDKHMACAuthorizer.commonHMACRefreshCallbackQueue.operationCount == 0 {
                        SDKHMACAuthorizer.commonHMACRefreshOperation = nil
                    }
                }

            }

            SDKHMACAuthorizer.commonHMACRefreshCallbackQueue.addOperation(callbackOperation)
        }
    }

    private func refreshApplicationHMACToken(completion: @escaping HMACRefreshCompletion) {
        SDKHMACAuthorizer.ApplicationHMACRefreshQueue.sync {
            let operation = SDKHMACAuthorizer.applicationHMACRefreshOperation ?? self.createApplicationHMACRefreshOperation()
            if SDKHMACAuthorizer.applicationHMACRefreshOperation == nil {
                SDKHMACAuthorizer.applicationHMACRefreshOperation = operation
                SDKHMACAuthorizer.applicationHMACRefreshCallbackQueue.addOperation(operation)
            }

            let callbackOperation = BlockOperation {
                guard operation.refreshedApplicationHMAC else {
                    completion(nil, operation.refreshError)
                    return
                }

                guard
                    let applicationIdentityHMACInfo = AWController.sharedInstance.context.applicationIdentity?.authorization,
                    let refreshedHMACToken = applicationIdentityHMACInfo.hmacToken,
                    let token = refreshedHMACToken.data(using: String.Encoding.utf8) else {
                        completion(nil, operation.refreshError)
                        return
                }

                self.hmacKey = token
                completion(self, nil)
            }
            callbackOperation.addDependency(operation)
            callbackOperation.completionBlock = {
                SDKHMACAuthorizer.ApplicationHMACRefreshQueue.sync {
                    if SDKHMACAuthorizer.applicationHMACRefreshCallbackQueue.operationCount == 0 {
                        SDKHMACAuthorizer.applicationHMACRefreshOperation = nil
                    }
                }
            }

            SDKHMACAuthorizer.applicationHMACRefreshCallbackQueue.addOperation(callbackOperation)
        }
    }

    private func createCommonHMACRefreshOperation() -> CommonHMACRefreshOperation {
        let controller = AWController.sharedInstance
        return CommonHMACRefreshOperation(sdkController: controller, presenter: controller.presenter, dataStore: controller.context)
    }
    private func createApplicationHMACRefreshOperation() -> ApplicationHMACRefreshOperation {
        let controller = AWController.sharedInstance
        return ApplicationHMACRefreshOperation(sdkController: controller, presenter: controller.presenter, dataStore: controller.context)
    }

    public func signRequest(_ request: NSMutableURLRequest) -> Bool {
        log(debug: " **** Signing HMAC *** for Request: \(request)")
        log(debug: "HMAC: \(String(data: self.hmacKey, encoding: .utf8) ?? "Could not create a string using hmacKey data")")
        request.signatureMethod = "aw-sha256"
        return (self as HMACAuthorizer).signRequest(request)
    }
}

typealias SDKHMACAuthorizer = AWHMACSigner
