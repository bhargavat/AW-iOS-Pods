//
//  WebsiteFilteringPayload.swift
//  ProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension AWSDK {
    @objc(AWWebsiteFilterType)
    public enum WebsiteFilterType: Int {
        case unknown = 0
        case deny = 1
        case allow = 2
    }
}

@objc(AWWebsiteFilteringPayload)
public class WebsiteFilteringPayload: ProfilePayload {
    public fileprivate (set) var websiteFilterCategories: [String] = []
    public fileprivate (set) var websiteFilterId: Int = 0
    public fileprivate (set) var filterType: AWSDK.WebsiteFilterType = .unknown

    /// For constructing this payload in UT. It should not be called for elsewhere

    override init(dictionary: [String : Any]) {
        super.init(dictionary: dictionary)
        guard dictionary["PayloadType"] as? String == WebsiteFilteringPayloadConstants.kWebsiteFilteringPayloadType else {
            log(error: "Failed to get WebsiteFiltering Payload")
            return
        }

        log(debug: "Website filtering payload: \(dictionary[WebsiteFilteringPayloadConstants.kWebsiteFilteringFilterTypeId] ?? "Empty")")
        if let webFilterType = dictionary.int(for: WebsiteFilteringPayloadConstants.kWebsiteFilteringFilterTypeId) {
            self.filterType ??= AWSDK.WebsiteFilterType(rawValue:webFilterType)
        }
        self.websiteFilterId ??= dictionary.int(for: WebsiteFilteringPayloadConstants.kWebsiteFilteringWebsiteFilterId)
        self.websiteFilterCategories ??= (dictionary[WebsiteFilteringPayloadConstants.kWebsiteFilteringWebsiteFilterCategories] as? [String])

        ///if array is empty set FilterType to Unknown
        if self.websiteFilterCategories.count == 0 {
            self.filterType = AWSDK.WebsiteFilterType.unknown
        }
    }
    
    public override class func payloadType() -> String {
        return WebsiteFilteringPayloadConstants.kWebsiteFilteringPayloadType
    }
}
