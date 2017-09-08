//
//  AWCommandProcessor.swift
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

extension AWError.SDK {

    enum CommandProcessor: AWErrorType {
        case cannotProcessCommand
        case missingCommandHandler
    }
}

internal protocol CommandProcessorDelegate : class {
    func processorDidFinishProcessing(command: Command, response: CommandResponse)
    func processorDidFailToProcess(command: Command, error: NSError)
}

internal protocol CommandProcessor {

    weak var delegate: CommandProcessorDelegate? { get set }

    weak var commandHandlerDelegate: CommandHandlerDelegate? { get set }

    var context: SDKContext { get set }

    func process(command: Command)
}

extension CommandProcessor {

    func process(command: Command) {
        guard let commandHandler = self.commandHandlerDelegate  else {
            self.delegate?.processorDidFailToProcess(command: command, error: AWError.SDK.CommandProcessor.cannotProcessCommand.error)
            return
        }

        var response: CommandResponse? = nil

        switch command.type {
        case .installProfiles:
            response = commandHandler.processInstallProfile(command: command)

        case .requestProfiles:
            response = commandHandler.processRequestProfiles(command: command)

        case .uploadLogs:
            response = commandHandler.processUploadLogs(command: command)

        case .lockSSO:
            response = commandHandler.processLockSSO(command: command)

        default:
            response = commandHandler.processCustom(command: command)
        }

        guard let processedResponse = response else {
            self.delegate?.processorDidFailToProcess(command: command, error: AWError.SDK.CommandProcessor.missingCommandHandler.error)
            return
        }

        self.delegate?.processorDidFinishProcessing(command: command, response: processedResponse)
    }
}
