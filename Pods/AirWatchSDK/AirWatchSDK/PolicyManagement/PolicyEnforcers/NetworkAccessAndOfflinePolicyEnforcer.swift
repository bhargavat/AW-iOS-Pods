//
//  NetworkAccessPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWLocalization
import AWPresentation
import Foundation

private class ServerDetailsController: SDKServerDetailsController, SDKServerDetailsControllerDelegate {

    var presenter: SDKQueuePresenter
    var dataSource: SDKServerDetailsControllerDatasource?
    var delegate: SDKServerDetailsControllerDelegate?

    init(presenter: SDKQueuePresenter, dataStore: SDKContext) {
        self.presenter = presenter
        self.dataSource = dataStore
        self.delegate = self
    }

}

class NetworkAccessAndOfflinePolicyEnforcer: PolicyEnforcementOperation {
    // this class uses two payloadTypes and so we must implement payloadType so to not crash
    override var payloadType: String { return "NetworkAccessAndOfflinePolicy" }

    override func enforce() throws {
        let networkStatusManager = NetworkConnectivityStatusManager.sharedInstance
        networkStatusManager.offlineAccessSettings = self.profile?.offlineAccessPayload
        networkStatusManager.networkAccessSettings = self.profile?.networkAccessPayload
        networkStatusManager.reachabilityCheckHostname = self.dataStore.consoleServicesConfig?.airWatchServerURL
        
        networkStatusManager.networkActivtyStatusUpdateHandler = {(_ status: AWSDK.NetworkActivityStatus) in
            switch status {
            case .proxySetupFailed:
                fallthrough
            
            case .connectedToUnknownSSID:
                fallthrough
            
            case .cellularDataConnectionDisabled:
                fallthrough
            
            case .cellularDataConnectionDisabledWhileRoaming:
                let bridgedStatus = AWSDK.NetworkActivityStatus(rawValue: status.rawValue) ?? .unknown
                AWController.sharedInstance.delegate?.applicationShouldStopNetworkActivity?(reason: bridgedStatus)

            case .normal:
                AWController.sharedInstance.delegate?.applicationCanResumeNetworkActivity?()                
                
            case .networkNotReachable: fallthrough
            case .unknown: fallthrough
            default:
                log(error: "Network Connectivity Status manager current Status: \(status)")
            }
        }
        let sdkController = self.sdkController
        networkStatusManager.offlineAccessBlockHandler = { [weak self] (_ shouldBlockAccess: Bool) in
            if shouldBlockAccess {
                sdkController.presenter.displayBlocker(message: AWSDKLocalization.getLocalizationString("OfflineAccessNotAllowed"))
            } else {
                self?.enforcementComplete()
                ///the blocker view is within SDKWindowType.background, not SDKWindowType.blocker
                sdkController.presenter.dismiss(SDKWindowType.blocker)
            }
        }
        
        networkStatusManager.refresh()
    }

}
