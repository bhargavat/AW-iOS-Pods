//
//  TunnelLogger.swift
//  AWTunnel
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog

@objc public class TunnelLogger: NSObject {
    public static let sharedInstance = TunnelLogger()
    private let actualLogger = AWLogger.getlogger("com.air-watch.sdk.tunnel")

    @objc public func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        self.actualLogger.log(error: input, function: function, file: file, line: line)
    }

    @objc public func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        self.actualLogger.log(warning: input, function: function, file: file, line: line)
    }

    @objc public func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        self.actualLogger.log(info: input, function: function, file: file, line: line)
    }

    @objc public func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        self.actualLogger.log(verbose: input, function: function, file: file, line: line)
    }

    @objc public func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
        self.actualLogger.log(debug: input, function: function, file: file, line: line)
    }
}

internal func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    TunnelLogger.sharedInstance.log(error: input, function: function, file: file, line: line)
}

internal func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    TunnelLogger.sharedInstance.log(warning: input, function: function, file: file, line: line)
}

internal func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    TunnelLogger.sharedInstance.log(info: input, function: function, file: file, line: line)
}

internal func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    TunnelLogger.sharedInstance.log(verbose: input, function: function, file: file, line: line)
}

internal func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    TunnelLogger.sharedInstance.log(debug: input, function: function, file: file, line: line)
}
