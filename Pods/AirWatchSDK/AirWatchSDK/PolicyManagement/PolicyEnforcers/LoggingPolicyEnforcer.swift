//
//  LoggingPolicyEnforcer.swift
//  PolicyManagement
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

import AWServices
import AWLog

internal class LoggingPolicyEnforcer: PolicyEnforcementOperation {
    override var payloadType: String { return LoggingPayload.type }

    var loggingPayload: LoggingPayload? {
        return self.profile?.getPayload(self.payloadType)
    }

    override func enforce() throws {
        self.updateLogLevelFromProfile()
        self.updateCommandLogLevel()
        self.enforcementComplete()
    }

    private func updateLogLevelFromProfile() {
        guard let payload = self.loggingPayload else {
            log(debug: "LoggingPolicyEnforcer: Enforcing empty payload setting default values.")
            AWLogger.globalLogLevel = .info
            self.dataStore.shouldSendLogsOnlyOnWifi = true
            self.dataStore.currentLogLevel = AWLogLevel.info
            return
        }

        self.dataStore.shouldSendLogsOnlyOnWifi = payload.sendLogsOverWifiOnly
        self.dataStore.currentLogLevel = payload.loggingLevel.correspondingAWLogLevel
        AWLogger.globalLogLevel = self.dataStore.currentLogLevel
        log(info: "Logs will be uploaded over WiFi only: \(payload.sendLogsOverWifiOnly)")
        log(info: "Current Log Level for the loggers: \(AWLogger.globalLogLevel)")
    }

    private func updateCommandLogLevel() {
        guard self.dataStore.uploadLogTimeStamp != nil else {
            log(info: "Command Logging is not enabled. Not updating Command Log Settings")
            return
        }

        log(debug: "Command Logging is enabled. Updating Command Logger to required log level: \(self.dataStore.commandLogLevel)")
        AWLogger.activateCommandLogger(level: self.dataStore.commandLogLevel)
    }
}
