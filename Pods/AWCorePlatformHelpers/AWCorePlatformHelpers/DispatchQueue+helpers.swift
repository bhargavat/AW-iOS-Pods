//
//  AWDispatcher.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

public extension DispatchQueue {
    
    public static var network = DispatchQueue(label: "com.air-watch.network",
                                              qos: DispatchQoS.utility,
                                              attributes: DispatchQueue.Attributes.concurrent,
                                              autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                              target: nil)
    
    public static var background =  DispatchQueue(label: "com.air-watch.background",
                                                  qos: DispatchQoS.background,
                                                  attributes: DispatchQueue.Attributes.concurrent,
                                                  autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                                  target: nil)

    public static var highPriority = DispatchQueue(label: "com.air-watch.high-priority",
                                                   qos: DispatchQoS.userInitiated,
                                                   attributes: DispatchQueue.Attributes.concurrent,
                                                   autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                                   target: nil)
    
    public static var serial = DispatchQueue(label: "com.air-watch.global.serial-queue",
                                             qos: DispatchQoS.userInteractive,
                                             attributes: [],
                                             autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency.inherit,
                                             target: nil)
}
