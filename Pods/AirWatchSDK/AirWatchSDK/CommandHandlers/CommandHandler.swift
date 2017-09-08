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
import AWLog

internal protocol CommandHandlerDelegate: class {
    func processInstallProfile(command: Command) -> CommandResponse?
    func processRequestProfiles(command: Command) -> CommandResponse?
    func processLockSSO(command: Command) -> CommandResponse?
    func processUploadLogs(command: Command) -> CommandResponse?
    func processCustom(command: Command ) -> CommandResponse?
}

internal class SDKCommandHandler: CommandHandlerDelegate{
    internal var processedCommands: [Command] = []
    internal var context: SDKContext
    internal var controller: AWController

    internal init(controller: AWController, dataStore: SDKContext) {
        self.context = dataStore
        self.controller = controller
    }

    func processInstallProfile(command: Command) -> CommandResponse? {
        guard
            let installProfileCommand = command as? InstallProfileCommand,
            let bundleIdentifier = Bundle.main.bundleIdentifier
        else {
            log(error: "Recieved \(command) but could not be processed as Install Profile Command. Sending Error Response")
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }

        log(info: "Recieved Install Profile Command with profile Data length: \(installProfileCommand.profileInfo.count)")
        let profileData = installProfileCommand.profileInfo
        guard let profile = Profile(profileData: profileData) else {
            log(error: "Given Profile Data can not be converted into a working Profile. Returning Error Response for Command Processing")
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }

        let appProfileName = AWController.sharedInstance.requestingProfiles.filter{ $0 != AWSDK.ConfigurationProfileType.sdk.StringValue }.first
        if let name = appProfileName,
            profile.authenticationPayload == nil,
            let properProfile = Profile(profileData: profileData, profileType: AWSDK.ConfigurationProfileType.fromString(name)) {
            _ = self.context.saveProfile(properProfile)
        } else if profile.authenticationPayload != nil,
            let properProfile = Profile(profileData: profileData, profileType: .sdk) {
            _ = self.context.saveProfile(properProfile)
        } else {
            log(error: "Unknown profile delivered to application")
        }

        self.processedCommands.append(command)
        _ = self.context.saveProfile(profile)
        log(info: "Saved Profile to Store")
        CommandManagementNotification.installedNewProfile.post(data: profile)
        return SDKConsoleCommandResponse(status: .acknowledged, payloadIdentifier: command.UUID, commandTarget: bundleIdentifier).commandResponse
    }

    func processRequestProfiles(command: Command) -> CommandResponse? {
        guard let requestProfileCommand = command as? RequestProfilesCommand else {
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }

        var result : [ [String : AnyObject] ] = []
        let profiles = self.context.profiles
        profiles.forEach { (profile) in
            result.append(profile.dictionaryToStore as [String : AnyObject])
        }
        self.processedCommands.append(requestProfileCommand)
        return SDKConsoleCommandResponse.acknowledge(command: command, profiles: result)
    }


    func processLockSSO(command: Command) -> CommandResponse? {
        guard
            let lockSSOCommand = command as? LockSSOCommand,
            self.controller.canLockSession()
        else { return SDKConsoleCommandResponse.errorResponse.commandResponse }

        self.processedCommands.append(lockSSOCommand)
        if self.controller.lockSession(lockType: .command) {
            return SDKConsoleCommandResponse.acknowledge(command: command)
        }

        return SDKConsoleCommandResponse.errorResponse.commandResponse
    }

    func processUploadLogs(command: Command) -> CommandResponse? {
        guard let uploadlogsCommand = command as? UploadLogsCommand else {
            log(error: "Asked to process command other than Upload Logs command.")
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }

        guard let bundleIdentifier = Bundle.main.bundleIdentifier else {
            log(error: "The main bundle identifier is nil.")
            return SDKConsoleCommandResponse.errorResponse.commandResponse
        }

        guard
            uploadlogsCommand.consoleLogLevel != 0,
            uploadlogsCommand.logPeriod != 0
        else {
            LogTransmitter.sharedInstance.sendLogs()
            return SDKConsoleCommandResponse(status: .acknowledged, payloadIdentifier: command.UUID, commandTarget: bundleIdentifier).commandResponse
        }

        let commandLogLevelValue = uploadlogsCommand.consoleLogLevel
        let requiredCommandLogLevel = AWSDK.CommandLogLevel(rawValue: commandLogLevelValue) ?? .debug
        let defaultAmountOfTimeToLog = uploadlogsCommand.logPeriod > 0 ? uploadlogsCommand.logPeriod : 1800; //Default to 30 mins.

        // Write Values to storage for future/restart scenarios
        self.context.commandLogLevel = requiredCommandLogLevel.correspondingAWLogLevel
        self.context.uploadLogTimeStamp = Date(timeIntervalSinceNow: defaultAmountOfTimeToLog)
        AWLogger.activateCommandLogger(level: requiredCommandLogLevel.correspondingAWLogLevel)

        //Here start the timer for log transmitter.
        if let timeStampDate = self.context.uploadLogTimeStamp {
            log(debug: "Creating Timer for Log Transmission Date")
            let timer = Timer(timeInterval: 0.0,
                              target: LogTransmitter.sharedInstance,
                              selector: #selector(LogTransmitter.sendCommandLogs),
                              userInfo: nil,
                              repeats: false)
            timer.fireDate = max(timeStampDate, Date())
            timer.tolerance = 2.0
            timer.fire()
        }

        return SDKConsoleCommandResponse(status: .acknowledged, payloadIdentifier: command.UUID, commandTarget: bundleIdentifier).commandResponse
    }

    func processCustom(command: Command) -> CommandResponse? {
        for handler in self.controller.commandHandlers {
            if let response = handler.process(command: command.consoleCommand) {
                self.processedCommands.append(command)
                return response.commandResponse
            }
        }

        return nil
    }


}

