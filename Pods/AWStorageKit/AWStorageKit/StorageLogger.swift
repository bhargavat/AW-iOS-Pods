//
//  StorageLogger.swift
//  AWStorage
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog


let storageLogger = AWLogger.getlogger("com.air-watch.sdk.storage")

internal func AWLogError(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(error: input, function: function, file: file, line: line)
}

internal func AWLogWarning(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(warning: input, function: function, file: file, line: line)
}

internal func AWLogInfo(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(info: input, function: function, file: file, line: line)
}

internal func AWLogVerbose(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(verbose: input, function: function, file: file, line: line)
}

internal func AWLogDebug(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(debug: input, function: function, file: file, line: line)
}

internal func AWLogSecure(_ input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    storageLogger.log(secure: input, function: function, file: file, line: line)
}

