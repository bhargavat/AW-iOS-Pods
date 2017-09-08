//
//  CommandHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

@objc
public protocol CommandHandler: class {
    func process(command: ConsoleCommand) -> ConsoleCommandResponse?
}

extension AWSDK {
    @objc(AWCommandType)
    public enum CommandType: Int {
        case installProfiles
        case requestProfiles
        case uploadLogs
        case lockSSO
        case custom
    }

    @objc(AWCommandStatus)
    public enum CommandStatus: Int {
        case unknown = 0
        case acknowledged = 1
        case error = 2
        case commandFormatError = 3
        case idle = 4
        case notNow = 5
    }

}
@objc(AWConsoleCommand)
public protocol ConsoleCommand {
    var UUID: String { get }
    var type: AWSDK.CommandType { get }
    var commandInfo: [String: AnyObject] { get }
}

@objc(AWConsoleCommandResponse)
public protocol ConsoleCommandResponse {
    var status: AWSDK.CommandStatus { get }
    var payloadIdentifier: String { get }
    var commandTarget: String { get }
    var certificateResponse: [[String: AnyObject]]? { get }
    var installedProfilesResponse:[[String: AnyObject]]? { get }
}

extension Command {
    var consoleCommand: ConsoleCommand { return InternalConsoleCommand(command: self) }
}

extension ConsoleCommand {
    var command: Command { return InternalCommand(command: self) }
}

class SDKConsoleCommandResponse: ConsoleCommandResponse {
    var status = AWSDK.CommandStatus.unknown
    var payloadIdentifier = ""
    var commandTarget = ""
    var certificateResponse: [[String: AnyObject]]? = nil
    var installedProfilesResponse: [[String: AnyObject]]? = nil

    init(status: AWSDK.CommandStatus = .unknown, payloadIdentifier: String = "", commandTarget: String = "",
         certificateResponse: [[String: AnyObject]]? = nil, installedProfilesResponse: [[String: AnyObject]]? = nil) {

        self.status = status
        self.payloadIdentifier = payloadIdentifier
        self.commandTarget = commandTarget
        self.certificateResponse = certificateResponse
        self.installedProfilesResponse = installedProfilesResponse
    }

    static let errorResponse = SDKConsoleCommandResponse(status: .error)

    static func acknowledge(command: Command, profiles: [[String: AnyObject]]? = nil) -> CommandResponse {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }


        return SDKConsoleCommandResponse(status: .acknowledged,
                                         payloadIdentifier: command.UUID,
                                         commandTarget: bundleIdentifier,
                                         certificateResponse: nil,
                                         installedProfilesResponse: profiles).commandResponse
    }
}


extension ConsoleCommandResponse {
    var commandResponse: CommandResponse {
        return InternalCommandResponse(status: AWServices.CommandStatus(rawValue: self.status.rawValue) ?? .unknown,
                                       payloadIdentifier: self.payloadIdentifier,
                                       commandTarget: self.commandTarget,
                                       certificateResponse: self.certificateResponse,
                                       installedProfilesResponse: self.installedProfilesResponse);
    }
}


fileprivate struct InternalCommandResponse: CommandResponse {
    var status: AWServices.CommandStatus
    var payloadIdentifier: String
    var commandTarget: String
    var certificateResponse: [ [String: AnyObject] ]?
    var installedProfilesResponse:[ [String: AnyObject] ]?
}

fileprivate class InternalConsoleCommand: ConsoleCommand {
    var UUID: String
    var type: AWSDK.CommandType
    var commandInfo: [String: AnyObject]

    init(command: Command) {
        self.UUID = command.UUID
        self.commandInfo = command.commandInfo
        self.type = AWSDK.CommandType(rawValue: command.type.rawValue) ?? .custom
    }
}

fileprivate class InternalCommand: Command {
    var UUID: String
    var type: AWServices.CommandType
    var commandInfo: [String: AnyObject]

    init(command: ConsoleCommand) {
        self.UUID = command.UUID
        self.commandInfo = command.commandInfo
        self.type = AWServices.CommandType(rawValue: command.type.rawValue) ?? .custom
    }
}
