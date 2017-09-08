//
//  CommandFetchOperation.swift
//  AirWatchSDK
//
//  Copyright © 2016 VMware, Inc. All rights reserved. This product is protected
//  by copyright and intellectual property laws in the United States and other
//  countries as well as by international treaties. VMware products are covered
//  by one or more patents listed at http://www.vmware.com/go/patents.
//

import Foundation
import AWServices

class FetchConsoleCommandsOperation: SDKSetupAsyncOperation, CommandControllerDelegate {

    private var controller: AWCommandController? = nil
    private var sdkCommandHandler: SDKCommandHandler? = nil

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext, commandControllerDelegate: CommandControllerDelegate?) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        let sdkCommandHandler = SDKCommandHandler(controller: sdkController, dataStore: dataStore)
        self.controller = AWCommandController(context: self.dataStore, commandHandlerDelegate: sdkCommandHandler, commandControllerDelegate: self)
        self.sdkCommandHandler = sdkCommandHandler
    }

    required init(sdkController: AWController, presenter: SDKQueuePresenter, dataStore: SDKContext) {
        super.init(sdkController: sdkController, presenter: presenter, dataStore: dataStore)
        self.sdkCommandHandler = SDKCommandHandler(controller: sdkController, dataStore: dataStore)
        let sdkCommandHandler = SDKCommandHandler(controller: sdkController, dataStore: dataStore)
        self.controller = AWCommandController(context: self.dataStore, commandHandlerDelegate: sdkCommandHandler, commandControllerDelegate: self)
        self.sdkCommandHandler = sdkCommandHandler
    }

    override func startOperation() {
        log(debug: "Operation: Fetch Console Commands")
        self.controller?.startLoadingCommands()
    }

    func startedLoadingCommands() {
        log(info: "Command controller started loading commands")
        self.sdkController.commandManagementDelegate?.controllerDidStartLoadingCommands()
    }

    func failedLoadingCommands(error: NSError) {
        log(error: "Command controller failed to loading commands: \(error)")
        self.sdkController.commandManagementDelegate?.controllerDidFailToLoadCommands(error: error)
        self.markOperationFailed()
        // If the error code is 401, which means we don't have access to fetch the command, which means we are currently not enrolled (but the sdk still think that we are enrolled), so we need to un-enroll and re-enroll
        if error.code == 401 {
            self.sdkController.start()
        }
    }

    func finishedLoadingCommands() {
        log(error: "Command controller finished loading commands")
        self.sdkController.commandManagementDelegate?.controllerDidFinishLoadingCommands()
        var profileInstalled = false
        self.sdkCommandHandler?.processedCommands.forEach { (command) in
            if command.type == .installProfiles {
                profileInstalled = true
            }
        }
        self.controller = nil
        self.sdkCommandHandler = nil

        guard profileInstalled else {
            self.markOperationComplete()
            return
        }

        let profileApplicationOperations = createDependencyChain([ApplyNonAuthenticatedSettingsOperation.self, ApplyAuthenticatedSettingsOperation.self])
        SDKOperationQueue.workerQueue.addOperations(profileApplicationOperations, waitUntilFinished: true)
        log(info: "Completed Applying policies from profile changes when profile was downloaded by Fetch Console Commands Operation")
        self.markOperationComplete()
    }

}
