//
//  PresentationLogger.swift
//  AWSDKPresenter
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import UIKit
import AWLog

internal let presentation = AWLogger.getlogger("com.air-watch.sdk.presentation")

internal func log(error input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(error: input, function: function, file: file, line: line)
}

internal func log(warning input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(warning: input, function: function, file: file, line: line)
}

internal func log(info input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(info: input, function: function, file: file, line: line)
}

internal func log(verbose input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(verbose: input, function: function, file: file, line: line)
}

internal func log(debug input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(debug: input, function: function, file: file, line: line)
}

internal func log(secure input: String, function: String = #function, file: String = #file, line: UInt = #line) {
    presentation.log(secure: input, function: function, file: file, line: line)
}
