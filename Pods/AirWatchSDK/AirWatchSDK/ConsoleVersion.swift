//
//  ConsoleVersion.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

// The minimum version in which the SDK can support
internal struct  ConsoleVersion {
    internal let major: Int
    internal let minor: Int
    internal let patch: Int
    
    static var minimumSupportedVersion = ConsoleVersion(major: 9, minor: 1, patch: 1)
    
    internal init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    internal init?(value: String) {
        var consoleVersionAsArray = value.components(separatedBy: ".")
        if consoleVersionAsArray.count == 2 {
            consoleVersionAsArray.append("0")
        }
        
        guard
            consoleVersionAsArray.count >= 3,
            let consoleMajor = Int(consoleVersionAsArray.removeFirst()),
            let consoleMinor = Int(consoleVersionAsArray.removeFirst()),
            let consolePatch = Int(consoleVersionAsArray.removeFirst())
            else {
                return nil
        }
        
        self.init(major: consoleMajor, minor: consoleMinor, patch: consolePatch)
    }
}

func >=(lhs: ConsoleVersion, rhs: ConsoleVersion) -> Bool {
    if lhs.major > rhs.major {
        return true
    }
    
    if lhs.major == rhs.major, lhs.minor > rhs.minor {
        return true
    }
    
    if lhs.major == rhs.major, lhs.minor == rhs.minor, lhs.patch >= rhs.patch  {
        return true
    }
    
    return false
}
