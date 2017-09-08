//
//  OpenURLLogger.swift
//  AWOpenURLClient
//
//  Created by Troy Liu on 5/26/17.
//  Copyright © 2017 VMware Inc. All rights reserved.
//

import Foundation
import AWLog


let openURLLogger = AWLogger.getlogger("com.air-watch.sdk.open-url-client")

internal func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(error: input, function: function, file: file, line: line)
}

internal func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(warning: input, function: function, file: file, line: line)
}

internal func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(info: input, function: function, file: file, line: line)
}

internal func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(verbose: input, function: function, file: file, line: line)
}

internal func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(debug: input, function: function, file: file, line: line)
}

internal func log(secure input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    openURLLogger.log(secure: input, function: function, file: file, line: line)
}
