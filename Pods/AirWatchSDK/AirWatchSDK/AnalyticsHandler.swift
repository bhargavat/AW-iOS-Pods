//
//  Analytics.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation
import UIKit
import AWDataSampler

extension AWSDK {

    @objc(AWAnalyticsEvent)
    public enum AnalyticsEvent : UInt16
    {
        case customEvent = 0
        case sessionStarted
        case sessionEnded
        case viewDidAppear
        case viewDidDisappear
    }

    @objc(AWAnalyticsEventValueType)
    public enum AnalyticsEventValueType : UInt16
    {
        case none = 0
        case integer
        case long
        case string
    }

}

extension AWSDK.AnalyticsEvent {
    internal var _AnalyticsEvent: AnalyticsEvent {
        return AnalyticsEvent(rawValue: self.rawValue) ?? .customEvent
    }
}

extension AWSDK.AnalyticsEventValueType {
    internal var _AnalyticsEventValueType: AWAnalyticsEventValueType {
        return AWAnalyticsEventValueType(rawValue: self.rawValue) ?? .none
    }
}

@objc open class AnalyticsHandler: NSObject {
    public static let sharedInstance = AnalyticsHandler()

    public var enabled: Bool {
        get { return _AnalyticsHandler.sharedInstance.enabled }
        set { _AnalyticsHandler.sharedInstance.enabled = newValue }
    }

    @objc
    open func recordEvent(_ event: AWSDK.AnalyticsEvent, eventName: String, eventValue: String, valueType: AWSDK.AnalyticsEventValueType) {
        _AnalyticsHandler.sharedInstance.recordEvent(event._AnalyticsEvent, eventName: eventName, eventValue: eventValue, valueType: valueType._AnalyticsEventValueType)
    }
}

internal class _AnalyticsHandler: NSObject, DataSamplerDelegate {
    public static let sharedInstance = _AnalyticsHandler()

    internal var sessionUUID: String?
    public var enabled  = false {
        didSet {
            guard oldValue != enabled else { return }

            if enabled == false {
                NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
                NotificationCenter.default.removeObserver(self, name: .UIApplicationDidEnterBackground, object: nil)
                return
            }

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(startAnalyticsHandler),
                                                   name: .UIApplicationDidBecomeActive,
                                                   object: nil)

            NotificationCenter.default.addObserver(self,
                                                   selector: #selector(stopAnalyticsHandler),
                                                   name: .UIApplicationDidEnterBackground,
                                                   object: nil)
        }
    }

    internal lazy var bundleVersion: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }()

    internal lazy var bundleName: String? = {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    }()

    internal lazy var sampler: DataSampler = {
        let configuration = DataSamplerConfiguration.filtered(moduleFilter: { (module) -> Bool in
            return (module.rawValue == AWDataSamplerModules.analytics.rawValue)
        })

        let sampler = DataSampler(config: configuration,
                                  deviceServices: AWController.sharedInstance.context.deviceServices)
        sampler.delegate = _AnalyticsHandler.sharedInstance
        return sampler
    }()

    internal var disableAppSessionLog = false

    internal func recordEvent(_ event: AnalyticsEvent, eventName: String, eventValue: String, valueType: AWAnalyticsEventValueType) {
        guard self.enabled else {
            log(verbose: "Analytics did not record event by name of \(eventName), because it is not enabled.")
            return
        }

        if self.sessionUUID == nil {
            self.registerAppSessionStart()
        }

        // Create instance from AWDataSampler class, and use that to create sample for the given event
        let resultBundleId = Bundle.main.bundleIdentifier?.data(using: .utf8) ?? Data()
        let eventNameData = eventName.data(using: .utf8) ?? Data()
        let eventValueData = eventValue.data(using: .utf8) ?? Data()
        let sessionUUIDData = sessionUUID?.data(using: .utf8) ?? Data()
        let bundleNameData = bundleName?.data(using: .utf8) ?? Data()
        let bundleVersionData = bundleVersion?.data(using: .utf8) ?? Data()
        let analyticsSample = DataSampleAnalytics(eventName: eventNameData,
                                                  eventValue: eventValueData,
                                                  sessionUUID: sessionUUIDData,
                                                  eventType: event,
                                                  valueType: valueType,
                                                  bundleVersion: bundleVersionData,
                                                  bundleName: bundleNameData,
                                                  bundleID: resultBundleId)
        self.sampler.addSample(analyticsSample)
    }


    func registerAppSessionStart() {
        guard self.sessionUUID == nil else { return }
        self.sessionUUID = UUID().uuidString

        if self.disableAppSessionLog == false {
            self.recordEvent(.customEvent, eventName: "AW_AppSessionStart", eventValue: "", valueType: .string)
        }

        log(info: "SessionStart::::::Session ID: \(self.sessionUUID ?? "No session UUID")")
    }

    func registerAppSessionEnd() {
        guard let sessionUUID = self.sessionUUID else {
            log(debug: "Analytics tried to end session without a valid sessionUUID, returning early.")
            return
        }

        if self.disableAppSessionLog == false {
            self.recordEvent(.customEvent, eventName: "AW_AppSessionEnd", eventValue: sessionUUID, valueType: .string)
        }

        log(info: "SessionEnd::::::Session ID: \(sessionUUID)")

        self.sessionUUID = nil
    }

    private var currentAnalyticsUploadTaskIdentifier = UIBackgroundTaskInvalid
    // MARK: Notification Methods
    func startAnalyticsHandler(notification: Notification) {
        self.registerAppSessionStart()
        self.sampler.start()
    }

    func stopAnalyticsHandler(notification: Notification) {
        self.registerAppSessionEnd()

        guard Bundle.main.isExtensionBundle == false else {
            self.sampler.stop()
            self.sampler.transmitImmediately()
            return
        }

        log(verbose: "Starting bg task...")
        currentAnalyticsUploadTaskIdentifier = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(self.currentAnalyticsUploadTaskIdentifier)
        }

        // if DataSampler IS initialized, tell it to shutdown and transmit with self as delegate.
        // else, if is NOT in ExtensionMode AND backgroundTask is NOT Invalid, then end task and invalidate it with InfoLog "All done, No DataSampler config."
        self.sampler.stop()
        self.sampler.transmitImmediately()
    }


    public func DataSamplerSamplingErrorNotify(_ sampler: DataSampler, error: NSError) {
        log(error: "While processing Sample, Analytics Data Sampler received error: \(error)")
        log(debug: "DataSampler: \(sampler)")
    }

    public func DataSamplerDidSendSamples(_ sampler: DataSampler) {
        /// end background task
        guard Bundle.main.isExtensionBundle == false else { return }
        log(verbose: "All done, Data sent Successfully.")

        if currentAnalyticsUploadTaskIdentifier != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(currentAnalyticsUploadTaskIdentifier)
            self.currentAnalyticsUploadTaskIdentifier = UIBackgroundTaskInvalid
        }
        /// Clear Analytics sampled data that was sent.
        sampler.purgeSamples(AWDataSamplerModules.analytics)
    }

    public func DataSamplerFailedSendingSamples(_ sampler: DataSampler, error: NSError) {

        guard Bundle.main.isExtensionBundle == false else { return }

        if self.currentAnalyticsUploadTaskIdentifier != UIBackgroundTaskInvalid {
            UIApplication.shared.endBackgroundTask(currentAnalyticsUploadTaskIdentifier)
            self.currentAnalyticsUploadTaskIdentifier = UIBackgroundTaskInvalid
        }

        log(verbose: "Failed to send, but all done.")
    }

}
