//
//  AWAgnoticAnalyticsIdentifier.swift
//  AirWatchSDK
//
//  Copyright © 2017 VMWare, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import UIKit

public extension UIDevice {

    //AirWatch Console Agnostic Analytics Identifier.
    public var applicationAnalyticsIdentifier: String {
        let identifier = AWController.sharedInstance.context.sharedApplicationAnalyticsIdentifier
        UserDefaults.standard.set(identifier, forKey: "com.air-watch.application.analytics-identifier")
        return identifier
    }

}
