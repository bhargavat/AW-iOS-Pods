//
//  Logger.swift
//  AWEncryptedStoreKit
//
//  Created by Stephen Turner on 4/26/17.
//  Copyright © 2017 vmware. All rights reserved.
//

import AWLog

let encStoreLogger = AWLogger.getlogger("com.air-watch.sdk.encrypted.store")

internal func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(error: input, function: function, file: file, line: line)
}

internal func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(warning: input, function: function, file: file, line: line)
}

internal func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(info: input, function: function, file: file, line: line)
}

internal func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(verbose: input, function: function, file: file, line: line)
}

internal func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(debug: input, function: function, file: file, line: line)
}

internal func log(secure input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    encStoreLogger.log(secure: input, function: function, file: file, line: line)
}
