//
//  DataCollectionPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import AWServices
import AWCrypto
import Foundation

#if sdk_mixpanel_data_collection_enabled
import SDKMixpanel
#endif

class DataCollectionPolicyEnforcer: PolicyEnforcementOperation {

    override var payloadType: String { return AnalyticsPayload.type }

    var analyticsPayload: AnalyticsPayload? {
        return self.profile?.getPayload(self.payloadType)
    }
    override func enforce() throws {
        let shouldEnableDataCollection = self.analyticsPayload?.enabled ?? false

        self.setupAirWatchAnalyticsDataCollection(enableAnalytics: shouldEnableDataCollection)
#if sdk_mixpanel_data_collection_enabled
        self.setupMixpanelDataCollection(shouldCollectData: shouldEnableDataCollection)
#endif

        log(debug: "Configured data collection. Collecting Data? : \(shouldEnableDataCollection)")
        self.enforcementComplete()
    }


    private func setupAirWatchAnalyticsDataCollection(enableAnalytics: Bool) {
        AnalyticsHandler.sharedInstance.enabled = enableAnalytics
    }

#if sdk_mixpanel_data_collection_enabled
    let sdkMixPanel: SDKMixpanelDataCollectionService? = nil
    private func setupMixpanelDataCollection(shouldCollectData: Bool) {
        let sdkMixPanel = SDKMixpanelDataCollectionService.sharedInstance
        if sdkMixPanel == nil {
            SDKMixpanelDataCollectionService.configureDataCollection(shouldCollectData: shouldCollectData)
        }
        
        if shouldCollectData {
            sdkMixPanel?.startDataCollection()
            if let profile = self.profile {
                sdkMixPanel?.constructUserProperties(profile: profile, datastore: self.dataStore)
            }
        } else {
            sdkMixPanel?.flushCollectedData()
            sdkMixPanel?.stopDataCollection()
        }
    }
#endif
}
