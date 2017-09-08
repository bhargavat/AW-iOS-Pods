//
//  LoggingPayload.swift
//  AWProfileManager
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWLog

extension AWSDK {
    internal enum SettingLogLevel: Int {
        case off = -1
        case error = 0
        case warning = 1
        case information = 2
        case debug = 3

        var correspondingAWLogLevel: AWLogLevel {
            switch self {
            case .off:          return .off
            case .error:        return .error
            case .warning:      return .warning
            case .information:  return .info
            case .debug:        return .verbose
            }
        }

    }

    internal enum CommandLogLevel: Int {
        case off = -1
        case error = 3
        case warning = 2
        case information = 1
        case debug = 0

        var correspondingAWLogLevel: AWLogLevel {
            switch self {
            case .off:          return .off
            case .error:        return .error
            case .warning:      return .warning
            case .information:  return .info
            case .debug:        return .verbose
            }
        }
    }
}

extension AWLogLevel {
    var correspondingSettingLogLevel: AWSDK.SettingLogLevel {
        switch self {
        case .off:          return .off
        case .error:        return .error
        case .warning:      return .warning
        case .info:         return .information
        case .verbose:      return .debug
        default:            return .debug
        }
    }

    var correspondingCommandLogLevel: AWSDK.CommandLogLevel {
        switch self {
        case .off:          return .off
        case .error:        return .error
        case .warning:      return .warning
        case .info:         return .information
        case .verbose:      return .debug
        default:            return .debug
        }
    }
}

/**
 * @brief		Logging payload that is contained in an 'AWProfile'.
 * @details	A profile payload that represents the Logging group of an SDK profile.
 * @version 6.0
 */
@objc(AWLoggingPayload)
internal class LoggingPayload: ProfilePayload {

    /** An AWLogTraceLevel that defines the logging module's trace level. */
    public fileprivate (set) var loggingLevel: AWSDK.SettingLogLevel = .off

    /** A boolean that defines if logs should only be sent while connected to wifi. */
    public fileprivate (set) var sendLogsOverWifiOnly: Bool = false

    override init(dictionary: [String: Any]) {
        super.init(dictionary: dictionary)

        if let logLevelInt = dictionary.int(for: LoggingPayloadConstants.kAWLoggingLoggingLevelKey),
            -1...3 ~= logLevelInt,
           let logLevel = AWSDK.SettingLogLevel(rawValue: logLevelInt) {
            self.loggingLevel = logLevel
        }
        self.sendLogsOverWifiOnly ??= dictionary.bool(for: LoggingPayloadConstants.kAWLoggingSendLogsOverWifiKey)
    }

    override public class func payloadType() -> String {
        return LoggingPayloadConstants.kAWLoggingPayloadType
    }
}
