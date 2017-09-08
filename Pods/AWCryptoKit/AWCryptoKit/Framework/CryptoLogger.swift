//
//  CryptoLogger.swift
//  AWCryptoKit
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import AWLog

let cryptoLogger = AWLogger.getlogger("com.air-watch.sdk.core.crypto")

internal func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(error: input, function: function, file: file, line: line)
}

internal func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(warning: input, function: function, file: file, line: line)
}

internal func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(info: input, function: function, file: file, line: line)
}

internal func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(verbose: input, function: function, file: file, line: line)
}

internal func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(debug: input, function: function, file: file, line: line)
}

internal func log(secure input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    cryptoLogger.log(secure: input, function: function, file: file, line: line)
}
