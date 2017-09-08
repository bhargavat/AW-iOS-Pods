//
//  BreezyPayload.swift
//  Pods
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public class BreezyPayload: ProfilePayload {
    
    public fileprivate(set) var breezyMDMAuthToken: String?
    public fileprivate(set) var breezyServerURL: String?
    
    public fileprivate(set) var breezyOauthConsumerID: String?
    public fileprivate(set) var breezyOauthConsumerSecret: String?
    
    public fileprivate(set) var isEnabled: Bool = false

    override init(dictionary: [String: Any]) {
        super.init(dictionary: dictionary)
        guard dictionary[ProfileConstants.kPayloadType] as? String == BreezyPayloadConstants.kIntegrationServicesPayloadTypeV2 else {
            log(error: "Failed to get Breezy Payload")
            return
        }
        self.breezyMDMAuthToken = dictionary[BreezyPayloadConstants.kIntegrationServicesBreezyMDMAuthToken] as? String
        self.breezyServerURL = dictionary[BreezyPayloadConstants.kIntegrationServicesBreezyServerUrl] as? String
        
        self.isEnabled ??= dictionary.bool(for: BreezyPayloadConstants.kIntegrationServicesEnabled)
        
        self.breezyOauthConsumerID = dictionary[BreezyPayloadConstants.kIntegrationServicesBreezyOauthConsumerID] as? String
        self.breezyOauthConsumerSecret = dictionary[BreezyPayloadConstants.kIntegrationServicesbreezyOauthConsumerSecret] as? String
    }
    
    override public class func payloadType() -> String {
        return BreezyPayloadConstants.kIntegrationServicesPayloadTypeV2
    }
}
