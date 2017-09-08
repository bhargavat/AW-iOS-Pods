//
//  UIDevice+Helpers.swift
//  AWCorePlatformHelpers
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import UIKit
import SystemConfiguration

extension UIDevice {

    public var deviceTypeIdentifier: Int {
        return 2
    }

    public func physicalMemory() -> UInt64{
        return ProcessInfo.processInfo.physicalMemory
    }
    
    public func operatingSystemVersion() -> (Int, Int, Int) {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return (version.majorVersion, version.minorVersion, version.patchVersion)
    }

    public func isAtleastOperatingSystemVersion(major: Int, minor: Int, patch: Int) ->  Bool {
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(OperatingSystemVersion(majorVersion: major, minorVersion: minor, patchVersion: patch ))
    }

    public func operatingSystemVersionString() -> String {
        return ProcessInfo.processInfo.operatingSystemVersionString
    }

    public var totalPhysicalMemory: UInt32 {
        var totalPhysical = physicalMemory()
        //setting the max for totalPhysical as UInt32.max to avoid possible overflow as the server expects UInt32 in memory sample and physicalMemory returns UInt64
        if(totalPhysical > UInt64(UInt32.max))
        {
            totalPhysical = UInt64(UInt32.max)
        }
        
        return UInt32(totalPhysical)
    }

    public var processorCount: Int {
        return ProcessInfo.processInfo.processorCount
    }

    public var activeProcessorCount: Int {
        return ProcessInfo.processInfo.processorCount
    }

    public var totalDiskSpace: Int {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return Int(((attributes[FileAttributeKey.systemSize] as? NSNumber)?.int32Value)!)
        } catch {
            return -1
        }
    }

    public var freeDiskSpace: Int {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            return Int(((attributes[FileAttributeKey.systemFreeSize] as? NSNumber)?.int32Value)!)
        } catch {
            return -1
        }
    }

}
