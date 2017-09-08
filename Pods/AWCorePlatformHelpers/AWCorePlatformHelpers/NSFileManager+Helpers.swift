//
//  UIApplication+Helpers.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import AWLog

public extension FileManager {

    // Return the document directory. If the document directory is unaccessible for any reason, an empty string is returned
    var documentsDirectory: String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        return paths.first ?? ""
    }
    // Return the caches directory. If the caches directory is unaccessible for any reason, an empty string is returned
    var cachesDirectory: String {
        let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
        return paths.first ?? ""
    }

    func filePathInDocumentsDirectory(_ name: String) -> String {
        return documentsDirectory.appending("/" + name)
    }

    func filePathInCachesDirectory(_ name: String) -> String {
        return cachesDirectory.appending("/" + name)
    }

    func createDirectoryInDocuments(_ path: String) -> Bool {
        do {
            let filePath = self.filePathInDocumentsDirectory(path)
            try createDirectory(atPath: filePath, withIntermediateDirectories: true, attributes: nil)
            AWLogInfo("Path for directory \(path) was created")
            return true
        } catch {
            AWLogError("Could not create directory for the path \(path)")
            return false
        }
    }

}
