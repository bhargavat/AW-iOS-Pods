//
//  CustomerLogger.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog

@objc (AWCustomerLogger)
public final class CustomerLogger: NSObject {
    @objc public static let sharedInstance = CustomerLogger()

    @objc public func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        AWLog.AWLogError(input, function: function, file: file, line: line)
    }

    @objc public func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        AWLog.AWLogWarning(input, function: function, file: file, line: line)
    }

    @objc public func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        AWLog.AWLogInfo(input, function: function, file: file, line: line)
    }

    @objc public func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        AWLog.AWLogVerbose(input, function: function, file: file, line: line)
    }
}


public func AWLogError(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    CustomerLogger.sharedInstance.log(error: input, function: function, file: file, line: line)
}

public func AWLogWarning(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    CustomerLogger.sharedInstance.log(warning: input, function: function, file: file, line: line)
}

public func AWLogInfo(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    CustomerLogger.sharedInstance.log(info: input, function: function, file: file, line: line)
}

public func AWLogVerbose(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    CustomerLogger.sharedInstance.log(verbose: input, function: function, file: file, line: line)
}
