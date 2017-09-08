//
//  SDKMixpanelDataCollectionAdapter.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

#if sdk_mixpanel_data_collection_enabled
import Foundation
import SDKMixpanel
import AWServices

internal struct SDKUserActionEvent: DataCollectionUserActionEvent{
    var name: String
    var properties: [String: MixpanelType]
}


internal class SDKMixpanelDataCollectionService: NSObject, SDKDataCollectionService {
    
    internal private(set) var collectingData: Bool = false;
    
    internal static var sharedInstance: SDKMixpanelDataCollectionService? = nil
    
    #if DEBUG
    private let MixpanelToken = "bff2fb4e2e9ca37b59d322590e3a27f6"
    #else
    private let MixpanelToken = "f39fcaafac83fbd06526cbf6ee5f8e9d"
    #endif
    
    internal private(set) var mixpanel: MixpanelInstance? = nil
    
    internal static func configureDataCollection(shouldCollectData: Bool) {
        if shouldCollectData  {
            SDKMixpanelDataCollectionService.sharedInstance = SDKMixpanelDataCollectionService()
            SDKMixpanelDataCollectionService.sharedInstance?.startDataCollection()
        } else {
            SDKMixpanelDataCollectionService.sharedInstance?.stopDataCollection()
            SDKMixpanelDataCollectionService.sharedInstance = nil
        }
    }

    internal func startDataCollection() {
        guard !self.collectingData else {
            log(info: "Attempted to start Mixpanel while it is running")
            return
        }
        log(info: "Starting Mixpanel")
        log(debug: "Mixpanel Token: \(MixpanelToken)")
        let mixpanelInstance = Mixpanel.initialize(token: MixpanelToken,
                                                   launchOptions: nil,
                                                   flushInterval: 60,
                                                   instanceName: "AirWatchSDKInstance")
        mixpanelInstance.clearSuperProperties()
        mixpanelInstance.clearTimedEvents()
        mixpanelInstance.useIPAddressForGeoLocation = false
        self.collectingData = true
        self.mixpanel = mixpanelInstance
    }
    
    internal func stopDataCollection() {
        guard self.collectingData else {
            log(info: "Attempted to stop Mixpanel while it is not running")
            return
        }
        log(info: "Stopping Mixpanel")
        self.mixpanel?.flush()
        self.mixpanel?.reset()
        self.collectingData = false
    }
    
    internal func flushCollectedData() {
        self.mixpanel?.flush()
    }
    
    internal func update(userSetting: DataCollectionUserActionEvent) {
        let property = userSetting.properties
        self.mixpanel?.registerSuperProperties(property)
    }
    
    internal func time(event: DataCollectionUserActionEvent) {
        self.mixpanel?.time(event: event.name)
    }
    
    internal func track(event: DataCollectionUserActionEvent) {
        self.mixpanel?.track(event: event.name, properties: event.properties)
    }
}
#endif
