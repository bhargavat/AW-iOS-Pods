//
//  LogLevelSetupOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWLog
import AWStorage

internal class LogLevelSetupOperation: SDKSetupAsyncOperation {

    override func startOperation() {
        AWLogger.globalLogLevel = self.dataStore.currentLogLevel
        log(info: "Setting Current Log Level \(AWLogger.globalLogLevel)")
        self.sendUnsentLogs()
        self.configureLogCommandHandler()
        self.markOperationComplete()
    }

    private func sendUnsentLogs() {
        LogTransmitter.sharedInstance.dataStore = dataStore
        SDKOperationQueue.workerQueue.addOperation {
            LogTransmitter.sharedInstance.sendAnyUnsentLogs() //if there are any unsent logs, send them
        }
    }

    private func configureLogCommandHandler() {
        guard let commandLogsUploadTimestamp = self.dataStore.uploadLogTimeStamp else { return }
        /// Check if timeStampDate has already been passed
        if commandLogsUploadTimestamp < Date() {
            LogTransmitter.sharedInstance.sendCommandLogs()
            return
        }

        log(debug: "Creating Timer for Log Transmission Date")
        AWLogger.activateCommandLogger(level: self.dataStore.commandLogLevel)
        let timer = Timer(timeInterval: 0.0,
                          target: LogTransmitter.sharedInstance,
                          selector: #selector(LogTransmitter.sendCommandLogs),
                          userInfo: nil,
                          repeats: false)
        timer.fireDate = max(commandLogsUploadTimestamp, Date())
        timer.tolerance = 2.0
        timer.fire()
    }
}
