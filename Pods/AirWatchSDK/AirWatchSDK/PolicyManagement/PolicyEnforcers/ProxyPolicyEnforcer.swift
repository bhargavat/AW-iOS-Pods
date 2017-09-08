//
//  ProxyPolicyEnforcer.swift
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
import class AWTunnel.AWTunnelService

class ProxyPolicyEnforcer: PolicyEnforcementOperation {
    override var payloadType: String { return SDKProxyPayload.type }

    var forceRestart = false
    
    var proxyPayload: SDKProxyPayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {

        
        guard
            let proxyPayload = self.proxyPayload,
            proxyPayload.redirectTraffic == true
        else {
            log(error: "Can't set up AirWatch tunnel service! No proxy settings are found!")
            log(debug: "No proxy configuration profile is found")
            //TODO: error for enforcement failure
            self.enforcementComplete()
            return
        }
#if sdk_mixpanel_data_collection_enabled
        SDKMixpanelDataCollectionService.sharedInstance?.update(userSetting: SDKSettings.proxyType("\(proxyPayload.proxyType)"))
#endif
        log(debug: "Proxy Payload:\(proxyPayload)")
            
        let deviceSerivces = self.dataStore.profileRequiredSingleSignOn ? self.dataStore.commonDeviceServices : self.dataStore.deviceServices
        guard let deviceServices = deviceSerivces else {
            log(error: "Can't start AirWatch tunnel service! SDK is not fully set up!")
            log(debug: "AWTunnel requires a valid DeviceServices instance")
            //TODO: error for enforcement failure
            self.enforcementComplete()
            return
        }
        
        AWTunnelService.sharedInstance.boot(deviceServices: deviceServices)
        
        AWTunnelService.sharedInstance.startProxy(proxyPayload: proxyPayload, certificatePayload : self.profile?.certificatePayload, forceRestart: self.forceRestart) { (success: Bool, error: NSError?) in
#if sdk_mixpanel_data_collection_enabled
            SDKMixpanelDataCollectionService.sharedInstance?.update(userSetting: SDKSettings.proxyEnabled(success))
#endif
            switch(success, error) {
                
            case (false, let err?):
                log(error: "Proxy Setup failed with error -Domain :\(err.domain) Code :\(err.code)")
                fallthrough
                
            case (false, nil):
                self.sdkController.setupEncounteredFailure(error: AWSDKError.Setup.proxyFailedToStart)
                
            default:
                log(info: "Proxy setup success : \(success)")
            }
            
            self.enforcementComplete(error)
        }
    }

}
