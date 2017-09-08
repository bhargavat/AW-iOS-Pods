//
//  AWCommandController.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

// For backwards compatibility

enum CommandManagementNotification: String, PostableNotification {
    var name: String { return self.rawValue }
    case installedNewProfile = "AWNotificationCommandManagerInstalledNewProfile"
}

internal class AWCommandRetriever: CommandRetriever {
    weak var delegate: CommandRetrieverDelegate?
    var deviceServices: DeviceServices?
    var context: SDKContext
    init( context: SDKContext ) {
        self.context = context
        self.deviceServices = context.deviceServices
    }
}

internal class AWCommandProcessor: CommandProcessor {
    weak var delegate: CommandProcessorDelegate?
    weak var commandHandlerDelegate: CommandHandlerDelegate?

    var context: SDKContext
    init( commandHandlerDelegate: CommandHandlerDelegate?, context: SDKContext) {
        self.commandHandlerDelegate = commandHandlerDelegate
        self.context = context
    }
}

internal protocol CommandController {
    init(context: SDKContext, commandHandlerDelegate: CommandHandlerDelegate, commandControllerDelegate: CommandControllerDelegate?)
    func startLoadingCommands()
}

protocol CommandControllerDelegate: class {
    func startedLoadingCommands()
    func failedLoadingCommands(error: NSError)
    func finishedLoadingCommands()
}

internal class AWCommandController: CommandController {
    fileprivate var commandRetriever: CommandRetriever
    fileprivate var commandProcessor: CommandProcessor
    internal weak var delegate: CommandControllerDelegate?

    // delegate: CommandControllerDelegate? is an optional delegate to listen to events emitted by the command controller
    required init(context: SDKContext, commandHandlerDelegate: CommandHandlerDelegate, commandControllerDelegate: CommandControllerDelegate? = nil) {

        self.commandRetriever = AWCommandRetriever(context: context)
        self.commandProcessor = AWCommandProcessor(commandHandlerDelegate: commandHandlerDelegate, context: context)
        self.commandProcessor.delegate = self
        self.commandRetriever.delegate = self
        self.delegate = commandControllerDelegate
    }

    internal func startLoadingCommands() {
        self.delegate?.startedLoadingCommands()
        self.commandRetriever.startLoadingCommands()
    }
}

extension AWCommandController: CommandRetrieverDelegate {
    func acknowledged(command: Command?, status: AWServices.CommandStatus, error: NSError?) {
        switch status {
        case .acknowledged:
            log(info:  "Acknowledged successfully" )

        default:
            log(error:  "Acknowledge failed with error : \(String(describing: error))" )
        }

    }


    func failedToRetrieveCommand(error: NSError) {
        log(error: "Failed to retrieve command with error : \(error.description)")
        self.delegate?.failedLoadingCommands(error: error)
    }


    func commandAvailableToProcess(command: Command) {
        self.commandProcessor.process(command: command)
    }

    func finishedRetrievingCommands() {
        self.delegate?.finishedLoadingCommands()
    }

}

extension AWCommandController: CommandProcessorDelegate {
    func processorDidFailToProcess(command: Command, error: NSError) {
        log(error: "Failed to process command with error : \(error.description)")
    }

    func processorDidFinishProcessing(command: Command, response: CommandResponse) {
        self.commandRetriever.acknowledgeCommand(command: command, response: response)
    }
}
