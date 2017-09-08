////
////  SetupDataUsageOperation.swift
////  AirWatchSDK
////
////  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
////  by copyright and intellectual property laws in the United States and other
////  countries as well as by international treaties. VMware products are covered
////  by one or more patents listed at http://www.vmware.com/go/patents.
////
//
//import AWServices
//import AWHelpers
//import AWDataUsage
//import Foundation
////
////TODO: Must move datausage transmitting data to server logic inside this class so that DataUsage will only capture data
//class SetupDataUsageOperation: SDKSetupAsyncOperation {
//
//    internal var isDataUsageEnabled = SDKDefaultSettings.sharedSettings.isDataUsageEnabled()
//    internal var dataUsage = AWDataUsage.sharedInstance()
//    internal var dataUsageTransmitter: DataUsageTransmitterEndPoint?
//    internal var deviceServicesConfig: DeviceServicesConfig?
//
//    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
//        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
//    }
//    
//    fileprivate class DataUsageTransmissionHandler: NSObject, AWDataUsageHandler {
//        fileprivate var context: SDKContext
//        init(context: SDKContext) {
//            self.context = context
//        }
//        
//        @objc func sendData(toServer dictionaryToSend: [AnyHashable: Any]?, withCompletion completion: SendDataUsageTransmitterCompletionHandler?) {
//            let deviceServices = context.deviceServices
//            guard let dictionaryToSend = dictionaryToSend, let completion = completion else {
//                log(info: "Could not send data usage because dictionary or completion block is nil")
//                return
//            }
//            deviceServices?.sendDataUsageToServer(dictionaryToSend, withCompletion: completion)
//        }
//        
//        @objc func receiveData(fromServer startDate: Date?, end endDate: Date?, withCompletion completion: ReceiveDataUsageTransmitterCompletionHandler?) {
//            let deviceServices = context.deviceServices
//            guard let completion = completion else {
//                log(info: "Could not send data usage because completion block is nil")
//                return
//            }
//            deviceServices?.receiveDataUsageFromServer(startDate, endDate: endDate, withCompletion: completion)
//        }
//        
//    }
//    override func startOperation() {
//        if isDataUsageEnabled {
//            log(info: "DataUsage is enabled")
//            dataUsage.handler = DataUsageTransmissionHandler(context: dataStore)
//            dataUsage.enableMonitor()
//        }
//        self.markOperationComplete()
//    }
//}
