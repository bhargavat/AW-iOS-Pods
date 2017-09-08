//
//  ServicesLogger.swift
//  AirWatchServices
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog

let presentationLogger = AWLogger.getlogger("com.air-watch.sdk.services")
internal func log(error: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(error: error, function: function, file: file, line: line)
}

internal func log(warning: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(warning: warning, function: function, file: file, line: line)
}

internal func log(info: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(info: info, function: function, file: file, line: line)
}

internal func log(verbose: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(verbose: verbose, function: function, file: file, line: line)
}

internal func log(debug: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(debug: debug, function: function, file: file, line: line)
}

internal func log(secure: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentationLogger.log(secure: secure, function: function, file: file, line: line)
}
