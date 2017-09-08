//
//  LogTransmitter.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices
import AWError
import AWLog
import AWHelpers


private enum LogDataType: Int {
    case console = 0
    case logInsight = 1
}


internal class LogTransmitter: NSObject {
    static let sharedInstance = LogTransmitter()
    var dataStore: SDKContext?

    let consoleLogFilePath: String = "unsentConsoleLogsReport.log"
    let logInsightLogFilePath: String = "unsentLogInsightLogsReport.log"

    //MARK: Lifecycle
    private override init() {}
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    //MARK: Method To Be Called By NSTimer
    ///This method only gets called in upload log command state via the timer that is kicked off
    func sendCommandLogs() {
        self.sendLogs(dueToCommand: true)
        self.dataStore?.commandLogLevel = .off
        self.dataStore?.uploadLogTimeStamp = nil
        AWLogger.deactivateCommandLogger()
    }

    //MARK: Send Logs Methods
    func sendLogs(dueToCommand: Bool = false, completion: @escaping LogTransmissionCompletionHandler = {_,_ in }) {
        guard let logDataToSend: Data = createLogDataToSend(dueToCommand: dueToCommand) else {
            log(error: "ERROR: Unable to get log data from logger")
            return
        }
        if let logLevel = dueToCommand ? self.dataStore?.commandLogLevel : self.dataStore?.currentLogLevel {
            sendConsoleLogData(logDataToSend, logLevel: logLevel, completion: completion)
        } else {
            sendConsoleLogData(logDataToSend, completion: completion)
        }
        sendLogInsightData(logDataToSend)

    }

    func sendAnyUnsentLogs() {
        log(info: "Checking for any unsent logs that need to be sent.")
        if let unsentConsoleLogs: Data = getUnsentLogReportData(LogDataType.console) {
            log(info: "Unsent Console Logs Found: Preparing to send.")
            sendConsoleLogData(unsentConsoleLogs)
        }

        if let unsentLogInsightLogs: Data = getUnsentLogReportData(LogDataType.logInsight) {
            log(info: "Unsent Log Insight Logs Found: Preparing to send.")
            sendLogInsightData(unsentLogInsightLogs)
        }
        log(info: "Completed Checking for any unsent logs.")
    }

    func wipeAllLogData() {
        AWLogger.purgeLogs()
        LogTransmitterFileHandler(filename: consoleLogFilePath).purge()
        LogTransmitterFileHandler(filename: logInsightLogFilePath).purge()
    }

    //MARK: Private Send Logs Methods
    @objc fileprivate func sendConsoleLogData(_ logData: Data, logLevel: AWLogLevel = AWLogger.globalLogLevel, completion: @escaping LogTransmissionCompletionHandler = {_,_ in }) {
        guard let dataStore = dataStore else {
            log(error: "ERROR: dataStore is nil")
            return
        }
        guard let deviceServices: DeviceServices = dataStore.deviceServices else {
            log(error: "ERROR: deviceServices is nil")
            return
        }

        let logReportFileHandler = LogTransmitterFileHandler(filename: self.consoleLogFilePath)

        deviceServices.sendLogData(logData, settingLogLevel: logLevel.correspondingCommandLogLevel.rawValue, overWifiOnly: dataStore.shouldSendLogsOnlyOnWifi, logType: AWLogType.application) { (success: Bool, error: NSError?) in
            if success && error == nil {
                log(info: "Successful send logs to server")
                logReportFileHandler.purge()
                NotificationCenter.default.removeObserver(self) ///if observer then remove it
                completion(true, nil)
            } else {
                self.saveUnsentLogDataForRetry(logData, logDataType: LogDataType.console)
                if error == AWError.SDK.Reachability.networkNotReachable.error { ///if it was a reachability issue due to WIFI only settings
                    log(error: "ERROR: Failed To Send Log Data: Received error \(String(describing: error));\n Begining to wait for a reachability change")
                    NotificationCenter.default.addObserver(self,
                                                           selector: #selector(self.sendConsoleLogData),
                                                           name: NSNotification.Name.AWReachabilityDidChange,
                                                           object: nil)
                } else {
                    log(error: "ERROR: Failed To Send Log Data: Received error \(String(describing: error));\n")
                    NotificationCenter.default.removeObserver(self) ///if observer then remove it
                }
                completion(false, error)
            }
            AWLogger.purgeLogs()
        }
    }

