//
//  AWController+CommandHandler.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation

extension AWController {

    public func loadCommands() {
        let loadCommandsOperation = FetchConsoleCommandsOperation(sdkController: self, presenter: self.presenter, dataStore: self.context, commandControllerDelegate: self)
        SDKOperationQueue.workerQueue.addOperation(loadCommandsOperation)
    }

    @objc(registerCommandHandler:)
    public func register(commandHandler: CommandHandler ) {
        self.commandHandlers.append(commandHandler)
    }

}

// MARK: Command Management Events
// Called by the AWCommandController
extension AWController: CommandControllerDelegate {
    func startedLoadingCommands() {
        self.commandManagementDelegate?.controllerDidStartLoadingCommands()
    }

    func failedLoadingCommands(error: NSError) {
        self.commandManagementDelegate?.controllerDidFailToLoadCommands(error: error)
    }

    func finishedLoadingCommands() {
        self.commandManagementDelegate?.controllerDidFinishLoadingCommands()
    }
}

// To be implemented by user of SDK, to listen in on the events that the command mangagement system generates
// such as started, failed, and finished loading commands
// To use, the user registers it as a commandManagementDelegate on the AWController singleton
@objc(AWControllerCommandManagementDelegate)
public protocol ControllerCommandManagementDelegate: class {
    func controllerDidStartLoadingCommands()
    func controllerDidFailToLoadCommands(error: NSError)
    func controllerDidFinishLoadingCommands()
}
