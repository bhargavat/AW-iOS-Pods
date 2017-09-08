//
//  Commands.swift
//  AirWatchServices
//
//  Created by Kishore Sajja on 5/4/17.
//  Copyright © 2017 VMWare, Inc. All rights reserved.
//

import Foundation

public extension AWServices {

    public enum CommandType: Int {
        case installProfiles
        case requestProfiles
        case uploadLogs
        case lockSSO
        case custom
    }

    public enum CommandStatus: Int {
        case unknown = 0
        case acknowledged = 1
        case error = 2
        case commandFormatError = 3
        case idle = 4
        case notNow = 5
    }

}

public protocol Command {
    var UUID: String { get }
    var type: AWServices.CommandType { get }
    var commandInfo: [String: AnyObject] { get }
}

public protocol InstallProfileCommand: Command {
    var profileInfo: Data { get }
}

public protocol UploadLogsCommand: Command {
    var consoleLogLevel: Int { get }
    var logPeriod: TimeInterval { get }
}

public protocol RequestProfilesCommand: Command { }

public protocol LockSSOCommand: Command {}

public protocol CustomCommand: Command { }

public protocol CommandResponse {
    var status: AWServices.CommandStatus { get }
    var payloadIdentifier: String { get }
    var commandTarget: String { get }
    var certificateResponse: [[String: AnyObject]]? { get }
    var installedProfilesResponse:[[String: AnyObject]]? { get }
}
