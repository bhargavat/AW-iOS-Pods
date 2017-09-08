//
//  AWController+CommandHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

extension AWController {

    @objc
    public func sdkProfile() -> Profile? {
        return self.context.SDKProfile
    }
    
    @available(*, deprecated: 6.0)
    @objc public func appProfile() -> Profile? {
        return self.context.appProfile
    }

    /**
     List of downloaded profiles from Server. This property will return a cached list of profiles. If you want to retrieve profiles please make sure you call
     */
    public var profiles: [Profile] {
        return self.context.profiles
    }


    public func setProfilesToRequest(_ profileTypes: [String]) {
        var profiles = Set(profileTypes)
        profiles.formUnion([AWSDK.ConfigurationProfileType.sdk.StringValue]) //Always request SDK Profile. No matter of what!
        self.requestingProfiles = Array(profiles)
    }
}
