//
//  Reachability.swift
//  AWCorePlatformHelpers
//
//  Created by Kishore Sajja on 12/28/16.
//  Copyright © 2016 Kishore Sajja. All rights reserved.
//

import Foundation
import SystemConfiguration

@objc(AWNetworkStatus)
public enum NetworkReachabilityStatus: Int {
    case notReachable
    case reachableViaWifi
    case reachableViaWWAN
}

public class Reachability: NSObject {
    public private(set) var monitoringReachabilityChanges: Bool = false
    public private(set) var host: String? = nil
    public private(set) var flags = SCNetworkReachabilityFlags(rawValue: 0)
    private var networkReachability: SCNetworkReachability
    
    public var currentReachabilityStatus: NetworkReachabilityStatus {
        guard
            withUnsafeMutablePointer(to: &flags, { (flagsPointer) -> Bool in
                return SCNetworkReachabilityGetFlags(self.networkReachability, flagsPointer)
            })
        else {
            return NetworkReachabilityStatus.notReachable
        }
        return self.networkReachabilityStatus(flags: flags)
    }
    
    public static var forInternetConnection = Reachability.reachabilityForInternetConnection()
    public init?(hostname: String) {
        guard
            let hostnameString = hostname.cString(using: .utf8),
            let route = SCNetworkReachabilityCreateWithName(nil, hostnameString)
        else {
            return nil
        }
        
        self.flags = .reachable
        self.host = hostname
        self.networkReachability = route
    }
    deinit {
        self.stopReachabilityMonitoring()
        self.host = nil
    }
    
    
    @discardableResult
    public func startReachabilityMonitoring() -> Bool {
        if self.monitoringReachabilityChanges {
            AWLogInfo("Internet Reachability Monitoring has already started")
            return true
        }
        
        var context = SCNetworkReachabilityContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()
        let setCallback = SCNetworkReachabilitySetCallback(networkReachability,{ (_, flags, info) in
            let reachability = Unmanaged<Reachability>.fromOpaque(info!).takeUnretainedValue()
            reachability.flags = flags
            NotificationCenter.default.post(name: NSNotification.Name.AWReachabilityDidChange, object: reachability)
        },&context)
        let scheduledReachability = SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.monitoringReachabilityChanges = setCallback && scheduledReachability
        AWLogInfo("Started Reachability Monitoring: \(self.monitoringReachabilityChanges)")
        return self.monitoringReachabilityChanges
    }
    
    public func stopReachabilityMonitoring() {
        SCNetworkReachabilitySetCallback(self.networkReachability, nil, nil)
        SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        self.monitoringReachabilityChanges = false
    }
    
    private static func reachability(hostAddress: sockaddr) -> SCNetworkReachability? {
        var address = hostAddress
        return withUnsafePointer(to: &address) { SCNetworkReachabilityCreateWithAddress(nil, $0) }
    }

    private static func reachabilityForInternetConnection() -> Reachability? {
        var zeroAddress = sockaddr_in()
        bzero(&zeroAddress, MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        if let v4Route = Reachability.reachability(internetAddress: zeroAddress) {
            return Reachability(networkReachability: v4Route)
        }
        
        var v6ZeroAddress = sockaddr_in6()
        bzero(&v6ZeroAddress, MemoryLayout<sockaddr_in6>.size)
        v6ZeroAddress.sin6_len = __uint8_t(MemoryLayout<sockaddr_in6>.size)
        v6ZeroAddress.sin6_family = sa_family_t(AF_INET6)
        if let v6Route = Reachability.reachability(internetAddress: zeroAddress) {
            return Reachability(networkReachability: v6Route)
        }
        
        return nil
    }
    
    internal static func reachability(internetAddress: sockaddr_in) -> SCNetworkReachability? {
        var address = internetAddress
        return withUnsafePointer(to: &address, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        })
    }
    
    private init(networkReachability: SCNetworkReachability) {
        self.networkReachability = networkReachability
    }
    
    private func networkReachabilityStatus(flags: SCNetworkReachabilityFlags) -> NetworkReachabilityStatus {
        var networkStatus: NetworkReachabilityStatus = .notReachable
        guard flags.contains(.reachable) else { return networkStatus }
        if flags.notContains(.connectionRequired) { networkStatus = .reachableViaWifi}
        if flags.contains(.connectionOnDemand) || flags.contains(.connectionOnTraffic) {
            if flags.notContains(.interventionRequired) { networkStatus =  .reachableViaWifi }
        }
        if flags.contains(.isWWAN) { networkStatus =  .reachableViaWWAN }
        return networkStatus
    }
}

extension OptionSet where Element == Self {
    public func notContains(_ member: Self) -> Bool {
        return self.contains(member) == false
    }
}