    @objc fileprivate func sendLogInsightData(_ logData: Data) {
        guard SDKDefaultSettings.sharedSettings.getLogInsightURLDefaults() != nil else { /// if logInsight is enabled.
            log(debug: "logInsight is not enabled: Taking no action")
            return
        }
        guard let dataStore = dataStore else {
            log(error: "ERROR: dataStore is nil")
            return
        }
        guard let deviceServices: DeviceServices = dataStore.deviceServices else {
            log(error: "ERROR: deviceServices is nil")
            return
        }

        let logReportFileHandler = LogTransmitterFileHandler(filename: self.logInsightLogFilePath)

        deviceServices.sendLogInsightData(logData, overWifiOnly: dataStore.shouldSendLogsOnlyOnWifi) { (success: Bool, error: NSError?) in
            if success && error == nil {
                log(info: "Successful send longs to log Insight server")
                logReportFileHandler.purge()
                NotificationCenter.default.removeObserver(self)  ///if observer then remove it
            } else {
                self.saveUnsentLogDataForRetry(logData, logDataType: LogDataType.logInsight)
                if error == AWError.SDK.Reachability.networkNotReachable.error { ///if it was a reachability issue due to WIFI only settings
                    log(error: "ERROR: Failed To Send Log Data: Received error \(String(describing: error));\n Begining to wait for a reachability change")
                    NotificationCenter.default.addObserver(self,
                                                           selector: #selector(self.sendLogInsightData),
                                                           name: NSNotification.Name.AWReachabilityDidChange,
                                                           object: nil)
                } else {
                    log(error: "ERROR: Failed To Send Log Data: Received error \(String(describing: error));\n")
                    NotificationCenter.default.removeObserver(self) ///if observer then remove it
                }
            }
            AWLogger.purgeLogs()
        }
    }

    //MARK: Private Helper Methods
    fileprivate func createLogDataToSend(dueToCommand: Bool = false) -> Data? {
        guard var reportData: Data = AppSnapshotController.sharedInstance.generateReport().data(using: String.Encoding.utf8) else {
            log(error: "ERROR: Log report cannot be generated because it cannot be converted to data using NSUTF8StringEncoding")
            return nil
        }
        
        if let logDataToSend: Data = dueToCommand ? AWLogger.getCommandLogFilesData() : AWLogger.getLogsFilesData() {
            guard logDataToSend.count > 0 else {
                log(error: "ERROR: No new log data to send: Sending empty log file")
                return nil
            }
            if let str = "\n\n".data(using: String.Encoding.utf8) {
                reportData.append(str)
                reportData.append(logDataToSend)
            } else {
                log(error: "Could not append log data to send")
            }
        } else {
            log(error: "ERROR: Unable to get log data from logger")
        }
        return reportData
    }

    fileprivate func getUnsentLogReportData(_ logDataType: LogDataType) -> Data? {
        let logReportFileHandler: LogTransmitterFileHandler
        let unsentLogData: Data?

        switch logDataType {
        case LogDataType.console:
            log(debug: "Checking for a unsent console log report")
            logReportFileHandler = LogTransmitterFileHandler(filename: consoleLogFilePath)
            unsentLogData = logReportFileHandler.readToData()

        case LogDataType.logInsight:
            log(debug: "Checking for a unsent log Insight log report")
            logReportFileHandler = LogTransmitterFileHandler(filename: consoleLogFilePath)
            unsentLogData = logReportFileHandler.readToData()
        }

        if unsentLogData != nil {
            logReportFileHandler.purge() //purge file if there was any unsent logs
        }
        if let unsentLogDataCount = unsentLogData?.count, unsentLogDataCount > 0 {
            return unsentLogData
        }
        
        return nil
    }

    fileprivate func saveUnsentLogDataForRetry(_ logDataToSave: Data, logDataType: LogDataType) {
        switch logDataType {
        case LogDataType.console:
            log(debug: "Saving unsent console log report")
            let logReportFileHandler: LogTransmitterFileHandler = LogTransmitterFileHandler(filename: consoleLogFilePath)
            logReportFileHandler.write(logDataToSave)
        case LogDataType.logInsight:
            log(debug: "Saving unsent log Insight log report")
            let logReportFileHandler: LogTransmitterFileHandler = LogTransmitterFileHandler(filename: consoleLogFilePath)
            logReportFileHandler.write(logDataToSave)
        }
    }
}
