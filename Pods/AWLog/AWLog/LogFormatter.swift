//
//  AWLogFormatter.swift
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CocoaLumberjack

internal extension AWLogFlag {
    var levelIndicator: String {
        switch self {
        case AWLogFlag.error:   return "E"
        case AWLogFlag.warning: return "W"
        case AWLogFlag.info:    return "I"
        case AWLogFlag.debug:   return "D"
        case AWLogFlag.verbose: return "V"
        default:                return "?"
        }
    }
}

internal extension DateFormatter {
    internal static func logTimeStampFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"
        
        return formatter
    }
}

private let timestampFormatter = DateFormatter.logTimeStampFormatter()
private let appName   = ProcessInfo.processInfo.processName
private let processID = getpid()


internal class StandardLogFormatter: NSObject, DDLogFormatter {
    
    func format(message logMessage: DDLogMessage) -> String {
        let timestamp = timestampFormatter.string(from: logMessage.timestamp)
        let loglevel  = logMessage.flag.levelIndicator
        let threadID  = logMessage.threadID ?? ""
        let message   = logMessage.message  ?? ""
        let tag       = logMessage.tag      ?? ""
        let filename  = logMessage.fileName ?? ""
        return "\(timestamp) \(threadID) [\(loglevel)] \(message) [\(tag) \(filename):\(logMessage.line)]"
    }

}

internal class ASLLogFormatter: NSObject, DDLogFormatter {

    func format(message logMessage: DDLogMessage!) -> String! {
        let message  = logMessage.message  ?? ""
        let tag      = logMessage.tag      ?? ""
        let filename = logMessage.fileName ?? ""
        return "\(message) [\(tag) \(filename):\(logMessage.line)]"
    }

}


internal class LogFormatter: DDMultiFormatter {
    
    internal var whitelistFormatter: DDContextWhitelistFilterLogFormatter? = nil
    internal var blacklistFormatter: DDContextBlacklistFilterLogFormatter? = nil
    
    internal init(formatter: DDLogFormatter? = nil) {
        super.init()
        self.add(formatter ?? StandardLogFormatter())
    }

    
    internal func whitelist(_ contexts: [Int]) -> Void{
        if let formatter = whitelistFormatter {
            self.remove(formatter)
        }
        
        guard contexts.count > 0 else {
            self.whitelistFormatter = nil
            return
        }
        
        let formatter = DDContextWhitelistFilterLogFormatter()
        contexts.forEach { (context) in
            formatter?.add(toWhitelist: UInt(bitPattern: context))
        }
        self.add(formatter)
        self.whitelistFormatter = formatter
    }
    
    internal func blacklist(_ contexts: [Int]) {
        
        if let formatter = blacklistFormatter {
            self.remove(formatter)
        }
        
        guard contexts.count > 0 else {
            self.blacklistFormatter = nil
            return
        }
        
        let formatter = DDContextBlacklistFilterLogFormatter()
        contexts.forEach { (context) in
            formatter?.add(toBlacklist: UInt(bitPattern: context))
        }
        self.add(formatter)
        self.blacklistFormatter = formatter
    }
}


