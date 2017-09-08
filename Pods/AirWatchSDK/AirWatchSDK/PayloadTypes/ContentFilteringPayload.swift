//
//  ContentFilteringPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

@objc(AWContentFilterType)
public enum ContentFilterType: Int {
    case none = 0
    case websense = 1
}

@objc(AWContentFilteringPayload)
public class ContentFilteringPayload: ProfilePayload {

    public fileprivate (set) var contentFilterType: ContentFilterType = .none
    public fileprivate (set) var contentFilterProxyId: Int = 0
    public fileprivate (set) var websensePacAddress: String?
    public fileprivate (set) var websenseAccountId: Int = 0
    public fileprivate (set) var websenseSecurityKey: String?
    public fileprivate (set) var websenseProxyId: Int = 0

    /// For constructing this payload in UT. It should not be called for elsewhere
    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)

        guard dictionary["PayloadType"] as? String == ContentFilteringPayloadConstants.kContentFilteringPayloadType else {
            log(error: "Failed to get Content Filter Payload")
            return
        }
        
        if let intVal = dictionary.int(for: ContentFilteringPayloadConstants.kContentFilteringWebsenseProxyTypeId),
           let filterType = ContentFilterType(rawValue: intVal) {
            self.contentFilterType = filterType
        }
        
        self.contentFilterProxyId ??= dictionary.int(for: ContentFilteringPayloadConstants.kContentFilteringWebsensePacAddress)
        self.websensePacAddress = dictionary[ContentFilteringPayloadConstants.kContentFilteringWebsensePacAddress] as? String
        self.websenseAccountId ??= dictionary.int(for: ContentFilteringPayloadConstants.kContentFilteringWebsenseAccountId)
        self.websenseSecurityKey = dictionary[ContentFilteringPayloadConstants.kContentFilteringWebsenseSecurityKey] as? String
        self.websenseProxyId ??= dictionary.int(for: ContentFilteringPayloadConstants.kContentFilteringWebsenseProxyTypeId)
    }

    override public class func payloadType() -> String {
        return ContentFilteringPayloadConstants.kContentFilteringPayloadType
    }
}
