//
//  SDKSetupOperationQueue.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

class SDKOperationQueue: OperationQueue {

    static private(set) var sharedQueue = SDKOperationQueue(name: "com.airwatch.sdk-setup-queue")
    static private(set) var workerQueue = SDKOperationQueue(name: "com.airwatch.sdk-worker-queue")

    fileprivate init(name: String) {
        super.init()
        self.name = name
        self.qualityOfService = QualityOfService.userInitiated
    }

    static func reset() {
        sharedQueue.cancelAllOperations()
        SDKOperationQueue.sharedQueue = SDKOperationQueue(name: "com.airwatch.sdk-setup-queue")
        
        workerQueue.cancelAllOperations()
        SDKOperationQueue.workerQueue = SDKOperationQueue(name: "com.airwatch.sdk-worker-queue")
        SDKOperationQueue.workerQueue.maxConcurrentOperationCount = -1
    }
}
