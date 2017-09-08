//
//  AWController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//


import Foundation

import AWError

internal struct ApplicationEventsMonitoringOptions: OptionSet {
    var rawValue: Int
    internal init(rawValue: Int) {
        self.rawValue = rawValue
    }
    static let none: ApplicationEventsMonitoringOptions = []
    static let applicationSecurity = ApplicationEventsMonitoringOptions(rawValue: 1)
    static let sdkManagement = ApplicationEventsMonitoringOptions(rawValue: 1 << 1)

    static let sdkSetupInProgressOptions: ApplicationEventsMonitoringOptions = [.applicationSecurity]
    static let sdkSetupCompleteOptions: ApplicationEventsMonitoringOptions = [.applicationSecurity, .sdkManagement]
    static let sdkSetupFailedOptions: ApplicationEventsMonitoringOptions = []
}

internal extension AWController {

    internal func monitorApplicationEvents() {
        NotificationCenter.default.removeObserver(self, name: .UIApplicationDidBecomeActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationDidBecomeActive), name: .UIApplicationDidBecomeActive, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillResignActive, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillResignActive), name: .UIApplicationWillResignActive, object: nil)
        
        NotificationCenter.default.removeObserver(self, name: .UIApplicationWillEnterForeground, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleApplicationWillEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
    }

    internal func handleApplicationDidBecomeActive(_ notification: Notification) -> Void {
        if self.applicationEventsMonitoringOptions.contains(.applicationSecurity) {
            self.presenter.dismissBackgroundBlocker()
        }
    }

    internal func handleApplicationWillResignActive(_ notification: Notification) -> Void {
        var taskIdentifier = UIBackgroundTaskInvalid
        taskIdentifier = UIApplication.shared.beginBackgroundTask {
            if taskIdentifier != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
                taskIdentifier = UIBackgroundTaskInvalid
            }
        }
        
        if self.applicationEventsMonitoringOptions.contains(.applicationSecurity) {
            self.presenter.displayBackgroundBlocker()
        }

        // ISDK-169776 (Reopened 7/31/2017) - Fix blocker not showing up in app switcher for iPhone Plus model
        // Moved extendSSO() to background thread to ensure that it is not blocking the UI updates required for displaying the background blocker
        // Prior to this move, it was causing a timing issue in which the blocker UI did not have a chance actually update before the user went to the app switcher view
        DispatchQueue.background.async {
            if self.applicationEventsMonitoringOptions.contains(.sdkManagement) {
                self.context.extendSSOSession()
                log(debug: "Extend SSO Session Returned")
            }
            
            if taskIdentifier != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(taskIdentifier)
            }
        }
    }

    internal func handleApplicationWillEnterForeground(_ notification: Notification) {
        if self.applicationEventsMonitoringOptions.contains(.sdkManagement) {
            self.presenter.dismissAllViewControllers()
            self.refreshSDK()
            return
        }
        
        if self.isExpectingOpenURLResponse {
            self.setUpOpenURLResponseAlarm()
        }
    }
    
    internal func startObservingHMACChanges() {
        NotificationCenter.default.removeObserver(self,name: NSNotification.Name(rawValue: DataChangeNotification.HMACRefreshed.rawValue), object:nil)
        NotificationCenter.default.addObserver(self, selector: #selector(HMACRefreshNotification), name: NSNotification.Name(rawValue: DataChangeNotification.HMACRefreshed.rawValue), object: nil)
    }
    
}
