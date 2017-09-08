//
//  AWErrorLogger.swift
//  AWError
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog

let errorLogger = AWLogger.getlogger("com.air-watch.sdk.error")

internal func AWLogError(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(error: input, function: function, file: file, line: line)
}

internal func AWLogWarning(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(warning: input, function: function, file: file, line: line)
}

internal func AWLogInfo(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(info: input, function: function, file: file, line: line)
}

internal func AWLogVerbose(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(verbose: input, function: function, file: file, line: line)
}

internal func AWLogDebug(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(debug: input, function: function, file: file, line: line)
}

internal func AWLogSecure(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    errorLogger.log(secure: input, function: function, file: file, line: line)
}

