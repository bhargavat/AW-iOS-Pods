//
//  SDKSecurityEvents.swift
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


internal enum SDKUserActivityEvent {
    
    case userAuthenticated
    
    case userSessionExpired
    
    case userUnlockedSession

}

internal extension SDKUserActivityEvent: DataCollectionUserActionEvent {

    var name: String {

        switch self {

        case .userAuthenticated:
            return "SDK User Authetnicated"

        case .userSessionExpired:
            return "SDK User Session Expired"

        case .userUnlockedSession:
            return "SDK Session Unlocked By User"

        }
    }

    var properties: [String: MixpanelType] {
        return [:]
    }

}
#endif
