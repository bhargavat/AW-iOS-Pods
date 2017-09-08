//
//  AWSDKLocalization.swift
//  AWLocalization
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

public func AWSDKLocalizedString(_ key: String, comment: String = "") -> String {
    return AWSDKLocalization.getLocalizationString(key, comment)
}

public extension String {
    var localized: String {
        return AWSDKLocalization.getLocalizationString(self)
    }
}

@objc
public final class AWSDKLocalization: NSObject {

    static let resourceBundle = Bundle(for: AWSDKLocalization.self)

    public static func getLocalizationString(_ key: String, _ comment: String? = "") -> String {
        guard let localizationBundlePath = Bundle.path(forResource: "SDKLocalization",
                                                            ofType: "bundle",
                                                       inDirectory: resourceBundle.bundlePath),
              let localizationBundle = Bundle(path: localizationBundlePath)
        else {
            return key
        }

        return localizationBundle.localizedString(forKey: key, value: comment, table: nil)
    }
}
