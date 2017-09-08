//
//  AWLoggersCollection.swift
//  AWLog
//
//  Copyright © 2016 VMware, Inc. All rights reserved.
//  This product is protected by copyright and intellectual property laws in the United States and
//  other countries as well as by international treaties.
//  AirWatch products may be covered by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import CocoaLumberjack

internal enum LoggerType {
    case tty, asl, file
}

internal class LoggersCollection: DDLog {
    
    init(types: [LoggerType], logLevel: DDLogLevel) {
        super.init()
        self.removeAllLoggers()
        
        types.forEach { (loggerType) in
            switch loggerType {
            case .tty:
                self.add(TTYLogger.sharedInstance(), with: logLevel)

            case .asl:
                if #available(iOS 10, *) { break }
                self.add(ASLLogger.sharedInstance(), with: logLevel)
                
            case .file:
                self.add(FileLogger.sharedFileLogger, with: logLevel)
            }
        }
    }

    internal func setLogLevel(_ logLevel: DDLogLevel) {
        guard let allLoggers = self.allLoggers()?.filter({ $0 !== FileLogger.commandFileLogger }) else {
            return
        }
        
        allLoggers.forEach{ logger in
            self.remove(logger)
            self.add(logger, with: logLevel)
        }
    }

}
